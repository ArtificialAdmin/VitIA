from sqlalchemy import Boolean, Column, Integer, String, DateTime, ForeignKey, Text, Float, Table, UniqueConstraint
from sqlalchemy.orm import relationship, backref
from sqlalchemy.sql import func
from sqlalchemy.dialects.postgresql import JSONB
from .database import Base

# --- TABLAS DE ASOCIACIÓN ---

publicacion_variedad_assoc = Table(
    'publicacion_variedad',
    Base.metadata,
    Column('id_publicacion', Integer, ForeignKey('Publicaciones.id_publicacion'), primary_key=True),
    Column('id_variedad', Integer, ForeignKey('Variedades.id_variedad'), primary_key=True)
)

favoritos_assoc = Table(
    'favoritos',
    Base.metadata,
    Column('id_usuario', Integer, ForeignKey('Usuarios.id_usuario'), primary_key=True),
    Column('id_variedad', Integer, ForeignKey('Variedades.id_variedad'), primary_key=True)
)

# --- MODELOS ---

class VotoPublicacion(Base):
    __tablename__ = "VotosPublicacion"
    id_voto = Column(Integer, primary_key=True, index=True)
    es_like = Column(Boolean, nullable=False)
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
    fecha_registro = Column(DateTime(timezone=True), server_default=func.now())

    publicaciones = relationship("Publicacion", back_populates="autor")
    coleccion = relationship("Coleccion", back_populates="propietario")
    favoritos = relationship("Variedad", secondary=favoritos_assoc, backref="favoritos_de_usuarios")

class Variedad(Base):
    __tablename__ = "Variedades"
    id_variedad = Column(Integer, primary_key=True, index=True)
    nombre = Column(String(150), nullable=False, index=True)
    descripcion = Column(Text, nullable=False)
    color = Column(String(50), nullable=True)
    links_imagenes = Column(JSONB) 
    info_extra = Column(JSONB)
    morfologia = Column(JSONB)

    items_coleccion = relationship("Coleccion", back_populates="variedad", cascade="all, delete-orphan")

class Coleccion(Base):
    __tablename__ = "Coleccion"
    id_coleccion = Column(Integer, primary_key=True, index=True)
    path_foto_usuario = Column(String(512), nullable=False)
    fecha_captura = Column(DateTime(timezone=True), server_default=func.now())
    notas = Column(Text, nullable=True)
    latitud = Column(Float, nullable=True)
    longitud = Column(Float, nullable=True)
    es_publica = Column(Boolean, default=True)
    es_premium = Column(Boolean, default=False) # <--- NUEVO: Indica si la captura fue en modo avanzado

    id_usuario = Column(Integer, ForeignKey("Usuarios.id_usuario"), nullable=False)
    id_variedad = Column(Integer, ForeignKey("Variedades.id_variedad"), nullable=False)
    # Soporte Premium
    fotos_premium = Column(JSONB, nullable=True) # Lista de URLs
    analisis_ia = Column(Text, nullable=True) # Descripción breve de la IA

    propietario = relationship("Usuario", back_populates="coleccion")
    variedad = relationship("Variedad", back_populates="items_coleccion")

class Publicacion(Base):
    __tablename__ = "Publicaciones"
    id_publicacion = Column(Integer, primary_key=True, index=True)
    titulo = Column(String(255), nullable=False)
    texto = Column(Text, nullable=False)
    links_fotos = Column(JSONB)
    fecha_publicacion = Column(DateTime(timezone=True), server_default=func.now())
    likes = Column(Integer, default=0)

    variedades = relationship("Variedad", secondary=publicacion_variedad_assoc, backref="publicaciones")
    id_usuario = Column(Integer, ForeignKey("Usuarios.id_usuario"), nullable=False)
    autor = relationship("Usuario", back_populates="publicaciones")
    comentarios = relationship("Comentario", back_populates="publicacion", cascade="all, delete-orphan")

class Comentario(Base):
    __tablename__ = "Comentarios"
    id_comentario = Column(Integer, primary_key=True, index=True)
    texto = Column(Text, nullable=False)
    fecha_comentario = Column(DateTime(timezone=True), server_default=func.now())
    likes = Column(Integer, default=0)
    borrado = Column(Boolean, default=False)
    id_usuario = Column(Integer, ForeignKey("Usuarios.id_usuario", ondelete="CASCADE"), nullable=False)
    id_publicacion = Column(Integer, ForeignKey("Publicaciones.id_publicacion", ondelete="CASCADE"), nullable=False)
    id_padre = Column(Integer, ForeignKey("Comentarios.id_comentario"), nullable=True)

    autor = relationship("Usuario")
    publicacion = relationship("Publicacion", back_populates="comentarios")
    hijos = relationship("Comentario", backref=backref('padre', remote_side=[id_comentario]))
