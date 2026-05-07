from sqlalchemy.orm import Session, joinedload
from app.core import models
from . import schemas

def create_coleccion_item(db: Session, item: schemas.ColeccionCreate, id_usuario: int):
    """Crea un nuevo item en la colección de un usuario."""
    db_item = models.Coleccion(
        **item.model_dump(),
        id_usuario=id_usuario
    )
    db.add(db_item)
    db.commit()
    db.refresh(db_item)
    
    if getattr(db_item, "solicita_validacion_experto", False) and getattr(db_item, "es_premium", False):
        db_validacion = models.ValidacionExperto(
            id_coleccion=db_item.id_coleccion
        )
        db.add(db_validacion)
        db.commit()
        
        # Enviar notificación PUSH a los expertos
        from app.services.push_notifications import send_push_notification
        expertos = db.query(models.Usuario).filter(models.Usuario.rol == "experto").all()
        tokens = [e.fcm_token for e in expertos if e.fcm_token]
        if tokens:
            send_push_notification(
                tokens=tokens,
                title="Nueva Validación Pendiente",
                body="Un usuario ha solicitado validación de una imagen premium.",
                data={"id_coleccion": str(db_item.id_coleccion)}
            )
        
    return db_item

def get_user_coleccion(db: Session, id_usuario: int, skip: int = 0, limit: int = 100):
    """Obtiene una lista paginada de la colección de un usuario."""
    return db.query(models.Coleccion)\
             .options(joinedload(models.Coleccion.validacion))\
             .filter(models.Coleccion.id_usuario == id_usuario)\
             .order_by(models.Coleccion.fecha_captura.desc())\
             .offset(skip)\
             .limit(limit)\
             .all()

def get_coleccion_item(db: Session, id_coleccion: int, id_usuario: int):
    """Obtiene un item específico de la colección."""
    return db.query(models.Coleccion).filter(
        models.Coleccion.id_coleccion == id_coleccion,
        models.Coleccion.id_usuario == id_usuario
    ).first()

def update_coleccion_item(db: Session, db_item: models.Coleccion, item_update: schemas.ColeccionUpdate):
    """Actualiza un item de la colección."""
    update_data = item_update.model_dump(exclude_unset=True)
    for key, value in update_data.items():
        setattr(db_item, key, value)
    db.add(db_item)
    db.commit()
    db.refresh(db_item)
    return db_item

def delete_coleccion_item(db: Session, id_coleccion: int, id_usuario: int):
    """Elimina un item de la colección."""
    db_item = get_coleccion_item(db, id_coleccion, id_usuario)
    if db_item:
        db.delete(db_item)
        db.commit()
    return db_item

def get_colecciones_mapa(db: Session, modo: str = "publico", id_usuario: int = None):
    """Obtiene items para el mapa."""
    query = db.query(models.Coleccion)\
              .options(joinedload(models.Coleccion.propietario))\
              .filter(models.Coleccion.latitud.isnot(None), models.Coleccion.longitud.isnot(None))
    
    if modo == "privado" and id_usuario:
        query = query.filter(models.Coleccion.id_usuario == id_usuario)
    else:
        query = query.filter(models.Coleccion.es_publica == True)
        
    return query.order_by(models.Coleccion.fecha_captura.desc()).all()
