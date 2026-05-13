from fastapi import APIRouter, Depends, WebSocket, WebSocketDisconnect, HTTPException, status
from sqlalchemy.orm import Session
from typing import List, Dict
import json

from app.core.database import get_db
from app.modules.auth.router import get_current_user
from app.core import models
from app.modules.chat import schemas, crud

router = APIRouter(tags=["Chat & Notifications"])

# --- WEBSOCKET MANAGER ---

class ConnectionManager:
    def __init__(self):
        # Dictionary mapping room_id to a list of dicts: {"websocket": ws, "user_id": uid}
        self.active_connections: Dict[int, List[Dict]] = {}

    async def connect(self, websocket: WebSocket, room_id: int, user_id: int):
        await websocket.accept()
        if room_id not in self.active_connections:
            self.active_connections[room_id] = []
        self.active_connections[room_id].append({"websocket": websocket, "user_id": user_id})
        # Broadcast presence
        await self.broadcast_to_room({"type": "presence", "user_id": user_id, "status": "online"}, room_id)

    async def disconnect(self, websocket: WebSocket, room_id: int, user_id: int):
        if room_id in self.active_connections:
            # Eliminar la conexión específica
            self.active_connections[room_id] = [c for c in self.active_connections[room_id] if c["websocket"] != websocket]
            if not self.active_connections[room_id]:
                del self.active_connections[room_id]
            else:
                # Broadcast presence
                await self.broadcast_to_room({"type": "presence", "user_id": user_id, "status": "offline"}, room_id)

    async def broadcast_to_room(self, message: dict, room_id: int):
        if room_id in self.active_connections:
            for connection in self.active_connections[room_id]:
                ws = connection["websocket"]
                try:
                    await ws.send_json(message)
                except Exception:
                    pass

manager = ConnectionManager()

# --- CHAT ENDPOINTS ---

@router.get("/chat/rooms", response_model=List[schemas.ChatRoomResponse])
def get_my_chat_rooms(db: Session = Depends(get_db), current_user: models.Usuario = Depends(get_current_user)):
    rooms = crud.get_user_rooms(db, current_user.id_usuario)
    # Augment response with other user details and last message
    response = []
    for room in rooms:
        other_user_id = room.id_user2 if room.id_user1 == current_user.id_usuario else room.id_user1
        other_user = db.query(models.Usuario).filter(models.Usuario.id_usuario == other_user_id).first()
        
        last_msg = db.query(models.ChatMessage)\
                     .filter(models.ChatMessage.id_room == room.id_room)\
                     .order_by(models.ChatMessage.created_at.desc()).first()
        
        room_data = schemas.ChatRoomResponse.from_orm(room)
        if other_user:
            room_data.other_user_name = f"{other_user.nombre} {other_user.apellidos}"
            room_data.other_user_avatar = other_user.path_foto_perfil
        
        if last_msg:
            room_data.last_message = schemas.ChatMessageResponse.from_orm(last_msg)
            
        response.append(room_data)
        
    return response

@router.post("/chat/rooms/{other_user_id}", response_model=schemas.ChatRoomResponse)
def get_or_create_chat(other_user_id: int, db: Session = Depends(get_db), current_user: models.Usuario = Depends(get_current_user)):
    if other_user_id == current_user.id_usuario:
        raise HTTPException(status_code=400, detail="No puedes crear un chat contigo mismo.")
        
    other_user = db.query(models.Usuario).filter(models.Usuario.id_usuario == other_user_id).first()
    if not other_user:
        raise HTTPException(status_code=404, detail="Usuario no encontrado.")
        
    room = crud.get_or_create_room(db, current_user.id_usuario, other_user_id)
    
    room_data = schemas.ChatRoomResponse.from_orm(room)
    room_data.other_user_name = f"{other_user.nombre} {other_user.apellidos}"
    room_data.other_user_avatar = other_user.path_foto_perfil
    return room_data

