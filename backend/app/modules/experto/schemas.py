from pydantic import BaseModel
from typing import Optional, List, Dict, Any
from datetime import datetime
from app.modules.coleccion.schemas import Coleccion
from app.modules.usuarios.schemas import BaseConfig

class ValidacionExpertoBase(BaseModel):
    es_correcta: Optional[bool] = None
    feedback_experto: Optional[str] = None
    evaluacion_imagenes: Optional[List[Dict[str, Any]]] = None

class ValidacionExpertoUpdate(ValidacionExpertoBase):
    id_variedad_correcta: Optional[int] = None
    variedad_sugerida: Optional[str] = None

class ValidacionExperto(ValidacionExpertoBase, BaseConfig):
    id_validacion: int
    id_coleccion: int
    id_experto: Optional[int] = None
    solicitada_en: datetime
    validada_en: Optional[datetime] = None
    estado: str
    
    coleccion: Coleccion # Anidado para que el experto vea qué variedad dijo la IA y las fotos

