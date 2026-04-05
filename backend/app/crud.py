# --- En tu archivo /app/crud.py ---

from sqlalchemy.orm import Session, joinedload
from . import models, schemas, security
from typing import List, Optional

# -----------------------------------------------------
# Funciones CRUD para Variedad (Biblioteca)
# -----------------------------------------------------

def get_variedad(db: Session, id_variedad: int):
    """Obtiene una variedad específica por su ID."""
    return db.query(models.Variedad).filter(models.Variedad.id_variedad == id_variedad).first()

def get_variedad_by_nombre(db: Session, nombre: str):
    """Obtiene una variedad específica por su nombre (para evitar duplicados)."""
    return db.query(models.Variedad).filter(models.Variedad.nombre == nombre).first()

def get_variedades(db: Session, skip: int = 0, limit: int = 100):
    """Obtiene una lista paginada de todas las variedades."""
    return db.query(models.Variedad).offset(skip).limit(limit).all()

def create_variedad(db: Session, variedad: schemas.VariedadCreate):
    """Crea una nueva variedad en la base de datos."""
    db_variedad = models.Variedad(**variedad.model_dump())
    db.add(db_variedad)
    db.commit()
    db.refresh(db_variedad)
    return db_variedad

def update_variedad(db: Session, db_variedad: models.Variedad, variedad_update: schemas.VariedadUpdate):
    """
    Actualiza una variedad existente.
    Usa model_dump(exclude_unset=True) para solo actualizar los campos
    que se enviaron en la petición (clave para PATCH).
    """
    update_data = variedad_update.model_dump(exclude_unset=True)
    
    for key, value in update_data.items():
        setattr(db_variedad, key, value)
    
    db.add(db_variedad) # Opcional si ya está en la sesión
    db.commit()
    db.refresh(db_variedad)
    return db_variedad

def delete_variedad(db: Session, id_variedad: int):
    """Elimina una variedad de la base de datos."""
    db_variedad = db.query(models.Variedad).filter(models.Variedad.id_variedad == id_variedad).first()
    if db_variedad:
        db.delete(db_variedad)
        db.commit()
    return db_variedad

def create_variedad_automatica(db: Session, nombre: str):
    """Crea una variedad nueva con datos por defecto"""
    nueva_variedad = models.Variedad(
        nombre=nombre,
        descripcion=f"Variedad identificada automáticamente por VitIA: {nombre}",
        # Añade otros campos obligatorios si tu modelo los requiere
    )
    db.add(nueva_variedad)
    db.commit()
    db.refresh(nueva_variedad)
    return nueva_variedad

# -----------------------------------------------------
# Funciones CRUD para Coleccion (Personal)
# -----------------------------------------------------

def create_coleccion_item(db: Session, item: schemas.ColeccionCreate, id_usuario: int):
    """Crea un nuevo item en la colección de un usuario."""
    # **item.model_dump() coge 'path_foto_usuario' y 'id_variedad' del schema
    db_item = models.Coleccion(
        **item.model_dump(),
        id_usuario=id_usuario  # Añadimos el ID del usuario autenticado
    )
    db.add(db_item)
    db.commit()
    db.refresh(db_item)
    return db_item

def get_user_coleccion(db: Session, id_usuario: int, skip: int = 0, limit: int = 100):
    """Obtiene una lista paginada de la colección de un usuario."""
    return db.query(models.Coleccion)\
             .filter(models.Coleccion.id_usuario == id_usuario)\
             .offset(skip)\
             .limit(limit)\
             .all()

def get_coleccion_item(db: Session, id_coleccion: int, id_usuario: int):
    """
    Obtiene un item específico de la colección,
    asegurándose de que pertenece al usuario.
    """
    return db.query(models.Coleccion).filter(
        models.Coleccion.id_coleccion == id_coleccion,
        models.Coleccion.id_usuario == id_usuario
    ).first()

def delete_coleccion_item(db: Session, id_coleccion: int, id_usuario: int):
    """
    Elimina un item de la colección,
    asegurándose de que pertenece al usuario.
    """
    db_item = get_coleccion_item(db, id_coleccion, id_usuario)
    
    if db_item:
        db.delete(db_item)
        db.commit()
    return db_item

