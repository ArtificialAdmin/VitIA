from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.core.health import router as health_router
from app.modules.biblioteca.router import router as variedad_router
from app.modules.biblioteca.ml_router import router as ml_router
from app.modules.coleccion.router import router as coleccion_router
from app.modules.auth.router import router as auth_router
from app.modules.usuarios.router import router as users_router
from app.modules.foro.router import router as foro_router

app = FastAPI(title="VitIA Backend Modular")

@app.get("/")
def read_root():
    return {"status": "online", "message": "VitIA API Modular"}

# --- CONFIGURACIÓN DE CORS ---
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*", "Authorization", "Content-Type", "access-control-allow-origin"],
)

# --- REGISTRO DE RUTAS ---
app.include_router(health_router, prefix="/health", tags=["Salud"])
app.include_router(auth_router) 
app.include_router(users_router)
app.include_router(variedad_router)
app.include_router(coleccion_router)
app.include_router(foro_router)
app.include_router(ml_router)