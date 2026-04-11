# --- Archivo NUEVO: /app/routes/routes_publicacion.py ---

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List

# Importaciones relativas
from .. import crud, models, schemas
from ..database import get_db
from ..auth import get_current_user  # Importamos nuestra dependencia de autenticación

router = APIRouter(
    prefix="/publicaciones",
    tags=["Publicaciones (Foro)"]
)

from fastapi import APIRouter, Depends, HTTPException, status, File, UploadFile, Form
from ..services.imagekit_service import upload_image_to_imagekit

# ... imports ...

@router.post("/",
    response_model=schemas.Publicacion,
    status_code=status.HTTP_201_CREATED,
    summary="Crear una nueva publicación en el foro"
)
async def create_publicacion_endpoint(
    titulo: str = Form(...),
    texto: str = Form(...),
    file: UploadFile = File(None),
    db: Session = Depends(get_db),
    current_user: models.Usuario = Depends(get_current_user)
):
    """
    Crea un nuevo post en el foro, asociado al usuario autenticado.
    Soporta subida de imagen (Multipart).
    """
    links_fotos = []
    
    # 1. Si hay archivo, lo subimos
    with open("debug_log.txt", "a") as f:
        f.write(f"Request received. Title: {titulo}, File present: {file is not None}\n")

    if file:
        try:
            file_bytes = await file.read()
            with open("debug_log.txt", "a") as f:
                f.write(f"File bytes read: {len(file_bytes)}\n")
            
            # Guardamos en la carpeta específica del Foro
            image_url = upload_image_to_imagekit(file_bytes, file.filename, folder="/vitia/Foro")
            
            with open("debug_log.txt", "a") as f:
                f.write(f"ImageKit URL: {image_url}\n")
                
            links_fotos.append(image_url)
        except Exception as e:
            with open("debug_log.txt", "a") as f:
                f.write(f"Error subiendo a ImageKit: {e}\n")
            print(f"Error subiendo a ImageKit: {e}")
            # Opcional: Fallar o continuar sin imagen. Aquí continuamos pero logueamos.

    # 2. Creamos el objeto esquema manually
    publicacion_create = schemas.PublicacionCreate(
        titulo=titulo,
        texto=texto,
        links_fotos=links_fotos
    )

    # 3. Llama a la función CRUD
    return crud.create_publicacion(
        db=db, 
        publicacion=publicacion_create, 
        id_usuario=current_user.id_usuario
    )


@router.get("/",
    response_model=List[schemas.Publicacion],
    summary="Obtener todas las publicaciones del foro (Feed)"
)
def read_publicaciones_endpoint(
    skip: int = 0,
    limit: int = 100,
    db: Session = Depends(get_db),
    current_user: models.Usuario = Depends(get_current_user)
):
    """
    Obtiene una lista paginada de todas las publicaciones de todos los usuarios,
    ordenadas por fecha (la más reciente primero).
    
    Incluye el estado 'is_liked' para el usuario actual.
    """
    publicaciones = crud.get_publicaciones(db, skip=skip, limit=limit)
    
    # Enriquecer con is_liked
    for pub in publicaciones:
        # Verificar si existe un voto del usuario actual para esta publicación
        voto = db.query(models.VotoPublicacion).filter(
            models.VotoPublicacion.id_publicacion == pub.id_publicacion,
            models.VotoPublicacion.id_usuario == current_user.id_usuario,
            models.VotoPublicacion.es_like == True
        ).first()
        
        # Asignamos el atributo dinámicamente. 
        # Pydantic (from_attributes=True) lo leerá.
        pub.is_liked = (voto is not None)
        
        # Calcular total de comentarios (incluyendo respuestas)
        pub.num_comentarios = db.query(models.Comentario).filter(
            models.Comentario.id_publicacion == pub.id_publicacion,
            models.Comentario.borrado == False
        ).count()

    return publicaciones

@router.get("/me",
    response_model=List[schemas.Publicacion],
    summary="Obtener todas las publicaciones del usuario actual"
)
def read_user_publicaciones_endpoint(
    db: Session = Depends(get_db),
    current_user: models.Usuario = Depends(get_current_user),
    skip: int = 0,
    limit: int = 100
):
    """
    Obtiene una lista paginada de todas las publicaciones
    creadas por el usuario actualmente autenticado.
    """
    publicaciones = crud.get_user_publicaciones(
        db=db, 
        id_usuario=current_user.id_usuario, 
        skip=skip, 
        limit=limit
    )
    
    # Enriquecer con is_liked (el usuario puede dar like a sus propios posts)
    for pub in publicaciones:
        voto = db.query(models.VotoPublicacion).filter(
            models.VotoPublicacion.id_publicacion == pub.id_publicacion,
            models.VotoPublicacion.id_usuario == current_user.id_usuario,
            models.VotoPublicacion.es_like == True
        ).first()
        pub.is_liked = (voto is not None)
        
        # Calcular total de comentarios
        pub.num_comentarios = db.query(models.Comentario).filter(
            models.Comentario.id_publicacion == pub.id_publicacion,
            models.Comentario.borrado == False
        ).count()

    return publicaciones

@router.delete("/{id_publicacion}",
    response_model=schemas.Publicacion,
    summary="Eliminar una publicación del foro"
)
def delete_publicacion_endpoint(
    id_publicacion: int,
    db: Session = Depends(get_db),
    current_user: models.Usuario = Depends(get_current_user)
):
    """
    Elimina una publicación.
    
    - Solo el autor original de la publicación puede eliminarla.
    """
    # 1. Obtener la publicación
    db_publicacion = crud.get_publicacion(db, id_publicacion=id_publicacion)
    
    # 2. Verificar si existe
    if db_publicacion is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Publicación no encontrada"
        )
    
    # 3. Verificar que el usuario es el autor (¡Importante!)
    if db_publicacion.id_usuario != current_user.id_usuario:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="No tienes permiso para eliminar esta publicación"
        )
    
    # 4. Eliminar la publicación
    return crud.delete_publicacion(db=db, db_publicacion=db_publicacion)

# --- VOTOS ---
@router.post("/{id_publicacion}/voto", summary="Votar Publicación")
def votar_publicacion_endpoint(
    id_publicacion: int,
    voto: schemas.VotoCreate, # Recibe { "es_like": true/false/null }
    db: Session = Depends(get_db),
    current_user: models.Usuario = Depends(get_current_user)
):
    """
    - **es_like: true** -> Like
    - **es_like: false** -> Dislike
    - **es_like: null** -> Borrar voto (Neutro)
    """
    estado = crud.votar_publicacion(db, current_user.id_usuario, id_publicacion, voto.es_like)
    return {"msg": estado}

@router.post("/{id_publicacion}/like", summary="Dar Like (Legacy)")
def like_publicacion_endpoint(
    id_publicacion: int,
    db: Session = Depends(get_db),
    current_user: models.Usuario = Depends(get_current_user)
):
    """Endpoint simplificado para dar like (compatible con frontend anterior)"""
    return crud.votar_publicacion(db, current_user.id_usuario, id_publicacion, True)

@router.post("/{id_publicacion}/unlike", summary="Quitar Like (Legacy)")
def unlike_publicacion_endpoint(
    id_publicacion: int,
    db: Session = Depends(get_db),
    current_user: models.Usuario = Depends(get_current_user)
):
    """Endpoint simplificado para quitar like (compatible con frontend anterior)"""
    # Unlike suele significar 'quitar el like', es decir, volver a neutro (None)
    return crud.votar_publicacion(db, current_user.id_usuario, id_publicacion, None)
