from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List

from app.core import models
from app.core.database import get_db
from app.modules.auth.router import get_current_user
from . import crud, schemas

router = APIRouter(
    prefix="/experto",
    tags=["Experto"]
)

def get_current_experto(current_user: models.Usuario = Depends(get_current_user)):
    if current_user.rol != "experto" and current_user.rol != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="No tienes permisos de experto."
        )
    return current_user

@router.get("/validaciones/pendientes", response_model=List[schemas.ValidacionExperto], summary="Obtener validaciones pendientes")
def read_validaciones_pendientes(
    skip: int = 0,
    limit: int = 50,
    db: Session = Depends(get_db),
    experto: models.Usuario = Depends(get_current_experto)
):
    """Devuelve una lista de colecciones que requieren validación manual por un experto."""
    return crud.get_validaciones_pendientes(db, skip=skip, limit=limit)

@router.get("/validaciones/pendientes/count", summary="Obtener número de validaciones pendientes")
def count_validaciones_pendientes(
    db: Session = Depends(get_db),
    experto: models.Usuario = Depends(get_current_experto)
):
    """Devuelve la cantidad de colecciones que requieren validación manual por un experto."""
    total = crud.get_validaciones_pendientes_count(db)
    return {"count": total}

@router.get("/validaciones/{id_validacion}", response_model=schemas.ValidacionExperto, summary="Obtener detalle de una validación")
def read_validacion(
    id_validacion: int,
    db: Session = Depends(get_db),
    current_user: models.Usuario = Depends(get_current_user)
):
    """Obtiene el detalle de una validación específica."""
    val = crud.get_validacion(db, id_validacion)
    if not val:
        raise HTTPException(status_code=404, detail="Validación no encontrada")
    return val

@router.post("/validaciones/{id_validacion}", response_model=schemas.ValidacionExperto, summary="Enviar validación")
def validate_item(
    id_validacion: int,
    validacion_data: schemas.ValidacionExpertoUpdate,
    db: Session = Depends(get_db),
    experto: models.Usuario = Depends(get_current_experto)
):
    """El experto envía su veredicto y evaluación de imágenes para una colección."""
    val = crud.update_validacion(db, id_validacion, experto.id_usuario, validacion_data)
    if not val:
        raise HTTPException(status_code=404, detail="Validación no encontrada")
    return val

@router.get("/colecciones-dataset", response_model=List[schemas.Coleccion], summary="Obtener todas las colecciones sin evaluar")
def read_colecciones_sin_evaluar(
    skip: int = 0,
    limit: int = 100,
    db: Session = Depends(get_db),
    experto: models.Usuario = Depends(get_current_experto)
):
    """Devuelve todas las imágenes del dataset global que aún no han sido validadas por un experto."""
    return crud.get_colecciones_sin_evaluar(db, skip=skip, limit=limit)

@router.post("/anotar-coleccion/{id_coleccion}", response_model=schemas.ValidacionExperto, summary="Anotar colección del dataset")
def anotar_coleccion_dataset(
    id_coleccion: int,
    validacion_data: schemas.ValidacionExpertoUpdate,
    db: Session = Depends(get_db),
    experto: models.Usuario = Depends(get_current_experto)
):
    """El experto anota cualquier imagen de la base de datos (crea/actualiza la validación)."""
    val = crud.anotar_coleccion(db, id_coleccion, experto.id_usuario, validacion_data)
    if not val:
        raise HTTPException(status_code=404, detail="Colección no encontrada o error al anotar")
    return val
