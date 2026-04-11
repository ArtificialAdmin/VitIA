from sqlalchemy.orm import Session
from app.core import models
from . import schemas
from typing import List, Optional

def get_variedad(db: Session, id_variedad: int):
    """Obtiene una variedad específica por su ID."""
    return db.query(models.Variedad).filter(models.Variedad.id_variedad == id_variedad).first()

def get_variedad_by_nombre(db: Session, nombre: str):
    """Obtiene una variedad por nombre."""
    return db.query(models.Variedad).filter(models.Variedad.nombre == nombre).first()

def get_variedades(db: Session, skip: int = 0, limit: int = 100):
    """Obtiene lista paginada de variedades."""
    return db.query(models.Variedad).offset(skip).limit(limit).all()

def create_variedad(db: Session, variedad: schemas.VariedadCreate):
    """Crea una nueva variedad."""
    db_variedad = models.Variedad(**variedad.model_dump())
    db.add(db_variedad)
    db.commit()
    db.refresh(db_variedad)
    return db_variedad

def update_variedad(db: Session, db_variedad: models.Variedad, variedad_update: schemas.VariedadUpdate):
    """Actualiza una variedad existente."""
    update_data = variedad_update.model_dump(exclude_unset=True)
    for key, value in update_data.items():
        setattr(db_variedad, key, value)
    db.add(db_variedad)
    db.commit()
    db.refresh(db_variedad)
    return db_variedad

def delete_variedad(db: Session, id_variedad: int):
    """Elimina una variedad de la base de datos."""
    db_variedad = get_variedad(db, id_variedad)
    if db_variedad:
        db.delete(db_variedad)
        db.commit()
    return db_variedad

def create_variedad_automatica(db: Session, nombre: str):
    """Crea una variedad nueva con datos por defecto tras identificación IA."""
    nueva_variedad = models.Variedad(
        nombre=nombre,
        descripcion=f"Variedad identificada automáticamente por VitIA: {nombre}",
    )
    db.add(nueva_variedad)
    db.commit()
    db.refresh(nueva_variedad)
    return nueva_variedad

def check_variedad_in_coleccion(db: Session, id_usuario: int, id_variedad: int) -> bool:
    """Devuelve True si el usuario tiene esta variedad registrada."""
    item = db.query(models.Coleccion).filter(
        models.Coleccion.id_usuario == id_usuario,
        models.Coleccion.id_variedad == id_variedad
    ).first()
    return item is not None

def toggle_favorito(db: Session, id_usuario: int, id_variedad: int):
    """Añade o quita una variedad de favoritos."""
    user = db.query(models.Usuario).get(id_usuario)
    variedad = db.query(models.Variedad).get(id_variedad)
    if not variedad or not user:
        return None
    if variedad in user.favoritos:
        user.favoritos.remove(variedad)
        action = "eliminado de"
    else:
        user.favoritos.append(variedad)
        action = "añadido a"
    db.commit()
    return action
