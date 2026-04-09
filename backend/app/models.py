# --- En tu archivo /app/models.py ---

from sqlalchemy import Boolean, Column, Integer, String, DateTime, ForeignKey, Text, Float, Table, UniqueConstraint
from sqlalchemy.orm import relationship, backref
from sqlalchemy.sql import func
from sqlalchemy.dialects.postgresql import JSONB  # Específico para PostgreSQL

# Importas la 'Base' que creaste en tu archivo database.py
# (El archivo que tiene el 'engine' y 'SessionLocal')
from .database import Base  

# 1. TABLA DE ASOCIACIÓN (NUEVA)
# Esta tabla "invisible" conecta Publicaciones con Variedades (Muchos a Muchos)
publicacion_variedad_assoc = Table(
    'publicacion_variedad',
    Base.metadata,
    Column('id_publicacion', Integer, ForeignKey('Publicaciones.id_publicacion'), primary_key=True),
    Column('id_variedad', Integer, ForeignKey('Variedades.id_variedad'), primary_key=True)
)
# 1. TABLA ASOCIACIÓN: FAVORITOS
favoritos_assoc = Table(
    'favoritos',
    Base.metadata,
    Column('id_usuario', Integer, ForeignKey('Usuarios.id_usuario'), primary_key=True),
    Column('id_variedad', Integer, ForeignKey('Variedades.id_variedad'), primary_key=True)
)

# 2. TABLAS DE VOTOS
# La lógica es: Si existe fila, hay voto. Si no existe fila, es "Nada".
class VotoPublicacion(Base):
    __tablename__ = "VotosPublicacion"
    
    id_voto = Column(Integer, primary_key=True, index=True)
    es_like = Column(Boolean, nullable=False) # True=Like, False=Dislike
    
    id_usuario = Column(Integer, ForeignKey("Usuarios.id_usuario", ondelete="CASCADE"), nullable=False)
    id_publicacion = Column(Integer, ForeignKey("Publicaciones.id_publicacion", ondelete="CASCADE"), nullable=False)

    __table_args__ = (UniqueConstraint('id_usuario', 'id_publicacion', name='unique_voto_pub'),)

class VotoComentario(Base):
    __tablename__ = "VotosComentario"
    
    id_voto = Column(Integer, primary_key=True, index=True)
    es_like = Column(Boolean, nullable=False)
    
    id_usuario = Column(Integer, ForeignKey("Usuarios.id_usuario", ondelete="CASCADE"), nullable=False)
    id_comentario = Column(Integer, ForeignKey("Comentarios.id_comentario", ondelete="CASCADE"), nullable=False)

    __table_args__ = (UniqueConstraint('id_usuario', 'id_comentario', name='unique_voto_com'),)


# -----------------------------------------------------
# Modelo: Usuarios
# -----------------------------------------------------
class Usuario(Base):
    __tablename__ = "Usuarios"

    id_usuario = Column(Integer, primary_key=True, index=True)
    nombre = Column(String(100), nullable=False)
    apellidos = Column(String(150), nullable=False)
    email = Column(String(255), unique=True, index=True, nullable=False)
    password_hash = Column(String(255), nullable=False)
    es_premium = Column(Boolean, default=False)
    latitud = Column(Float, nullable=True)
    longitud = Column(Float, nullable=True)
    tutorial_superado = Column(Boolean, default=False)
    path_foto_perfil = Column(String(512), nullable=True)
    
    # Usamos timezone=True para guardar con zona horaria (TIMESTAMPTZ)
    fecha_registro = Column(DateTime(timezone=True), server_default=func.now())

    # --- Relaciones ---
    # 'relationship' es la magia de SQLAlchemy.
    # Le dice a SQLAlchemy cómo conectar este modelo con otros.
    
    # Un Usuario puede tener muchas Publicaciones.
    # 'back_populates' le dice a la clase 'Publicacion' qué variable nos representa.
    publicaciones = relationship("Publicacion", back_populates="autor")
    
    # Un Usuario puede tener muchos items en su Coleccion.
    coleccion = relationship("Coleccion", back_populates="propietario")

    favoritos = relationship("Variedad", secondary=favoritos_assoc, backref="favoritos_de_usuarios")


