from pydantic import BaseModel, EmailStr, ConfigDict
from typing import Optional, List
from datetime import datetime

class BaseConfig(BaseModel):
    model_config = ConfigDict(from_attributes=True, populate_by_name=True)

class UsuarioBase(BaseModel):
    email: EmailStr
    nombre: str
    apellidos: str
    latitud: Optional[float] = None
    longitud: Optional[float] = None
    tutorial_superado: bool = False
    path_foto_perfil: Optional[str] = None

class UsuarioCreate(UsuarioBase):
    password: str

class UsuarioUpdate(BaseModel):
    nombre: Optional[str] = None
    apellidos: Optional[str] = None
    email: Optional[EmailStr] = None
    latitud: Optional[float] = None
    longitud: Optional[float] = None
    tutorial_superado: Optional[bool] = None
    path_foto_perfil: Optional[str] = None

class Usuario(UsuarioBase, BaseConfig):
    id_usuario: int
    es_premium: bool
    fecha_registro: datetime
    tutorial_superado: bool = False
    
    # Nota: Las relaciones circulares (publicaciones, coleccion)
    # se manejarán con forward refs si es necesario, pero por ahora
    # simplificamos para evitar dependencias entre módulos en los schemas base.

# --- Esquemas reducidos para otras entidades (Foro, Colección, etc.) ---
class AutorColeccion(BaseConfig):
    id_usuario: int
    nombre: str
    apellidos: str
    path_foto_perfil: Optional[str] = None

class AutorPublicacion(BaseConfig):
    id_usuario: int
    nombre: str
    apellidos: str
    path_foto_perfil: Optional[str] = None

class AutorComentario(BaseConfig):
    id_usuario: int
    nombre: str
    apellidos: str
    path_foto_perfil: Optional[str] = None
