from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List

from app.core import models
from app.core.database import get_db
from app.modules.auth.router import get_current_user
from . import crud, schemas

router = APIRouter(
    prefix="/variedades",
    tags=["Variedades (Biblioteca)"]
)

@router.post("/", response_model=schemas.Variedad, status_code=status.HTTP_201_CREATED, summary="Crear variedad")
def create_variedad_endpoint(variedad: schemas.VariedadCreate, db: Session = Depends(get_db)):
    """Crea una nueva variedad en la biblioteca."""
    db_variedad = crud.get_variedad_by_nombre(db, nombre=variedad.nombre)
    if db_variedad:
        raise HTTPException(status_code=400, detail="Ya existe")
    return crud.create_variedad(db=db, variedad=variedad)

@router.get("/", response_model=List[schemas.Variedad], summary="Listar variedades")
def read_variedades_endpoint(skip: int = 0, limit: int = 100, db: Session = Depends(get_db)):
    """Obtiene todas las variedades."""
    return crud.get_variedades(db, skip=skip, limit=limit)

@router.get("/{id_variedad}", response_model=schemas.Variedad, summary="Detalle de variedad")
def read_variedad_endpoint(id_variedad: int, db: Session = Depends(get_db)):
    """Obtiene una variedad por ID."""
    db_variedad = crud.get_variedad(db, id_variedad=id_variedad)
    if not db_variedad:
        raise HTTPException(status_code=404, detail="No encontrada")
    return db_variedad

@router.patch("/{id_variedad}", response_model=schemas.Variedad, summary="Actualizar variedad")
def update_variedad_endpoint(id_variedad: int, variedad_update: schemas.VariedadUpdate, db: Session = Depends(get_db)):
    """Actualiza parcialmente una variedad."""
    db_variedad = crud.get_variedad(db, id_variedad=id_variedad)
    if not db_variedad:
        raise HTTPException(status_code=404, detail="No encontrada")
    return crud.update_variedad(db=db, db_variedad=db_variedad, variedad_update=variedad_update)

@router.delete("/{id_variedad}", response_model=schemas.Variedad, summary="Eliminar variedad")
def delete_variedad_endpoint(id_variedad: int, db: Session = Depends(get_db)):
    """Borra una variedad."""
    db_variedad = crud.delete_variedad(db, id_variedad=id_variedad)
    if not db_variedad:
        raise HTTPException(status_code=404, detail="No encontrada")
    return db_variedad

@router.get("/check/{id_variedad}", summary="Verificar registro")
def check_variedad_endpoint(
    id_variedad: int,
    db: Session = Depends(get_db),
    current_user: models.Usuario = Depends(get_current_user)
):
    """Verifica si el usuario tiene esta variedad en su colección."""
    en_coleccion = crud.check_variedad_in_coleccion(db, current_user.id_usuario, id_variedad)
    return {"en_coleccion": en_coleccion}

@router.post("/{id_variedad}/favorito", summary="Favorito Toggle")
def toggle_favorito_endpoint(
    id_variedad: int,
    db: Session = Depends(get_db),
    current_user: models.Usuario = Depends(get_current_user)
):
    """Marca/desmarca una variedad como favorita."""
    resultado = crud.toggle_favorito(db, current_user.id_usuario, id_variedad)
    if not resultado:
        raise HTTPException(status_code=404, detail="No encontrada")
    return {"msg": f"Variedad {resultado} favoritos"}
