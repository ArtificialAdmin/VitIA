from sqlalchemy.orm import Session
from sqlalchemy import or_, and_, desc
from app.core import models
from app.modules.chat import schemas
from app.services.push_notifications import send_push_notification

# --- CHAT ROOMS ---

def get_or_create_room(db: Session, user1_id: int, user2_id: int):
    # Sort IDs so user1 is always smaller to prevent duplicate rooms (1->2 and 2->1)
    id_u1, id_u2 = sorted([user1_id, user2_id])
    
    room = db.query(models.ChatRoom).filter(
        models.ChatRoom.id_user1 == id_u1,
        models.ChatRoom.id_user2 == id_u2
    ).first()
    
    if not room:
        room = models.ChatRoom(id_user1=id_u1, id_user2=id_u2)
        db.add(room)
        db.commit()
        db.refresh(room)
    
    return room

def get_user_rooms(db: Session, user_id: int):
    return db.query(models.ChatRoom).filter(
        or_(models.ChatRoom.id_user1 == user_id, models.ChatRoom.id_user2 == user_id)
    ).all()

# --- CHAT MESSAGES ---

def get_room_messages(db: Session, room_id: int, skip: int = 0, limit: int = 50):
    return db.query(models.ChatMessage)\
             .filter(models.ChatMessage.id_room == room_id)\
             .order_by(desc(models.ChatMessage.created_at))\
             .offset(skip).limit(limit).all()

def create_message(db: Session, room_id: int, sender_id: int, content: str):
    new_message = models.ChatMessage(
        id_room=room_id,
        id_sender=sender_id,
        content=content
    )
    db.add(new_message)
    db.commit()
    db.refresh(new_message)
    return new_message

# --- NOTIFICATIONS ---

def create_notification(db: Session, id_usuario: int, title: str, body: str, type: str, related_id: int = None):
    new_notif = models.Notification(
        id_usuario=id_usuario,
        title=title,
        body=body,
        type=type,
        related_id=related_id
    )
    db.add(new_notif)
    db.commit()
    db.refresh(new_notif)
    
    # Intenta enviar push
    user = db.query(models.Usuario).filter(models.Usuario.id_usuario == id_usuario).first()
    if user and user.fcm_token:
        send_push_notification(
            tokens=[user.fcm_token],
            title=title,
            body=body,
            data={"type": type, "related_id": str(related_id) if related_id else ""}
        )
    return new_notif

def get_user_notifications(db: Session, user_id: int, skip: int = 0, limit: int = 50):
    return db.query(models.Notification)\
             .filter(models.Notification.id_usuario == user_id)\
             .order_by(desc(models.Notification.created_at))\
             .offset(skip).limit(limit).all()

def mark_notifications_as_read(db: Session, user_id: int):
    db.query(models.Notification)\
      .filter(models.Notification.id_usuario == user_id, models.Notification.is_read == False)\
      .update({"is_read": True})
    db.commit()
