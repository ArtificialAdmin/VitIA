from sqlalchemy import create_engine
from sqlalchemy.orm import declarative_base, sessionmaker
from .config import settings

# 1. URL de conexión completa (leída desde .env gracias a settings)
SQLALCHEMY_DATABASE_URL = settings.DATABASE_URL

# 2. El motor de SQLAlchemy
engine = create_engine(
    SQLALCHEMY_DATABASE_URL,
    pool_pre_ping=True,
    pool_recycle=300,
    pool_size=10,
    max_overflow=20
)

# 3. El creador de sesiones
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# 4. La 'Base' para los modelos
Base = declarative_base()

# 5. Dependencia para los routers
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
