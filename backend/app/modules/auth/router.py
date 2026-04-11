from fastapi import APIRouter, Depends, HTTPException, status, Form, File, UploadFile
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from jose import JWTError, jwt
from datetime import datetime, timedelta, timezone
from typing import Optional, Union
from sqlalchemy.orm import Session
import base64
import os

from app.core import models, security
from app.core.database import get_db
from app.core.config import settings
from app.modules.usuarios import crud as user_crud
from app.modules.usuarios import schemas as user_schemas
from . import schemas

# Inicializar ImageKit
from imagekitio import ImageKit
from imagekitio.models.UploadFileRequestOptions import UploadFileRequestOptions

imagekit = ImageKit(
    public_key=settings.IMAGEKIT_PUBLIC_KEY,
    private_key=settings.IMAGEKIT_PRIVATE_KEY,
    url_endpoint=settings.IMAGEKIT_URL_ENDPOINT
)

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="auth/token")

router = APIRouter(
    prefix="/auth",
    tags=["Autenticación"]
)

# --- UTILIDADES JWT ---

def create_access_token(data: dict, expires_delta: Optional[timedelta] = None):
    """Crea un nuevo token de acceso JWT."""
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.now(timezone.utc) + expires_delta
    else:
        expire = datetime.now(timezone.utc) + timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, settings.SECRET_KEY, algorithm=settings.ALGORITHM)
    return encoded_jwt

def get_current_user(
    token: str = Depends(oauth2_scheme), 
    db: Session = Depends(get_db)
) -> models.Usuario:
    """Verifica el token y extrae el usuario actual."""
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="No se pudieron validar las credenciales",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
        user_id: str = payload.get("sub")
        if user_id is None:
            raise credentials_exception
        token_data = schemas.TokenData(id_usuario=int(user_id))
    except (JWTError, ValueError):
        raise credentials_exception
    
    user = user_crud.get_user(db, id_usuario=token_data.id_usuario)
    if user is None:
        raise credentials_exception
    return user

# --- RUTAS ---

@router.post("/register", response_model=user_schemas.Usuario)
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
    """Registra un nuevo usuario."""
    if user_crud.get_user_by_email(db, email=email):
        raise HTTPException(status_code=400, detail="El email ya está registrado")

    url_foto = None
    if foto and isinstance(foto, UploadFile):
        try:
            file_content = foto.file.read()
            file_base64 = base64.b64encode(file_content).decode("utf-8")
            upload_info = imagekit.upload_file(
                file=file_base64,
                file_name=f"perfil_{email}.jpg",
                options={
                    "folder": "/fotos_perfil/",
                    "is_private_file": False,
                    "use_unique_file_name": True
                }
            )
            url_foto = upload_info.url
        except Exception as e:
            print(f"Error subiendo foto: {e}")

    user_data = user_schemas.UsuarioCreate(
        email=email,
        password=password,
        nombre=nombre,
        apellidos=apellidos,
        latitud=latitud,
        longitud=longitud
    )
    return user_crud.create_user(db=db, user=user_data, url_foto=url_foto)

@router.post("/token", response_model=schemas.Token, summary="Iniciar sesión y obtener un token")
def login_for_access_token(
    db: Session = Depends(get_db),
    form_data: OAuth2PasswordRequestForm = Depends()
):
    """Genera el token de acceso JWT."""
    user = user_crud.get_user_by_email(db, email=form_data.username)
    if not user or not security.verify_password(form_data.password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Email o contraseña incorrectos",
            headers={"WWW-Authenticate": "Bearer"},
        )
    access_token = create_access_token(data={"sub": str(user.id_usuario)})
    return {"access_token": access_token, "token_type": "bearer"}

@router.post("/logout", status_code=status.HTTP_200_OK, summary="Cerrar sesión")
def logout_user(current_user: models.Usuario = Depends(get_current_user)):
    """Informa al servidor de un logout exitoso (estataless)."""
    return {"msg": "Cierre de sesión exitoso. El token debe ser eliminado por el cliente."}