def update_coleccion_item(
    db: Session, 
    db_item: models.Coleccion, 
    item_update: schemas.ColeccionUpdate
):
    """
    Actualiza un item de la colección.
    Usa model_dump(exclude_unset=True) para actualizar solo los campos enviados.
    """
    update_data = item_update.model_dump(exclude_unset=True)
    
    for key, value in update_data.items():
        setattr(db_item, key, value)
    
    db.add(db_item)
    db.commit()
    db.refresh(db_item)
    return db_item

# -----------------------------------------------------
# Funciones CRUD para Usuario (NUEVAS)
# -----------------------------------------------------

def get_user(db: Session, id_usuario: int):
    """Obtiene un usuario por su ID."""
    return db.query(models.Usuario).filter(models.Usuario.id_usuario == id_usuario).first()

def get_user_by_email(db: Session, email: str):
    """Obtiene un usuario por su email."""
    return db.query(models.Usuario).filter(models.Usuario.email == email).first()

def create_user(db: Session, user: schemas.UsuarioCreate, url_foto: str = None):
    fake_hashed_password = security.get_password_hash(user.password)
    
    db_user = models.Usuario(
        nombre=user.nombre,
        apellidos=user.apellidos,
        email=user.email,
        password_hash=fake_hashed_password,
        latitud=user.latitud,
        longitud=user.longitud,
        path_foto_perfil=url_foto,
        tutorial_superado=False # Valor por defecto seguro
    )
    db.add(db_user)
    db.commit()
    db.refresh(db_user)
    return db_user

def update_user(db: Session, db_user: models.Usuario, user_update: schemas.UsuarioUpdate):
    """
    Actualiza un usuario.
    Usa model_dump(exclude_unset=True) para actualizar solo los campos enviados.
    """
    update_data = user_update.model_dump(exclude_unset=True)
    
    for key, value in update_data.items():
        setattr(db_user, key, value)
    
    db.add(db_user)
    db.commit()
    db.refresh(db_user)
    return db_user


def delete_user(db: Session, id_usuario: int):
    """
    Elimina un usuario de la base de datos.
    """
    db_user = get_user(db, id_usuario=id_usuario)
    if db_user:
        db.delete(db_user)
        db.commit()
    return db_user

# -----------------------------------------------------
# Funciones CRUD para Publicaciones (Foro)
# -----------------------------------------------------

def create_publicacion(db: Session, publicacion: schemas.PublicacionCreate, id_usuario: int):
    # 1. Creamos la publicación base
    db_publicacion = models.Publicacion(
        titulo=publicacion.titulo,
        texto=publicacion.texto,
        links_fotos=publicacion.links_fotos,
        id_usuario=id_usuario
        # 'likes' empieza en 0 por defecto
    )
    
    # 2. Gestionamos las variedades (Categorías)
    if publicacion.variedades_ids:
        # Buscamos en la BD todas las variedades que coincidan con los IDs enviados
        variedades_db = db.query(models.Variedad).filter(
            models.Variedad.id_variedad.in_(publicacion.variedades_ids)
        ).all()
        
        # Se las asignamos a la publicación (SQLAlchemy rellena la tabla de asociación solo)
        db_publicacion.variedades = variedades_db

    db.add(db_publicacion)
    db.commit()
    db.refresh(db_publicacion)
    return db_publicacion

def get_publicacion(db: Session, id_publicacion: int):
    """Obtiene una publicación por su ID."""
    return db.query(models.Publicacion).filter(models.Publicacion.id_publicacion == id_publicacion).first()

def delete_publicacion(db: Session, db_publicacion: models.Publicacion):
    """Elimina una publicación de la base de datos."""
    db.delete(db_publicacion)
    db.commit()
    return db_publicacion

def get_publicaciones(db: Session, skip: int = 0, limit: int = 100):
    """Obtiene una lista paginada de todas las publicaciones del foro."""
    return db.query(models.Publicacion)\
             .options(joinedload(models.Publicacion.autor))\
             .order_by(models.Publicacion.fecha_publicacion.desc())\
             .offset(skip)\
             .limit(limit)\
             .all()

