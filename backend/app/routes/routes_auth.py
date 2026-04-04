# --- En tu archivo /app/routes/routes_auth.py ---

import os
from fastapi import APIRouter, Depends, HTTPException, status, Form, File, UploadFile
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.orm import Session
from typing import Optional, Union
from .. import crud, models, schemas, auth

# Importar ImageKit (Asegúrate de tener esto configurado como en tus otras rutas)
from imagekitio import ImageKit
from ..config import settings # O donde tengas tus claves
import base64

# Inicializar ImageKit
from imagekitio.models.UploadFileRequestOptions import UploadFileRequestOptions

# Inicializar ImageKit
imagekit = ImageKit(
    public_key=os.getenv("IMAGEKIT_PUBLIC_KEY"),
    private_key=os.getenv("IMAGEKIT_PRIVATE_KEY"),
    url_endpoint=os.getenv("IMAGEKIT_URL_ENDPOINT")
)

from .. import crud, models, schemas, auth, security
from ..database import get_db

router = APIRouter(
    prefix="/auth",
    tags=["Autenticación"]
)

@router.post("/register", response_model=schemas.Usuario)
def register_user(
    email: str = Form(...),
    password: str = Form(...),
    nombre: str = Form(...),
    apellidos: str = Form(...),
    latitud: Optional[float] = Form(None),
    longitud: Optional[float] = Form(None),
    foto: Union[UploadFile, str, None] = File(None),
    db: Session = Depends(get_db)
):
    # 1. Validar email
    if crud.get_user_by_email(db, email=email):
        raise HTTPException(status_code=400, detail="El email ya está registrado")

    # 2. Subir foto (ImageKit)
    url_foto = None
    # Validamos que 'foto' sea realmente un archivo y no un string vacío
    if foto and isinstance(foto, UploadFile):
        try:
            file_content = foto.file.read()
            file_base64 = base64.b64encode(file_content).decode("utf-8")
            
            upload_info = imagekit.upload_file(
                file=file_base64,
                file_name=f"perfil_{email}.jpg",
                options={
                    "folder": "/fotos_perfil/",
                    "is_private_file": False
                }
            )
            url_foto = upload_info.url
        except Exception as e:
            print(f"Error subiendo foto: {e}")
            pass

    # 3. ENCRIPTAR CONTRASEÑA (Usando auth.py) - ELIMINADO POR DOBLE HASHING EN CRUD
    # hashed_password = auth.get_password_hash(password)

    # 4. Crear objeto para el CRUD
    user_data = schemas.UsuarioCreate(
        email=email,
        password=password, # Pasamos la password PLANA, crud.create_user la encriptará
        nombre=nombre,
        apellidos=apellidos,
        latitud=latitud,
        longitud=longitud
    )

    # 5. Guardar en BD
    return crud.create_user(db=db, user=user_data, url_foto=url_foto)


@router.post("/token", 
    response_model=schemas.Token,
    summary="Iniciar sesión y obtener un token"
)
def login_for_access_token(
    db: Session = Depends(get_db),
    form_data: OAuth2PasswordRequestForm = Depends()
):
    """
    Endpoint de login.
    Recibe un 'username' (que será nuestro email) y 'password' 
    en un formulario, y devuelve un token de acceso.
    """
    user = crud.get_user_by_email(db, email=form_data.username)
    
    # Verifica que el usuario exista y la contraseña sea correcta
    if not user or not security.verify_password(form_data.password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Email o contraseña incorrectos",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    # Crea el token. El "subject" (sub) será el ID del usuario
    access_token = auth.create_access_token(
        data={"sub": str(user.id_usuario)}
    )
    
    return {"access_token": access_token, "token_type": "bearer"}

@router.post("/logout",
    status_code=status.HTTP_200_OK,
    summary="Cerrar sesión (invalidar token en cliente)"
)
def logout_user(current_user: models.Usuario = Depends(auth.get_current_user)):
    """
    Endpoint para que el cliente notifique un cierre de sesión.
    
    El servidor no hace nada (al ser JWT stateless).
    El cliente DEBE eliminar el token localmente después de llamar a esto.
    """
    return {"msg": "Cierre de sesión exitoso. El token debe ser eliminado por el cliente."}