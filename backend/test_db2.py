from app.core.database import SessionLocal
from app.core.models import Coleccion

db = SessionLocal()
items = db.query(Coleccion).order_by(Coleccion.id_coleccion.desc()).limit(5).all()
for item in items:
    print(f"ID: {item.id_coleccion}, es_premium: {item.es_premium}, date: {item.fecha_captura}")
