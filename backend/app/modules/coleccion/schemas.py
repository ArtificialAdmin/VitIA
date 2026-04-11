from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime
from app.modules.usuarios.schemas import BaseConfig, AutorColeccion
from app.modules.biblioteca.schemas import Variedad # Necesitaremos importar esto luego

class ColeccionBase(BaseModel):
    """Campo base para un item de la colección."""
    path_foto_usuario: str
    notas: Optional[str] = None
    latitud: Optional[float] = None
    longitud: Optional[float] = None
    es_publica: bool = True

class ColeccionCreate(ColeccionBase):
    """Esquema para crear un item en la colección."""
    id_variedad: int

class Coleccion(ColeccionBase, BaseConfig):
    """Esquema para LEER un item de la colección."""
    id_coleccion: int
    fecha_captura: datetime
    # Relación Anidada
    variedad: dict # Devolvemos dict temporalmente hasta migrar biblioteca
    propietario: AutorColeccion

class ColeccionUpdate(BaseModel):
    """Esquema para actualizar un item de la colección (Parcial)."""
    path_foto_usuario: Optional[str] = None
    id_variedad: Optional[int] = None
    notas: Optional[str] = None
    latitud: Optional[float] = None
    longitud: Optional[float] = None
    es_publica: Optional[bool] = None
