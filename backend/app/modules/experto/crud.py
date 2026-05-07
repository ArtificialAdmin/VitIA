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

def get_validaciones_pendientes_count(db: Session) -> int:
    return db.query(models.ValidacionExperto)\
             .filter(models.ValidacionExperto.estado == "pendiente")\
             .count()

def update_validacion(db: Session, id_validacion: int, id_experto: int, validacion_update: schemas.ValidacionExpertoUpdate):
    db_val = db.query(models.ValidacionExperto).filter(models.ValidacionExperto.id_validacion == id_validacion).first()
    if not db_val:
        return None
    
    db_val.id_experto = id_experto
    db_val.es_correcta = validacion_update.es_correcta
    db_val.feedback_experto = validacion_update.feedback_experto
    db_val.evaluacion_imagenes = validacion_update.evaluacion_imagenes
    db_val.variedad_sugerida = validacion_update.variedad_sugerida
    db_val.validada_en = datetime.utcnow()
    db_val.estado = "validada"
    
    coleccion = db_val.coleccion
    
    if validacion_update.id_variedad_correcta and coleccion:
        coleccion.id_variedad = validacion_update.id_variedad_correcta
        db.add(coleccion)
    elif validacion_update.variedad_sugerida and coleccion:
        # Si introdujo texto libre, buscamos si existe
        var_existente = db.query(models.Variedad).filter(models.Variedad.nombre.ilike(validacion_update.variedad_sugerida)).first()
        if var_existente:
            coleccion.id_variedad = var_existente.id_variedad
        else:
            nueva_var = models.Variedad(
                nombre=validacion_update.variedad_sugerida,
                descripcion="Variedad clasificada por un experto.",
                color="Desconocido"
            )
            db.add(nueva_var)
            db.flush()
            coleccion.id_variedad = nueva_var.id_variedad
        db.add(coleccion)
    
    # Procesar imágenes para guardarlas en la nueva tabla AnotacionesImagenes
    if validacion_update.evaluacion_imagenes and coleccion:
        id_variedad_final = validacion_update.id_variedad_correcta if validacion_update.id_variedad_correcta else coleccion.id_variedad
        
        for eval_img in validacion_update.evaluacion_imagenes:
            url_img = eval_img.get("url")
            es_buena = eval_img.get("valida")
            
            if url_img and es_buena is not None:
                db_anotacion = models.AnotacionImagen(
                    url_imagen=url_img,
                    es_buena=es_buena,
                    id_validacion=db_val.id_validacion,
                    id_variedad=id_variedad_final
                )
                db.add(db_anotacion)
    
    db.commit()
    db.refresh(db_val)
    return db_val

def get_colecciones_sin_evaluar(db: Session, skip: int = 0, limit: int = 100):
    # Devuelve todas las colecciones que NO tienen ValidacionExperto o cuyo estado no es validada/rechazada
    # Usamos outerjoin para incluir las que no tienen validacion
    query = db.query(models.Coleccion)\
              .outerjoin(models.ValidacionExperto)\
              .options(joinedload(models.Coleccion.variedad))\
              .filter(
                  (models.ValidacionExperto.id_validacion == None) | 
                  (models.ValidacionExperto.estado == "pendiente")
              )\
              .order_by(models.Coleccion.fecha_captura.desc())\
              .offset(skip)\
              .limit(limit)\
              .all()
    return query

def anotar_coleccion(db: Session, id_coleccion: int, id_experto: int, validacion_update: schemas.ValidacionExpertoUpdate):
    # Buscar si ya existe una validación (ej. solicitada por el usuario)
    db_val = db.query(models.ValidacionExperto).filter(models.ValidacionExperto.id_coleccion == id_coleccion).first()
    
    if not db_val:
        # Si no existe, la creamos (anotación masiva sin petición previa)
        db_val = models.ValidacionExperto(
            id_coleccion=id_coleccion,
            id_experto=id_experto,
            solicitada_en=datetime.utcnow()
        )
        db.add(db_val)
        db.flush() # Para obtener el id_validacion

    db_val.id_experto = id_experto
    db_val.es_correcta = validacion_update.es_correcta
    db_val.feedback_experto = validacion_update.feedback_experto
    db_val.evaluacion_imagenes = validacion_update.evaluacion_imagenes
    db_val.variedad_sugerida = validacion_update.variedad_sugerida
    db_val.validada_en = datetime.utcnow()
    db_val.estado = "validada"
    
    coleccion = db.query(models.Coleccion).filter(models.Coleccion.id_coleccion == id_coleccion).first()
    
    # Actualizar la colección si hay variedad correcta
    if validacion_update.id_variedad_correcta and coleccion:
        coleccion.id_variedad = validacion_update.id_variedad_correcta
        db.add(coleccion)
    elif validacion_update.variedad_sugerida and coleccion:
        var_existente = db.query(models.Variedad).filter(models.Variedad.nombre.ilike(validacion_update.variedad_sugerida)).first()
        if var_existente:
            coleccion.id_variedad = var_existente.id_variedad
        else:
            nueva_var = models.Variedad(
                nombre=validacion_update.variedad_sugerida,
                descripcion="Variedad clasificada por un experto.",
                color="Desconocido"
            )
            db.add(nueva_var)
            db.flush()
            coleccion.id_variedad = nueva_var.id_variedad
        db.add(coleccion)
    
    # Insertar en AnotacionesImagenes
    if validacion_update.evaluacion_imagenes and coleccion:
        id_variedad_final = validacion_update.id_variedad_correcta if validacion_update.id_variedad_correcta else coleccion.id_variedad
        for eval_img in validacion_update.evaluacion_imagenes:
            url_img = eval_img.get("url")
            es_buena = eval_img.get("valida")
            
            if url_img and es_buena is not None:
                db_anotacion = models.AnotacionImagen(
                    url_imagen=url_img,
                    es_buena=es_buena,
                    id_validacion=db_val.id_validacion,
                    id_variedad=id_variedad_final
                )
                db.add(db_anotacion)

    db.commit()
    db.refresh(db_val)
    return db_val
