from pydantic import BaseModel, ConfigDict
from typing import Optional, List
from datetime import datetime
from app.modules.usuarios.schemas import BaseConfig, AutorPublicacion, AutorComentario

class PublicacionBase(BaseModel):
    """Campos base para una publicación del foro."""
    titulo: str
    texto: str
    links_fotos: Optional[List[str]] = None

class PublicacionCreate(PublicacionBase):
    """Esquema para CREAR una publicación."""
    variedades_ids: Optional[List[int]] = []

class ComentarioBase(BaseModel):
    texto: str

class ComentarioCreate(ComentarioBase):
    id_publicacion: int
    id_padre: Optional[int] = None

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
    hijos: List['Comentario'] = [] 

class Publicacion(PublicacionBase, BaseConfig):
    """Esquema para LEER una publicación."""
    id_publicacion: int
    fecha_publicacion: datetime
    autor: AutorPublicacion
    likes: int
    is_liked: Optional[bool] = None
    num_comentarios: int = 0
    # Nota: variedades y comentarios se manejarán con forward refs
    # o se simplificarán para la versión local del módulo.
    # Por ahora permitimos listados básicos.
    comentarios: List[Comentario] = []

class VotoCreate(BaseModel):
    es_like: Optional[bool] = None

# Rebuild de refs circulares
Comentario.model_rebuild()
Publicacion.model_rebuild()
