import os
from pathlib import Path
from dotenv import load_dotenv
from pydantic_settings import BaseSettings, SettingsConfigDict

# Si el archivo está en backend/app/core/config.py, subimos 3 niveles para llegar a backend/
BASE_DIR = Path(__file__).resolve().parent.parent.parent  

load_dotenv(BASE_DIR / ".env")

class Settings(BaseSettings):
    DATABASE_URL: str
    SECRET_KEY: str
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30

    IMAGEKIT_PRIVATE_KEY: str
    IMAGEKIT_PUBLIC_KEY: str
    IMAGEKIT_URL_ENDPOINT: str

    model_config = SettingsConfigDict(
        env_file=str(BASE_DIR / ".env"),
        env_file_encoding="utf-8",
        extra="ignore"
    )

settings = Settings()

print("[DEBUG] DATABASE_URL:", settings.DATABASE_URL)
# print("[DEBUG] SECRET_KEY:", settings.SECRET_KEY[:6] + "...")