def get_colecciones_mapa(db: Session, modo: str = "publico", id_usuario: int = None):
    """Obtiene todos los items de la coleccion que tienen coordenadas geográficas para mostrarlas en el mapa."""
    query = db.query(models.Coleccion)\
              .options(joinedload(models.Coleccion.propietario))\
              .filter(models.Coleccion.latitud.isnot(None), models.Coleccion.longitud.isnot(None))
    
    if modo == "privado" and id_usuario:
        query = query.filter(models.Coleccion.id_usuario == id_usuario)
    else:
        query = query.filter(models.Coleccion.es_publica == True)
        
    return query.order_by(models.Coleccion.fecha_captura.desc()).all()

def like_publicacion(db: Session, id_publicacion: int):
    """Incrementa en 1 los likes de una publicación."""
    db_publicacion = get_publicacion(db, id_publicacion)
    if db_publicacion:
        db_publicacion.likes += 1
        db.commit()
        db.refresh(db_publicacion)
    return db_publicacion

def unlike_publicacion(db: Session, id_publicacion: int):
    """Decrementa en 1 los likes de una publicación (mínimo 0)."""
    db_publicacion = get_publicacion(db, id_publicacion)
    if db_publicacion and db_publicacion.likes > 0:
        db_publicacion.likes -= 1
        db.commit()
        db.refresh(db_publicacion)
    return db_publicacion

def get_user_publicaciones(db: Session, id_usuario: int, skip: int = 0, limit: int = 100):
    """Obtiene una lista paginada de las publicaciones de un usuario específico."""
    return db.query(models.Publicacion)\
             .options(joinedload(models.Publicacion.autor))\
             .filter(models.Publicacion.id_usuario == id_usuario)\
             .order_by(models.Publicacion.fecha_publicacion.desc())\
             .offset(skip)\
             .limit(limit)\
             .all()

# --- CRUD PARA COMENTARIOS ---

def create_comentario(db: Session, comentario: schemas.ComentarioCreate, id_usuario: int):
    db_comentario = models.Comentario(
        texto=comentario.texto,
        id_publicacion=comentario.id_publicacion,
        id_padre=comentario.id_padre, # Puede ser None o un ID
        id_usuario=id_usuario
    )
    db.add(db_comentario)
    db.commit()
    db.refresh(db_comentario)
    return db_comentario

def get_comentarios_publicacion(db: Session, id_publicacion: int, skip: int = 0, limit: int = 100):
    """
    Obtiene solo los comentarios PRINCIPALES (donde id_padre es NULL).
    Gracias a la relación 'hijos' en el modelo y schema, SQLAlchemy y Pydantic
    cargarán las respuestas anidadas automáticamente.
    """
    return db.query(models.Comentario)\
             .filter(models.Comentario.id_publicacion == id_publicacion)\
             .filter(models.Comentario.id_padre == None)\
             .order_by(models.Comentario.fecha_comentario.asc())\
             .offset(skip)\
             .limit(limit)\
             .all()

def delete_comentario(db: Session, id_comentario: int, id_usuario: int):
    """Elimina un comentario si pertenece al usuario."""
    db_comentario = db.query(models.Comentario).filter(
        models.Comentario.id_comentario == id_comentario,
        models.Comentario.id_usuario == id_usuario
    ).first()
    
    if db_comentario:
        db.delete(db_comentario)
        db.commit()
    return db_comentario

# --- CRUD PARA COMPROBAR SI UN USUARIO TIENE REGISTRADA UNA VARIEDAD ---

def check_variedad_in_coleccion(db: Session, id_usuario: int, id_variedad: int) -> bool:
    """Devuelve True si el usuario tiene esta variedad en su colección."""
    item = db.query(models.Coleccion).filter(
        models.Coleccion.id_usuario == id_usuario,
        models.Coleccion.id_variedad == id_variedad
    ).first()
    return item is not None

# --- LOGICA FAVORITOS ---
def toggle_favorito(db: Session, id_usuario: int, id_variedad: int):
    user = get_user(db, id_usuario)
    variedad = db.query(models.Variedad).get(id_variedad)
    if not variedad: return None
        
    if variedad in user.favoritos:
        user.favoritos.remove(variedad)
        db.commit()
        return "eliminado de"
    else:
        user.favoritos.append(variedad)
        db.commit()
        return "añadido a" # Pequeña corrección en el return string

