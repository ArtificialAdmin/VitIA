# --- Reemplaza el contenido de /app/routes/routes_coleccion.py con esto ---

from fastapi import APIRouter, Depends, HTTPException, status, UploadFile, File, Form
from sqlalchemy.orm import Session
from typing import List

# Importaciones relativas
from .. import crud, models, schemas
from ..database import get_db
from ..auth import get_current_user  # <-- ¡Importamos el REAL!
from ..services.imagekit_service import upload_image_to_imagekit
from datetime import datetime

router = APIRouter(
    prefix="/coleccion",
    tags=["Colección (Personal)"]
)

# -----------------------------------------------------
# ENDPOINTS PARA COLECCIÓN (Ahora con autenticación real)
# -----------------------------------------------------

@router.post("/", 
    response_model=schemas.Coleccion,
    status_code=status.HTTP_201_CREATED,
    summary="Añadir un item a la colección personal"
)
def create_coleccion_item_endpoint(
    item: schemas.ColeccionCreate,
    db: Session = Depends(get_db),
    current_user: models.Usuario = Depends(get_current_user) # <-- Dependencia real
):
    return crud.create_coleccion_item(db=db, item=item, id_usuario=current_user.id_usuario)


@router.get("/",
    response_model=List[schemas.Coleccion],
    summary="Obtener la colección personal del usuario"
)
def read_user_coleccion_endpoint(
    skip: int = 0,
    limit: int = 100,
    db: Session = Depends(get_db),
    current_user: models.Usuario = Depends(get_current_user) # <-- Dependencia real
):
    return crud.get_user_coleccion(db=db, id_usuario=current_user.id_usuario, skip=skip, limit=limit)

@router.get("/mapa",
    response_model=List[schemas.Coleccion],
    summary="Obtener todas las identificaciones con ubicación para el mapa"
)
def read_colecciones_mapa_endpoint(
    modo: str = "publico",
    db: Session = Depends(get_db),
    current_user: models.Usuario = Depends(get_current_user)
):
    """
    Obtiene todas las identificaciones/colecciones que contengan coordenadas,
    ideal para pintarlas en el mapa.
    """
    colecciones = crud.get_colecciones_mapa(db, modo=modo, id_usuario=current_user.id_usuario)
    return colecciones

@router.get("/{id_coleccion}",
    response_model=schemas.Coleccion,
    summary="Obtener un item específico de la colección"
)
def read_coleccion_item_endpoint(
    id_coleccion: int,
    db: Session = Depends(get_db),
    current_user: models.Usuario = Depends(get_current_user) # <-- Dependencia real
):
    db_item = crud.get_coleccion_item(db=db, id_coleccion=id_coleccion, id_usuario=current_user.id_usuario)
    if db_item is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Item de colección no encontrado o no pertenece al usuario"
        )
    return db_item


@router.patch("/{id_coleccion}",
    response_model=schemas.Coleccion,
    summary="Actualizar un item de la colección (Parcial)"
)
def update_coleccion_item_endpoint(
    id_coleccion: int,
    item_update: schemas.ColeccionUpdate,
    db: Session = Depends(get_db),
    current_user: models.Usuario = Depends(get_current_user) # <-- Dependencia real
):
    """
    Actualiza un item de la colección (ej. cambiar la foto o la variedad).
    Solo el propietario puede actualizar.
    """
    db_item = crud.get_coleccion_item(db=db, id_coleccion=id_coleccion, id_usuario=current_user.id_usuario)
    if db_item is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Item de colección no encontrado o no pertenece al usuario"
        )
    
    return crud.update_coleccion_item(db=db, db_item=db_item, item_update=item_update)


@router.delete("/{id_coleccion}",
    summary="Eliminar un item de la colección"
)
def delete_coleccion_item_endpoint(
    id_coleccion: int,
    db: Session = Depends(get_db),
    current_user: models.Usuario = Depends(get_current_user)
):
    # Retrieve first to check existence (and ownership)
    db_item = crud.delete_coleccion_item(db=db, id_coleccion=id_coleccion, id_usuario=current_user.id_usuario)
    if db_item is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Item de colección no encontrado o no pertenece al usuario"
        )
    # Don't return the object as it is detached and might have lazy loads
    return {"message": "Item eliminado correctamente", "id": id_coleccion}

@router.post("/upload", response_model=schemas.Coleccion)
async def create_coleccion_with_image(
    file: UploadFile = File(...),
    nombre_variedad: str = Form(...), # <--- CAMBIO: Recibimos NOMBRE, no ID
    notas: str = Form(None),
    latitud: float = Form(None),
    longitud: float = Form(None),
    es_publica: bool = Form(True),
    current_user: models.Usuario = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    # 1. Lógica inteligente: Buscar ID o Crear Variedad
    # Usamos las funciones que creamos en crud.py
    variedad_db = crud.get_variedad_by_nombre(db, nombre_variedad)
    
    if not variedad_db:
        # ¡Si no existe, la creamos al vuelo!
        print(f"Variedad '{nombre_variedad}' no existe. Creándola...")
        variedad_db = crud.create_variedad_automatica(db, nombre_variedad)
    
    id_real_variedad = variedad_db.id_variedad

    # 2. Subir imagen (Igual que antes)
    try:
        file_bytes = await file.read()
        image_url = upload_image_to_imagekit(file_bytes, file.filename)
    except Exception as e:
        raise HTTPException(status_code=500, detail="Error ImageKit")

    # 3. Guardar en Colección usando el ID real que acabamos de obtener
    nuevo_item = models.Coleccion(
        id_usuario=current_user.id_usuario,
        id_variedad=id_real_variedad, # <--- Usamos el ID recuperado/creado
        path_foto_usuario=image_url,
        fecha_captura=datetime.utcnow(),
        notas=notas,
        latitud=latitud,
        longitud=longitud,
        es_publica=es_publica
    )
    
    db.add(nuevo_item)
    db.commit()
    db.refresh(nuevo_item)
    
    return nuevo_item

@router.get("/mapa",
    response_model=List[schemas.Coleccion],
    summary="Obtener todas las identificaciones con ubicación para el mapa"
)
def read_colecciones_mapa_endpoint(
    modo: str = "publico",
    db: Session = Depends(get_db),
    current_user: models.Usuario = Depends(get_current_user)
):
    """
    Obtiene todas las identificaciones/colecciones que contengan coordenadas,
    ideal para pintarlas en el mapa.
    """
    colecciones = crud.get_colecciones_mapa(db, modo=modo, id_usuario=current_user.id_usuario)
    return colecciones