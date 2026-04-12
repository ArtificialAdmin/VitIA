from fastapi import APIRouter, Depends, HTTPException, status, UploadFile, File
from sqlalchemy.orm import Session
import base64
from typing import List

from app.core import models
from app.core.database import get_db
from app.modules.auth.router import get_current_user
from . import crud, schemas
from app.modules.biblioteca import schemas as biblioteca_schemas

# Inicializar ImageKit (Reutilizando configuración)
from imagekitio import ImageKit
from app.core.config import settings
from imagekitio.models.UploadFileRequestOptions import UploadFileRequestOptions

imagekit = ImageKit(
    public_key=settings.IMAGEKIT_PUBLIC_KEY,
    private_key=settings.IMAGEKIT_PRIVATE_KEY,
    url_endpoint=settings.IMAGEKIT_URL_ENDPOINT
)

router = APIRouter(
    prefix="/users",
    tags=["Usuarios"]
)

@router.get("/me", response_model=schemas.Usuario, summary="Mi Perfil")
def read_users_me(current_user: models.Usuario = Depends(get_current_user)):
    """Devuelve el perfil del usuario autenticado."""
    return current_user

@router.patch("/me", response_model=schemas.Usuario, summary="Actualizar perfil")
def update_users_me(
    user_update: schemas.UsuarioUpdate,
    db: Session = Depends(get_db),
    current_user: models.Usuario = Depends(get_current_user)
):
    """Actualiza los datos del usuario autenticado."""
    if user_update.email:
        existing_user = crud.get_user_by_email(db, email=user_update.email)
        if existing_user and existing_user.id_usuario != current_user.id_usuario:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Este correo electrónico ya está registrado por otro usuario."
            )
    return crud.update_user(db=db, db_user=current_user, user_update=user_update)

@router.delete("/me", response_model=schemas.Usuario, summary="Borrar mi cuenta")
def delete_users_me(
    db: Session = Depends(get_db),
    current_user: models.Usuario = Depends(get_current_user)
):
    """Elimina permanentemente la cuenta del usuario autenticado."""
    return crud.delete_user(db, id_usuario=current_user.id_usuario)

@router.get("/me/favoritos", response_model=List[biblioteca_schemas.Variedad], summary="Mis Favoritos")
def get_mis_favoritos(
    db: Session = Depends(get_db),
    current_user: models.Usuario = Depends(get_current_user)
):
    """Obtiene variedades marcadas como favoritas."""
    # Nota: Aquí devolvemos dicts por ahora para evitar problemas de esquemas circulares 
    # de variedades, que migraremos luego.
    return crud.get_user_favoritos(db, current_user.id_usuario)

@router.post("/me/avatar", response_model=schemas.Usuario, summary="Actualizar avatar")
def upload_avatar_me(
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    current_user: models.Usuario = Depends(get_current_user)
):
    """Sube una foto de perfil a ImageKit."""
    if not file:
        raise HTTPException(status_code=400, detail="Archivo vacío")

    try:
        file_content = file.file.read()
        file_base64 = base64.b64encode(file_content).decode("utf-8")
        upload_info = imagekit.upload_file(
            file=file_base64,
            file_name=f"perfil_{current_user.email}.jpg",
            options=UploadFileRequestOptions(
                folder="/fotos_perfil/",
                is_private_file=False,
                use_unique_file_name=True 
            )
        )
        update_data = schemas.UsuarioUpdate(path_foto_perfil=upload_info.url)
        return crud.update_user(db=db, db_user=current_user, user_update=update_data)
    except Exception as e:
        print(f"Error avatar: {e}")
        raise HTTPException(status_code=500, detail="Error de subida")
