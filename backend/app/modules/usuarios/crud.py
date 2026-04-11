from sqlalchemy.orm import Session
from app.core import models, security
from . import schemas
from typing import List, Optional

def get_user(db: Session, id_usuario: int):
    """Obtiene un usuario por su ID."""
    return db.query(models.Usuario).filter(models.Usuario.id_usuario == id_usuario).first()

def get_user_by_email(db: Session, email: str):
    """Obtiene un usuario por su email."""
    return db.query(models.Usuario).filter(models.Usuario.email == email).first()

def create_user(db: Session, user: schemas.UsuarioCreate, url_foto: str = None):
    """Crea un nuevo usuario en la BBDD."""
    hashed_password = security.get_password_hash(user.password)
    
    db_user = models.Usuario(
        nombre=user.nombre,
        apellidos=user.apellidos,
        email=user.email,
        password_hash=hashed_password,
        latitud=user.latitud,
        longitud=user.longitud,
        path_foto_perfil=url_foto,
        tutorial_superado=False
    )
    db.add(db_user)
    db.commit()
    db.refresh(db_user)
    return db_user

def update_user(db: Session, db_user: models.Usuario, user_update: schemas.UsuarioUpdate):
    """Actualiza los datos de un usuario."""
    update_data = user_update.model_dump(exclude_unset=True)
    
    for key, value in update_data.items():
        setattr(db_user, key, value)
    
    db.add(db_user)
    db.commit()
    db.refresh(db_user)
    return db_user

def delete_user(db: Session, id_usuario: int):
    """Elimina un usuario por su ID."""
    db_user = get_user(db, id_usuario=id_usuario)
    if db_user:
        db.delete(db_user)
        db.commit()
    return db_user

def get_user_favoritos(db: Session, id_usuario: int, skip: int = 0, limit: int = 100):
    """Obtiene la lista de variedades favoritas de un usuario."""
    user = get_user(db, id_usuario)
    if not user:
        return []

    return db.query(models.Variedad)\
             .join(models.favoritos_assoc)\
             .filter(models.favoritos_assoc.c.id_usuario == id_usuario)\
             .offset(skip)\
             .limit(limit)\
             .all()
