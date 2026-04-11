from pydantic import BaseModel
from typing import Optional, List, Any, Dict
from app.modules.usuarios.schemas import BaseConfig

class MorfologiaData(BaseModel):
    hoja: Optional[str] = None
    racimo: Optional[str] = None
    uva: Optional[str] = None

class EnlaceData(BaseModel):
    titulo: str
    url: str
    tipo: Optional[str] = "web"

class VariedadBase(BaseModel):
    """Campos base que comparte una Variedad."""
    nombre: str
    descripcion: str
    color: Optional[str] = None
    links_imagenes: Optional[List[str]] = None 
    info_extra: Optional[List[EnlaceData]] = None
    morfologia: Optional[MorfologiaData] = None

class VariedadCreate(VariedadBase):
    """Esquema para crear una nueva Variedad."""
    pass

class VariedadUpdate(BaseModel):
    """Esquema para actualizar una Variedad (PATCH)."""
    nombre: Optional[str] = None
    descripcion: Optional[str] = None
    links_imagenes: Optional[List[str]] = None
    info_extra: Optional[Dict[str, Any]] = None
    color: Optional[str] = None
    morfologia: Optional[MorfologiaData] = None

class Variedad(VariedadBase, BaseConfig):
    """Esquema para LEER una Variedad."""
    id_variedad: int
