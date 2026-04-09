# --- En tu archivo /app/schemas.py ---

from pydantic import BaseModel, ConfigDict, EmailStr
from typing import Optional, List, Dict, Any
from datetime import datetime

from sqlalchemy import Boolean, Column, Integer, String, DateTime, ForeignKey, Text, Float, Table # <-- AÑADIR Table
from sqlalchemy.orm import relationship, backref
from .database import Base

# -----------------------------------------------------
# Configuración Base de Pydantic
# -----------------------------------------------------

class BaseConfig(BaseModel):
    """Configuración base para todos los esquemas.
    
    from_attributes=True (antes orm_mode) le dice a Pydantic
    que lea los datos incluso si son de un modelo de SQLAlchemy
    (ej. usuario.id) y no solo un diccionario (ej. usuario['id']).
    """
    model_config = ConfigDict(from_attributes=True, populate_by_name=True)


# -----------------------------------------------------
# Esquemas: Variedad (Biblioteca)
# -----------------------------------------------------

class MorfologiaData(BaseModel):
    hoja: Optional[str] = None
    racimo: Optional[str] = None
    uva: Optional[str] = None

class EnlaceData(BaseModel):
    titulo: str
    url: str
    # Opcional: si quieres distinguir tipos (video, web, pdf...)
    tipo: Optional[str] = "web"

class VariedadBase(BaseModel):
    """Campos base que comparte una Variedad."""
    nombre: str
    descripcion: str
    color: Optional[str] = None
    # Usamos 'Any' para el JSONB, o puedes ser más específico
    # con List[str] para links_imagenes y Dict[str, Any] para info_extra
    links_imagenes: Optional[List[str]] = None 
    info_extra: Optional[List[EnlaceData]] = None
    morfologia: Optional[MorfologiaData] = None

class VariedadCreate(VariedadBase):
    """Esquema para crear una nueva Variedad (usado por un admin)."""
    # No necesita campos extra, hereda todo de Base
    pass

# --- En tu archivo /app/schemas.py ---
# ... (junto a tus otras clases de Variedad) ...

class VariedadUpdate(BaseModel):
    """
    Esquema para actualizar una Variedad.
    Todos los campos son opcionales para permitir 
    actualizaciones parciales (método PATCH).
    """
    nombre: Optional[str] = None
    descripcion: Optional[str] = None
    links_imagenes: Optional[List[str]] = None
    info_extra: Optional[Dict[str, Any]] = None
    color: Optional[str] = None
    morfologia: Optional[MorfologiaData] = None

class Variedad(VariedadBase, BaseConfig):
    """Esquema para LEER una Variedad (lo que se devuelve al usuario)."""
    id_variedad: int

# --- Esquema intermedio para el propietario de la colección ---
class AutorColeccion(BaseConfig):
    """Un esquema reducido para mostrar solo info pública del propietario."""
    id_usuario: int
    nombre: str
    apellidos: str
    path_foto_perfil: Optional[str] = None

# ----
# Esquemas: Coleccion (Personal del Usuario)
# -----------------------------------------------------

class ColeccionBase(BaseModel):
    """Campo base para un item de la colección."""
    path_foto_usuario: str
    notas: Optional[str] = None
    latitud: Optional[float] = None
    longitud: Optional[float] = None
    es_publica: bool = True

class ColeccionCreate(ColeccionBase):
    """Esquema para crear un item en la colección.
    
    En tu endpoint, probablemente recibirás el id_variedad 
    por separado, no en este body.
    """
    id_variedad: int
    # El id_usuario se obtendrá del token de autenticación,
    # no se le pide al usuario.

class Coleccion(ColeccionBase, BaseConfig):
    """Esquema para LEER un item de la colección."""
    id_coleccion: int
    fecha_captura: datetime
    
    # --- Relación Anidada ---
    # Al leer un item de la colección, queremos ver
    # la información completa de la variedad, no solo su ID.
    variedad: Variedad 
    propietario: AutorColeccion

class ColeccionUpdate(BaseModel):
    """
    Esquema para actualizar un item de la colección (Parcial).
    Todos los campos son opcionales.
    """
    path_foto_usuario: Optional[str] = None
    id_variedad: Optional[int] = None
    notas: Optional[str] = None
    latitud: Optional[float] = None
    longitud: Optional[float] = None
    es_publica: Optional[bool] = None

# -----------------------------------------------------
# Esquemas: Publicacion (Foro)
# -----------------------------------------------------

