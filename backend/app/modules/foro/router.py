from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List

from app.core import models
from app.core.database import get_db
from app.modules.auth.router import get_current_user
from . import crud, schemas

router = APIRouter(
    prefix="/foro",
    tags=["Foro"]
)

# --- PUBLICACIONES ---

@router.post("/", response_model=schemas.Publicacion, summary="Crear publicación")
def create_post(
    publicacion: schemas.PublicacionCreate,
    db: Session = Depends(get_db),
    current_user: models.Usuario = Depends(get_current_user)
):
    """Crea una nueva publicación en el foro."""
    return crud.create_publicacion(db=db, publicacion=publicacion, id_usuario=current_user.id_usuario)

@router.get("/", response_model=List[schemas.Publicacion], summary="Listar publicaciones")
def list_posts(
    skip: int = 0,
    limit: int = 20,
    db: Session = Depends(get_db),
    current_user: models.Usuario = Depends(get_current_user)
):
    """Obtiene el feed de publicaciones del foro."""
    publicaciones = crud.get_publicaciones(db, skip=skip, limit=limit)
    
    # Marcamos si el usuario actual le dio like
    for post in publicaciones:
        voto = db.query(models.VotoPublicacion).filter_by(
            id_usuario=current_user.id_usuario, 
            id_publicacion=post.id_publicacion
        ).first()
        post.is_liked = voto.es_like if voto else None
        post.num_comentarios = len(post.comentarios)
        
    return publicaciones

@router.get("/{id_publicacion}", response_model=schemas.Publicacion, summary="Detalle de publicación")
def get_post(
    id_publicacion: int,
    db: Session = Depends(get_db),
    current_user: models.Usuario = Depends(get_current_user)
):
    """Obtiene una publicación específica."""
    post = crud.get_publicacion(db, id_publicacion)
    if not post:
        raise HTTPException(status_code=404, detail="Publicación no encontrada")
    
    voto = db.query(models.VotoPublicacion).filter_by(
        id_usuario=current_user.id_usuario, 
        id_publicacion=id_publicacion
    ).first()
    post.is_liked = voto.es_like if voto else None
    return post

@router.delete("/{id_publicacion}", summary="Borrar publicación")
def delete_post(
    id_publicacion: int,
    db: Session = Depends(get_db),
    current_user: models.Usuario = Depends(get_current_user)
):
    """Elimina una publicación si el usuario es el autor."""
    db_publicacion = crud.get_publicacion(db, id_publicacion)
    if not db_publicacion:
        raise HTTPException(status_code=404, detail="No existe")
    if db_publicacion.id_usuario != current_user.id_usuario:
        raise HTTPException(status_code=403, detail="No autorizado")
    
    crud.delete_publicacion(db, db_publicacion)
    return {"msg": "Eliminado correctamente"}

# --- VOTOS PUBLICACION ---

@router.post("/{id_publicacion}/voto", summary="Votar publicación")
def vote_post(
    id_publicacion: int,
    voto: schemas.VotoCreate,
    db: Session = Depends(get_db),
    current_user: models.Usuario = Depends(get_current_user)
):
    """Da like, dislike o quita el voto a una publicación."""
    estado = crud.votar_publicacion(db, current_user.id_usuario, id_publicacion, voto.es_like)
    return {"status": estado}

# --- COMENTARIOS ---

@router.post("/comentarios", response_model=schemas.Comentario, summary="Crear comentario")
def create_comment(
    comentario: schemas.ComentarioCreate,
    db: Session = Depends(get_db),
    current_user: models.Usuario = Depends(get_current_user)
):
    """Crea un comentario o respuesta."""
    return crud.create_comentario(db, comentario, current_user.id_usuario)

@router.get("/{id_publicacion}/comentarios", response_model=List[schemas.Comentario], summary="Listar comentarios")
def list_comments(
    id_publicacion: int,
    db: Session = Depends(get_db),
    current_user: models.Usuario = Depends(get_current_user)
):
    """Obtiene los comentarios de una publicación (con respuestas)."""
    comentarios = crud.get_comentarios_publicacion(db, id_publicacion)
    
    # Marcar is_liked recursivamente (simplificado para el listado inicial)
    for c in comentarios:
        voto = db.query(models.VotoComentario).filter_by(
            id_usuario=current_user.id_usuario, 
            id_comentario=c.id_comentario
        ).first()
        c.is_liked = voto.es_like if voto else None
        
    return comentarios

@router.delete("/comentarios/{id_comentario}", summary="Borrar comentario")
def delete_comment(
    id_comentario: int,
    db: Session = Depends(get_db),
    current_user: models.Usuario = Depends(get_current_user)
):
    """Soft-delete de un comentario."""
    ok = crud.delete_comentario(db, id_comentario, current_user.id_usuario)
    if not ok:
        raise HTTPException(status_code=404, detail="No encontrado o no eres el autor")
    return {"msg": "Comentario eliminado"}

@router.post("/comentarios/{id_comentario}/voto", summary="Votar comentario")
def vote_comment(
    id_comentario: int,
    voto: schemas.VotoCreate,
    db: Session = Depends(get_db),
    current_user: models.Usuario = Depends(get_current_user)
):
    """Da like, dislike o quita el voto a un comentario."""
    estado = crud.votar_comentario(db, current_user.id_usuario, id_comentario, voto.es_like)
    return {"status": estado}
