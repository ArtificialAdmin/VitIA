from sqlalchemy.orm import Session, joinedload
from app.core import models
from . import schemas
from typing import List, Optional

# --- PUBLICACIONES ---

def create_publicacion(db: Session, publicacion: schemas.PublicacionCreate, id_usuario: int):
    db_publicacion = models.Publicacion(
        titulo=publicacion.titulo,
        texto=publicacion.texto,
        links_fotos=publicacion.links_fotos,
        id_usuario=id_usuario
    )
    if publicacion.variedades_ids:
        variedades_db = db.query(models.Variedad).filter(
            models.Variedad.id_variedad.in_(publicacion.variedades_ids)
        ).all()
        db_publicacion.variedades = variedades_db
    db.add(db_publicacion)
    db.commit()
    db.refresh(db_publicacion)
    return db_publicacion

def get_publicacion(db: Session, id_publicacion: int):
    return db.query(models.Publicacion).filter(models.Publicacion.id_publicacion == id_publicacion).first()

def get_publicaciones(db: Session, skip: int = 0, limit: int = 100):
    return db.query(models.Publicacion)\
             .options(joinedload(models.Publicacion.autor))\
             .order_by(models.Publicacion.fecha_publicacion.desc())\
             .offset(skip)\
             .limit(limit)\
             .all()

def delete_publicacion(db: Session, db_publicacion: models.Publicacion):
    db.delete(db_publicacion)
    db.commit()
    return db_publicacion

# --- COMENTARIOS ---

def create_comentario(db: Session, comentario: schemas.ComentarioCreate, id_usuario: int):
    db_comentario = models.Comentario(
        texto=comentario.texto,
        id_publicacion=comentario.id_publicacion,
        id_padre=comentario.id_padre,
        id_usuario=id_usuario
    )
    db.add(db_comentario)
    db.commit()
    db.refresh(db_comentario)
    return db_comentario

def get_comentarios_publicacion(db: Session, id_publicacion: int, skip: int = 0, limit: int = 100):
    return db.query(models.Comentario)\
             .filter(models.Comentario.id_publicacion == id_publicacion)\
             .filter(models.Comentario.id_padre == None)\
             .order_by(models.Comentario.fecha_comentario.asc())\
             .offset(skip)\
             .limit(limit)\
             .all()

def delete_comentario(db: Session, id_comentario: int, id_usuario: int):
    db_comentario = db.query(models.Comentario).filter(
        models.Comentario.id_comentario == id_comentario,
        models.Comentario.id_usuario == id_usuario
    ).first()
    if db_comentario:
        db_comentario.borrado = True
        db_comentario.texto = "Este comentario ha sido eliminado"
        db.commit()
        db.refresh(db_comentario)
    return db_comentario

# --- LOGICA DE VOTOS (Simplificada para el módulo) ---

def _actualizar_contador_likes(db: Session, modelo_voto, modelo_padre, id_campo_fk, id_valor_fk, columna_likes_padre):
    filtro = {id_campo_fk: id_valor_fk, "es_like": True}
    total_likes = db.query(modelo_voto).filter_by(**filtro).count()
    db.query(modelo_padre).filter(
        getattr(modelo_padre, id_campo_fk) == id_valor_fk
    ).update({columna_likes_padre: total_likes})
    db.commit()

def gestionar_voto(db: Session, modelo_voto, modelo_padre, id_usuario: int, id_campo_fk, id_valor_fk, es_like: Optional[bool]):
    filtro = {"id_usuario": id_usuario, id_campo_fk: id_valor_fk}
    voto_existente = db.query(modelo_voto).filter_by(**filtro).first()
    estado = ""
    if es_like is None:
        if voto_existente:
            db.delete(voto_existente)
            estado = "voto_eliminado"
        else:
            estado = "sin_cambios"
    elif voto_existente:
        if voto_existente.es_like != es_like:
            voto_existente.es_like = es_like
            estado = "voto_actualizado"
        else:
            estado = "sin_cambios"
    else:
        nuevo_voto = modelo_voto(es_like=es_like, **filtro)
        db.add(nuevo_voto)
        estado = "voto_creado"
    db.commit()
    if estado != "sin_cambios":
        _actualizar_contador_likes(db, modelo_voto, modelo_padre, id_campo_fk, id_valor_fk, "likes")
    return estado

def votar_publicacion(db: Session, id_usuario: int, id_publicacion: int, es_like: Optional[bool]):
    return gestionar_voto(db, models.VotoPublicacion, models.Publicacion, id_usuario, "id_publicacion", id_publicacion, es_like)

def votar_comentario(db: Session, id_usuario: int, id_comentario: int, es_like: Optional[bool]):
    return gestionar_voto(db, models.VotoComentario, models.Comentario, id_usuario, "id_comentario", id_comentario, es_like)
