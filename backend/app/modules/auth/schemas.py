from pydantic import BaseModel
from typing import Optional

class Token(BaseModel):
    """Esquema para devolver un Token JWT al usuario."""
    access_token: str
    token_type: str

class TokenData(BaseModel):
    """Esquema para los datos contenidos dentro del Token JWT."""
    email: Optional[str] = None
    id_usuario: Optional[int] = None