@router.get("/chat/rooms/{room_id}/messages", response_model=List[schemas.ChatMessageResponse])
def get_messages(room_id: int, skip: int = 0, limit: int = 50, db: Session = Depends(get_db), current_user: models.Usuario = Depends(get_current_user)):
    # Verify user is in room
    room = db.query(models.ChatRoom).filter(models.ChatRoom.id_room == room_id).first()
    if not room or (room.id_user1 != current_user.id_usuario and room.id_user2 != current_user.id_usuario):
        raise HTTPException(status_code=403, detail="No tienes acceso a esta sala.")
        
    return crud.get_room_messages(db, room_id, skip=skip, limit=limit)

@router.websocket("/ws/chat/{room_id}")
async def websocket_endpoint(websocket: WebSocket, room_id: int, user_id: int, db: Session = Depends(get_db)):
    # NOTA: En producción, la auth en WebSockets se suele hacer mediante un token enviado en los headers o query params.
    # Por simplicidad ahora, confiamos en el user_id. 
    await manager.connect(websocket, room_id, user_id)
    try:
        while True:
            # Recibe mensaje de texto del cliente
            data_str = await websocket.receive_text()
            data = json.loads(data_str)
            msg_type = data.get("type", "chat_message")
            
            if msg_type == "chat_message":
                content = data.get("content")
                if content:
                    # 1. Guarda en BD
                    new_msg = crud.create_message(db, room_id, user_id, content)
                    
                    # 2. Transmite a los que están en la sala
                    msg_response = schemas.ChatMessageResponse.from_orm(new_msg).dict()
                    msg_response["created_at"] = msg_response["created_at"].isoformat()
                    # Add type explicitly for the frontend
                    msg_response["type"] = "chat_message"
                    await manager.broadcast_to_room(msg_response, room_id)
                    
                    # 3. Envía notificación Push al OTRO usuario
                    room = db.query(models.ChatRoom).filter(models.ChatRoom.id_room == room_id).first()
                    if room:
                        other_user_id = room.id_user2 if room.id_user1 == user_id else room.id_user1
                        sender = db.query(models.Usuario).filter(models.Usuario.id_usuario == user_id).first()
                        sender_name = sender.nombre if sender else "Usuario"
                        
                        crud.create_notification(
                            db=db,
                            id_usuario=other_user_id,
                            title=f"Nuevo mensaje de {sender_name}",
                            body=content,
                            type="chat",
                            related_id=room_id
                        )

            elif msg_type == "read_receipt":
                # Received when a user opens the chat and sees a message
                msg_id = data.get("id_message")
                if msg_id:
                    crud.mark_message_as_read(db, msg_id)
                    # Broadcast the read receipt so the sender knows it was read
                    await manager.broadcast_to_room({
                        "type": "read_receipt",
                        "id_message": msg_id,
                        "id_reader": user_id
                    }, room_id)

    except WebSocketDisconnect:
        await manager.disconnect(websocket, room_id, user_id)

# --- NOTIFICATIONS ENDPOINTS ---

@router.get("/notifications", response_model=List[schemas.NotificationResponse])
def get_my_notifications(skip: int = 0, limit: int = 50, db: Session = Depends(get_db), current_user: models.Usuario = Depends(get_current_user)):
    return crud.get_user_notifications(db, current_user.id_usuario, skip, limit)

@router.post("/notifications/read")
def mark_my_notifications_read(db: Session = Depends(get_db), current_user: models.Usuario = Depends(get_current_user)):
    crud.mark_notifications_as_read(db, current_user.id_usuario)
    return {"message": "Notificaciones marcadas como leídas"}

@router.delete("/notifications")
def delete_my_notifications(db: Session = Depends(get_db), current_user: models.Usuario = Depends(get_current_user)):
    crud.delete_all_user_notifications(db, current_user.id_usuario)
    return {"message": "Todas las notificaciones eliminadas"}

@router.delete("/notifications/{notification_id}")
def delete_my_notification(notification_id: int, db: Session = Depends(get_db), current_user: models.Usuario = Depends(get_current_user)):
    deleted = crud.delete_user_notification(db, notification_id, current_user.id_usuario)
    if not deleted:
        raise HTTPException(status_code=404, detail="Notificación no encontrada o no tienes permiso")
    return {"message": "Notificación eliminada"}
