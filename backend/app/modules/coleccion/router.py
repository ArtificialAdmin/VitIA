from fastapi import APIRouter, Depends, HTTPException, status, UploadFile, File, Form
from sqlalchemy.orm import Session
import os
import base64
from typing import List, Optional

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

from app.modules.biblioteca import crud as biblio_crud

@router.post("/", response_model=schemas.Coleccion, summary="Añadir a colección")
async def create_item(
    file: UploadFile = File(...),
    nombre_variedad: str = Form(...),
    notas: Optional[str] = Form(None),
    latitud: Optional[float] = Form(None),
    longitud: Optional[float] = Form(None),
    es_publica: bool = Form(True),
    db: Session = Depends(get_db),
    current_user: models.Usuario = Depends(get_current_user)
):
    """Guarda una nueva captura enviada como MultipartForm."""
    try:
        # 1. Leer archivo
        file_bytes = await file.read()
        
        # 2. Subir a ImageKit
        upload_res = imagekit.upload_file(
            file=file_bytes,
            file_name=file.filename,
            options=UploadFileRequestOptions(
                folder="/vitia/colecciones/",
                use_unique_file_name=True
            )
        )
        
        # 3. Buscar/Crear ID de variedad por nombre
        variedad = biblio_crud.get_variedad_by_nombre(db, nombre_variedad)
        if not variedad:
            variedad = biblio_crud.create_variedad_automatica(db, nombre_variedad)
            
        # 4. Crear item en DB
        new_item = schemas.ColeccionCreate(
            id_variedad=variedad.id_variedad,
            path_foto_usuario=upload_res.url,
            notas=notas,
            latitud=latitud,
            longitud=longitud,
            es_publica=es_publica
        )
        
        return crud.create_coleccion_item(db=db, item=new_item, id_usuario=current_user.id_usuario)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error al subir imagen: {str(e)}")

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