# -----------------------------------------------------
# Modelo: Variedades (La "Biblioteca")
# -----------------------------------------------------
class Variedad(Base):
    __tablename__ = "Variedades"

    id_variedad = Column(Integer, primary_key=True, index=True)
    nombre = Column(String(150), nullable=False, index=True) # index=True para búsquedas rápidas
    descripcion = Column(Text, nullable=False)
    color = Column(String(50), nullable=True)
    
    # Usamos JSONB para guardar una lista de URLs o datos estructurados
    links_imagenes = Column(JSONB) 
    info_extra = Column(JSONB)
    morfologia = Column(JSONB)

    # --- Relaciones ---
    # Esta Variedad puede estar en la Coleccion de muchos usuarios
    items_coleccion = relationship("Coleccion", back_populates="variedad", cascade="all, delete-orphan")


# -----------------------------------------------------
# Modelo: Coleccion (La "Colección" personal)
# -----------------------------------------------------
class Coleccion(Base):
    __tablename__ = "Coleccion"

    id_coleccion = Column(Integer, primary_key=True, index=True)
    path_foto_usuario = Column(String(512), nullable=False) # Ruta a S3, Firebase, etc.
    fecha_captura = Column(DateTime(timezone=True), server_default=func.now())
    notas = Column(Text, nullable=True)
    latitud = Column(Float, nullable=True)
    longitud = Column(Float, nullable=True)
    es_publica = Column(Boolean, default=True)

    # --- Claves Foráneas ---
    # Aquí definimos las columnas que 'conectan' las tablas
    id_usuario = Column(Integer, ForeignKey("Usuarios.id_usuario"), nullable=False)
    id_variedad = Column(Integer, ForeignKey("Variedades.id_variedad"), nullable=False)

    # --- Relaciones ---
    # Define el "otro lado" de las relaciones de Usuario y Variedad
    propietario = relationship("Usuario", back_populates="coleccion")
    variedad = relationship("Variedad", back_populates="items_coleccion")


# -----------------------------------------------------
# Modelo: Publicaciones (El Foro)
# -----------------------------------------------------
class Publicacion(Base):
    __tablename__ = "Publicaciones"

    id_publicacion = Column(Integer, primary_key=True, index=True)
    titulo = Column(String(255), nullable=False)
    texto = Column(Text, nullable=False)
    links_fotos = Column(JSONB) # Lista de fotos para el post
    fecha_publicacion = Column(DateTime(timezone=True), server_default=func.now())
    likes = Column(Integer, default=0)

    # Relación Many-to-Many: Una publicación puede tener muchas variedades etiquetadas
    variedades = relationship(
        "Variedad",
        secondary=publicacion_variedad_assoc,
        backref="publicaciones"
    )

    # --- Clave Foránea ---
    id_usuario = Column(Integer, ForeignKey("Usuarios.id_usuario"), nullable=False)
    
    # --- Relaciones ---
    autor = relationship("Usuario", back_populates="publicaciones")
    comentarios = relationship("Comentario", back_populates="publicacion", cascade="all, delete-orphan")

class Comentario(Base):
    __tablename__ = "Comentarios"

    id_comentario = Column(Integer, primary_key=True, index=True)
    texto = Column(Text, nullable=False)
    fecha_comentario = Column(DateTime(timezone=True), server_default=func.now())
    likes = Column(Integer, default=0)
    borrado = Column(Boolean, default=False)

    # Claves foráneas
    id_usuario = Column(Integer, ForeignKey("Usuarios.id_usuario", ondelete="CASCADE"), nullable=False)
    id_publicacion = Column(Integer, ForeignKey("Publicaciones.id_publicacion", ondelete="CASCADE"), nullable=False)
    
    # RELACIÓN RECURSIVA (Self-Referential): Un comentario puede tener un "padre"
    id_padre = Column(Integer, ForeignKey("Comentarios.id_comentario"), nullable=True)

    # Relaciones
    autor = relationship("Usuario")
    publicacion = relationship("Publicacion", back_populates="comentarios")
    
    # Esto permite acceder a los hijos: comentario.hijos (lista de respuestas)
    # y al padre: comentario.padre (el comentario al que respondes)
    hijos = relationship("Comentario", 
                        backref=backref('padre', remote_side=[id_comentario]))