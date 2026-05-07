from pydantic import BaseModel, ConfigDict
from typing import Optional, List
from datetime import datetime
from app.modules.usuarios.schemas import BaseConfig, AutorColeccion
from app.modules.biblioteca.schemas import Variedad

class ColeccionBase(BaseModel):
    """Campo base para un item de la colección."""
    path_foto_usuario: str
    notas: Optional[str] = None
    latitud: Optional[float] = None
    longitud: Optional[float] = None
    es_publica: bool = True
    # Soporte Premium
    fotos_premium: Optional[List[str]] = None
    analisis_ia: Optional[str] = None
    es_premium: bool = False
    solicita_validacion_experto: bool = False

class ColeccionCreate(ColeccionBase):
    """Esquema para crear un item en la colección."""
    id_variedad: int

class ValidacionExpertoSchema(BaseModel):
    id_validacion: int
    es_correcta: Optional[bool]
    estado: str
    feedback_experto: Optional[str]
    validada_en: Optional[datetime]

    model_config = ConfigDict(from_attributes=True)

class Coleccion(ColeccionBase, BaseConfig):
    """Esquema para LEER un item de la colección."""
    id_coleccion: int
    fecha_captura: datetime
    # Relación Anidada
    variedad: Variedad
    propietario: AutorColeccion
    validacion: Optional[ValidacionExpertoSchema] = None

class ColeccionUpdate(BaseModel):
    """Esquema para actualizar un item de la colección (Parcial)."""
    path_foto_usuario: Optional[str] = None
    id_variedad: Optional[int] = None
    notas: Optional[str] = None
    latitud: Optional[float] = None
    longitud: Optional[float] = None
    es_publica: Optional[bool] = None
