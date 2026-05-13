from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime

# --- SCHEMAS PARA CHAT ---

class ChatMessageBase(BaseModel):
    content: str

class ChatMessageCreate(ChatMessageBase):
    pass

class ChatMessageResponse(ChatMessageBase):
    id_message: int
    id_room: int
    id_sender: int
    created_at: datetime
    is_read: bool

    class Config:
        orm_mode = True
        from_attributes = True

class ChatRoomResponse(BaseModel):
    id_room: int
    created_at: datetime
    id_user1: int
    id_user2: int
    other_user_name: Optional[str] = None # Extra field for UI
    other_user_avatar: Optional[str] = None # Extra field for UI
    last_message: Optional[ChatMessageResponse] = None

    class Config:
        orm_mode = True
        from_attributes = True

# --- SCHEMAS PARA NOTIFICATIONS ---

class NotificationBase(BaseModel):
    title: str
    body: str
    type: str
    related_id: Optional[int] = None

class NotificationCreate(NotificationBase):
    id_usuario: int

class NotificationResponse(NotificationBase):
    id_notification: int
    id_usuario: int
    is_read: bool
    created_at: datetime

    class Config:
        orm_mode = True
        from_attributes = True