def get_user_favoritos(db: Session, id_usuario: int, skip: int = 0, limit: int = 100):
    """Obtiene una lista paginada de las variedades favoritas de un usuario."""
    user = get_user(db, id_usuario)
    if not user:
        return []

    return db.query(models.Variedad)\
             .join(models.favoritos_assoc)\
             .filter(models.favoritos_assoc.c.id_usuario == id_usuario)\
             .offset(skip)\
             .limit(limit)\
             .all()

def _actualizar_contador_likes(db: Session, modelo_voto, modelo_padre, id_campo_fk, id_valor_fk, columna_likes_padre):
    """
    Función interna: Cuenta cuántos 'True' hay en la tabla de votos
    y actualiza la columna 'likes' del objeto padre (Publicacion o Comentario).
    """
    # 1. Contar likes reales (es_like = True)
    filtro = {id_campo_fk: id_valor_fk, "es_like": True}
    total_likes = db.query(modelo_voto).filter_by(**filtro).count()
    
    # Si quisieras restar los dislikes (Score), descomenta esto:
    # total_dislikes = db.query(modelo_voto).filter_by({id_campo_fk: id_valor_fk, "es_like": False}).count()
    # score_final = total_likes - total_dislikes
    
    # 2. Actualizar el padre
    # Usamos db.query().update() para ser eficientes
    db.query(modelo_padre).filter(
        getattr(modelo_padre, id_campo_fk) == id_valor_fk
    ).update({columna_likes_padre: total_likes})
    
    db.commit()

# --- LOGICA VOTOS (3 ESTADOS) ---
def gestionar_voto(db: Session, modelo_voto, modelo_padre, id_usuario: int, id_campo_fk, id_valor_fk, es_like: Optional[bool]):
    """
    1. Gestiona el voto (Crear, Borrar o Actualizar).
    2. Recalcula el contador del padre.
    """
    filtro = {
        "id_usuario": id_usuario,
        id_campo_fk: id_valor_fk
    }
    
    # 1. Buscar voto existente
    voto_existente = db.query(modelo_voto).filter_by(**filtro).first()
    estado = ""

    # CASO A: Quitar voto (Neutro)
    if es_like is None:
        if voto_existente:
            db.delete(voto_existente)
            estado = "voto_eliminado"
        else:
            estado = "sin_cambios"

    # CASO B: Dar Like o Dislike
    elif voto_existente:
        # Actualizar si cambia
        if voto_existente.es_like != es_like:
            voto_existente.es_like = es_like
            estado = "voto_actualizado"
        else:
            estado = "sin_cambios"
    else:
        # Crear nuevo
        nuevo_voto = modelo_voto(es_like=es_like, **filtro)
        db.add(nuevo_voto)
        estado = "voto_creado"
    
    db.commit()

    # 2. IMPORTANTE: Sincronizar el contador en la tabla padre
    # Solo recalculamos si hubo cambios para ahorrar recursos
    if estado != "sin_cambios":
        _actualizar_contador_likes(
            db, 
            modelo_voto=modelo_voto, 
            modelo_padre=modelo_padre, 
            id_campo_fk=id_campo_fk, 
            id_valor_fk=id_valor_fk, 
            columna_likes_padre="likes" # Nombre de la columna en Publicacion/Comentario
        )
    
    return estado

# Wrappers
def votar_publicacion(db: Session, id_usuario: int, id_publicacion: int, es_like: Optional[bool]):
    return gestionar_voto(
        db=db,
        modelo_voto=models.VotoPublicacion,
        modelo_padre=models.Publicacion, # <-- Pasamos el modelo padre
        id_usuario=id_usuario,
        id_campo_fk="id_publicacion",
        id_valor_fk=id_publicacion,
        es_like=es_like
    )

def votar_comentario(db: Session, id_usuario: int, id_comentario: int, es_like: Optional[bool]):
    return gestionar_voto(
        db=db,
        modelo_voto=models.VotoComentario,
        modelo_padre=models.Comentario, # <-- Pasamos el modelo padre
        id_usuario=id_usuario,
        id_campo_fk="id_comentario",
        id_valor_fk=id_comentario,
        es_like=es_like
    )