class PublicacionBase(BaseModel):
    """Campos base para una publicación del foro."""
    titulo: str
    texto: str
    links_fotos: Optional[List[str]] = None

class PublicacionCreate(PublicacionBase):
    """Esquema para CREAR una publicación."""
    # El id_usuario se obtendrá del token, no del body
    variedades_ids: Optional[List[int]] = []
    pass

# --- Esquema intermedio para el autor ---
class AutorPublicacion(BaseConfig):
    """Un esquema reducido para mostrar solo info pública del autor."""
    id_usuario: int
    nombre: str
    apellidos: str
    path_foto_perfil: Optional[str] = None

class Publicacion(PublicacionBase, BaseConfig):
    """Esquema para LEER una publicación."""
    id_publicacion: int
    fecha_publicacion: datetime
    
    # --- Relación Anidada ---
    # Mostramos la información del autor usando el esquema reducido
    autor: AutorPublicacion
    likes: int
    is_liked: Optional[bool] = None # <-- Indicar si el usuario actual le dio like
    num_comentarios: int = 0
    variedades: List[Variedad] = []
    comentarios: List['Comentario'] = []
# -----------------------------------------------------
# Esquemas: Usuario
# -----------------------------------------------------

class UsuarioBase(BaseModel):
    """Campos base del usuario."""
    email: EmailStr  # Pydantic valida que sea un email válido
    nombre: str
    apellidos: str
    latitud: Optional[float] = None
    longitud: Optional[float] = None
    tutorial_superado: bool = False
    path_foto_perfil: Optional[str] = None

class UsuarioCreate(UsuarioBase):
    """Esquema para CREAR un usuario (registro)."""
    # El usuario envía 'password', NO 'password_hash'
    password: str

class UsuarioUpdate(BaseModel):
    """
    Esquema para actualizar el perfil de un usuario.
    Todos los campos son opcionales.
    """
    nombre: Optional[str] = None
    apellidos: Optional[str] = None
    email: Optional[EmailStr] = None
    latitud: Optional[float] = None
    longitud: Optional[float] = None
    tutorial_superado: Optional[bool] = None
    path_foto_perfil: Optional[str] = None

class Usuario(UsuarioBase, BaseConfig):
    """Esquema para LEER la info de un usuario (perfil)."""
    id_usuario: int
    es_premium: bool
    fecha_registro: datetime
    tutorial_superado: bool = False
    # --- Relaciones Anidadas ---
    # Al ver el perfil de un usuario, mostramos sus publicaciones
    # y los items de su colección.
    publicaciones: List[Publicacion] = []
    coleccion: List[Coleccion] = []

# -----------------------------------------------------
# Esquemas: Autenticación (Login)
# -----------------------------------------------------

class Token(BaseModel):
    """Esquema para devolver un Token JWT al usuario."""
    access_token: str
    token_type: str

class TokenData(BaseModel):
    """Esquema para los datos contenidos dentro del Token JWT."""
    email: Optional[str] = None
    id_usuario: Optional[int] = None

# 2. NUEVOS SCHEMAS PARA COMENTARIOS

class ComentarioBase(BaseModel):
    texto: str

class ComentarioCreate(ComentarioBase):
    id_publicacion: int
    # Opcional: Si envías esto, es una respuesta. Si no, es comentario principal.
    id_padre: Optional[int] = None

# Schema para mostrar el autor del comentario (reducido)
class AutorComentario(BaseConfig):
    """Un esquema reducido para mostrar solo info pública del autor."""
    id_usuario: int
    nombre: str
    apellidos: str
    path_foto_perfil: Optional[str] = None

class Comentario(ComentarioBase, BaseConfig):
    id_comentario: int
    fecha_comentario: datetime
    likes: int
    id_usuario: int
    id_publicacion: int
    id_padre: Optional[int] = None
    is_liked: Optional[bool] = None
    borrado: bool = False
    
    autor: AutorComentario
    
    # RECURSIVIDAD: Un comentario puede tener una lista de comentarios (hijos)
    # Usamos List['Comentario'] entre comillas porque la clase se está definiendo ahora mismo
    hijos: List['Comentario'] = [] 

# Esto es necesario para que Pydantic resuelva la referencia circular (hijos -> Comentario)
Comentario.model_rebuild()
Publicacion.model_rebuild()

# 1. SCHEMA PARA CREAR/ACTUALIZAR VOTO
class VotoCreate(BaseModel):
    # True = Like
    # False = Dislike
    # None = Quitar voto (Neutro)
    es_like: Optional[bool] = None