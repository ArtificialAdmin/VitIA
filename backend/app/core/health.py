from fastapi import APIRouter
from app.core.database import get_db

router = APIRouter()

@router.get("/ping")
def ping():
    # Simple check
    return {"status": "ok", "message": "VitIA Backend is running"}
