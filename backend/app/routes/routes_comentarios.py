# --- Archivo NUEVO: app/routes/routes_comentario.py ---

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List

from .. import crud, models, schemas
from ..database import get_db
from ..auth import get_current_user

router = APIRouter(
    prefix="/comentarios",
    tags=["Comentarios"]
)

@router.post("/", 
    response_model=schemas.Comentario,
    status_code=status.HTTP_201_CREATED,
    summary="Comentar una publicación o responder a otro comentario"
)
def create_comentario_endpoint(
    comentario: schemas.ComentarioCreate,
    db: Session = Depends(get_db),
    current_user: models.Usuario = Depends(get_current_user)
):
    """
    Crea un comentario.
    - **id_publicacion**: ID del post.
    - **texto**: Contenido.
    - **id_padre**: (Opcional) ID del comentario al que respondes.
    """
    # Opcional: Validar que la publicación existe
    # Opcional: Validar que si hay id_padre, este existe
    
    return crud.create_comentario(db=db, comentario=comentario, id_usuario=current_user.id_usuario)

@router.get("/publicacion/{id_publicacion}",
    response_model=List[schemas.Comentario],
    summary="Obtener comentarios de una publicación"
)
def read_comentarios_publicacion(
    id_publicacion: int,
    skip: int = 0,
    limit: int = 100,
    db: Session = Depends(get_db),
    current_user: models.Usuario = Depends(get_current_user) # Opcional si permites ver sin login, pero aquí parece requerido para consistencia
):
    """
    Devuelve los comentarios en estructura de árbol (anidados).
    """
    comentarios = crud.get_comentarios_publicacion(db=db, id_publicacion=id_publicacion, skip=skip, limit=limit)
    
    # Enriquecer con is_liked recursivamente
    def enriquecer_recursivo(lista):
        for c in lista:
            voto = db.query(models.VotoComentario).filter(
                models.VotoComentario.id_comentario == c.id_comentario,
                models.VotoComentario.id_usuario == current_user.id_usuario,
                models.VotoComentario.es_like == True
            ).first()
            c.is_liked = (voto is not None)
            if c.hijos:
                enriquecer_recursivo(c.hijos)

    enriquecer_recursivo(comentarios)
    return comentarios

@router.delete("/{id_comentario}",
    summary="Eliminar un comentario"
)
def delete_comentario_endpoint(
    id_comentario: int,
    db: Session = Depends(get_db),
    current_user: models.Usuario = Depends(get_current_user)
):
    db_comentario = crud.delete_comentario(db=db, id_comentario=id_comentario, id_usuario=current_user.id_usuario)
    if db_comentario is None:
        raise HTTPException(status_code=404, detail="Comentario no encontrado o no autorizado")
    return {"msg": "Comentario eliminado"}

@router.post("/{id_comentario}/voto", summary="Votar Comentario")
def votar_comentario_endpoint(
    id_comentario: int,
    voto: schemas.VotoCreate,
    db: Session = Depends(get_db),
    current_user: models.Usuario = Depends(get_current_user)
):
    estado = crud.votar_comentario(db, current_user.id_usuario, id_comentario, voto.es_like)
    return {"msg": estado}