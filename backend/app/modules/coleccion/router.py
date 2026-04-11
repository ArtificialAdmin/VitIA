from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
import os
import base64
from typing import List

from app.core import models
from app.core.database import get_db
from app.modules.auth.router import get_current_user
from . import crud, schemas

# Inicializar ImageKit
from imagekitio import ImageKit
from app.core.config import settings
from imagekitio.models.UploadFileRequestOptions import UploadFileRequestOptions

imagekit = ImageKit(
    public_key=settings.IMAGEKIT_PUBLIC_KEY,
    private_key=settings.IMAGEKIT_PRIVATE_KEY,
    url_endpoint=settings.IMAGEKIT_URL_ENDPOINT
)

router = APIRouter(
    prefix="/coleccion",
    tags=["Colección"]
)

@router.post("/", response_model=schemas.Coleccion, summary="Añadir a colección")
def create_item(
    item: schemas.ColeccionCreate,
    db: Session = Depends(get_db),
    current_user: models.Usuario = Depends(get_current_user)
):
    """Guarda una nueva captura en la colección del usuario."""
    return crud.create_coleccion_item(db=db, item=item, id_usuario=current_user.id_usuario)

@router.get("/", response_model=List[schemas.Coleccion], summary="Mi Colección")
def list_items(
    skip: int = 0,
    limit: int = 50,
    db: Session = Depends(get_db),
    current_user: models.Usuario = Depends(get_current_user)
):
    """Lista los items de la colección del usuario autenticado."""
    return crud.get_user_coleccion(db, id_usuario=current_user.id_usuario, skip=skip, limit=limit)

@router.get("/mapa", response_model=List[schemas.Coleccion], summary="Items para el mapa")
def get_map_items(
    modo: str = "publico",
    db: Session = Depends(get_db),
    current_user: models.Usuario = Depends(get_current_user)
):
    """Obtiene los items con coordenadas para mostrar en el mapa."""
    return crud.get_colecciones_mapa(db, modo=modo, id_usuario=current_user.id_usuario)

@router.get("/{id_coleccion}", response_model=schemas.Coleccion, summary="Detalle de item")
def get_item(
    id_coleccion: int,
    db: Session = Depends(get_db),
    current_user: models.Usuario = Depends(get_current_user)
):
    """Obtiene un item específico de la colección."""
    item = crud.get_coleccion_item(db, id_coleccion, current_user.id_usuario)
    if not item:
        raise HTTPException(status_code=404, detail="No encontrado")
    return item

@router.patch("/{id_coleccion}", response_model=schemas.Coleccion, summary="Actualizar item")
def update_item(
    id_coleccion: int,
    item_update: schemas.ColeccionUpdate,
    db: Session = Depends(get_db),
    current_user: models.Usuario = Depends(get_current_user)
):
    """Actualiza los datos de un item de la colección."""
    db_item = crud.get_coleccion_item(db, id_coleccion, current_user.id_usuario)
    if not db_item:
        raise HTTPException(status_code=404, detail="No encontrado")
    return crud.update_coleccion_item(db, db_item, item_update)

@router.delete("/{id_coleccion}", summary="Eliminar item")
def delete_item(
    id_coleccion: int,
    db: Session = Depends(get_db),
    current_user: models.Usuario = Depends(get_current_user)
):
    """Borra un item de la colección."""
    ok = crud.delete_coleccion_item(db, id_coleccion, current_user.id_usuario)
    if not ok:
        raise HTTPException(status_code=404, detail="No encontrado")
    return {"msg": "Eliminado"}
