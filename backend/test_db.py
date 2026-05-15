from app.core.database import SessionLocal
from app.core.models import Coleccion

db = SessionLocal()
item = db.query(Coleccion).order_by(Coleccion.id_coleccion.desc()).first()
print("ID:", item.id_coleccion)
print("es_premium:", item.es_premium)
print("solicita_validacion:", item.solicita_validacion_experto)
print("fotos_premium:", item.fotos_premium)
