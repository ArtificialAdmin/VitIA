from sqlalchemy.orm import Session, joinedload
from app.core import models
from . import schemas
from datetime import datetime

def get_validaciones_pendientes(db: Session, skip: int = 0, limit: int = 100):
    return db.query(models.ValidacionExperto)\
             .options(joinedload(models.ValidacionExperto.coleccion).joinedload(models.Coleccion.variedad))\
             .filter(models.ValidacionExperto.estado == "pendiente")\
             .order_by(models.ValidacionExperto.solicitada_en.desc())\
             .offset(skip)\
             .limit(limit)\
             .all()

def update_validacion(db: Session, id_validacion: int, id_experto: int, validacion_update: schemas.ValidacionExpertoUpdate):
    db_val = db.query(models.ValidacionExperto).filter(models.ValidacionExperto.id_validacion == id_validacion).first()
    if not db_val:
        return None
    
    db_val.id_experto = id_experto
    db_val.es_correcta = validacion_update.es_correcta
    db_val.feedback_experto = validacion_update.feedback_experto
    db_val.evaluacion_imagenes = validacion_update.evaluacion_imagenes
    db_val.validada_en = datetime.utcnow()
    db_val.estado = "validada"
    
    # Procesar imágenes para guardarlas en la nueva tabla AnotacionesImagenes
    if validacion_update.evaluacion_imagenes:
        # Obtenemos la variedad de la colección para asociarla a la foto
        coleccion = db_val.coleccion
        id_variedad = coleccion.id_variedad
        
        for eval_img in validacion_update.evaluacion_imagenes:
            url_img = eval_img.get("url")
            es_buena = eval_img.get("valida")
            
            if url_img and es_buena is not None:
                db_anotacion = models.AnotacionImagen(
                    url_imagen=url_img,
                    es_buena=es_buena,
                    id_validacion=db_val.id_validacion,
                    id_variedad=id_variedad
                )
                db.add(db_anotacion)
    
    db.commit()
    db.refresh(db_val)
    return db_val
