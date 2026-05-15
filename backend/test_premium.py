import requests
import sys

url = "http://localhost:8000/coleccion/"
files = [
    ("file", ("cover.jpg", b"dummy content", "image/jpeg")),
]

data = {
    "nombre_variedad": "Tempranillo",
    "es_publica": "true",
    "solicita_validacion": "true",
    "analisis_ia": "Análisis premium super detallado."
}

# we need an auth token, but we are just testing if it saves. Wait, we removed the bypass.
# So I need to log in to get a token!
