from fastapi import APIRouter, UploadFile, File, HTTPException
from app.ia.model_loader import model
import io
from PIL import Image
from typing import List

from .schemas import PredictionResponse, PredictionResult
from typing import List

router = APIRouter(prefix="/ia", tags=["IA Inference"])

@router.post("/predict", response_model=PredictionResponse)
async def predict_image(file: UploadFile = File(...)):
    """Predicción de variedad de uva mediante IA (Modelo Base - 1 foto)."""
    if file.content_type.split("/")[0] != "image":
        raise HTTPException(status_code=400, detail="El archivo debe ser una imagen.")

    image_bytes = await file.read()
    try:
        image = Image.open(io.BytesIO(image_bytes)).convert("RGB")
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Imagen inválida: {e}")

    results = model.predict(image, save=False, verbose=False)

    class_confidences = {}
    for r in results:
        for box in r.boxes:
            cls_id = int(box.cls)
            conf = float(box.conf)
            cls_name = model.names[cls_id]
            class_confidences.setdefault(cls_name, []).append(conf)

    averaged = [PredictionResult(variedad=cls, confianza=round((sum(confs)/len(confs))*100, 2))
                for cls, confs in class_confidences.items()]

    averaged.sort(key=lambda x: x.confianza, reverse=True)

    return PredictionResponse(predicciones=averaged)

@router.post("/predict-premium", response_model=PredictionResponse)
async def predict_premium(files: List[UploadFile] = File(...)):
    """
    Predicción avanzada para usuarios Premium (Múltiples fotos).
    Combina los resultados de las capturas (Haz, Envés, Racimo, Uva) para una mayor precisión.
    """
    if not files:
        raise HTTPException(status_code=400, detail="Se requiere al menos una imagen.")

    total_confidences = {}

    for file in files:
        if file.content_type.split("/")[0] != "image":
            continue
        
        image_bytes = await file.read()
        try:
            image = Image.open(io.BytesIO(image_bytes)).convert("RGB")
            results = model.predict(image, save=False, verbose=False)
            
            for r in results:
                for box in r.boxes:
                    cls_id = int(box.cls)
                    conf = float(box.conf)
                    cls_name = model.names[cls_id]
                    total_confidences.setdefault(cls_name, []).append(conf)
        except:
            continue # Ignorar imágenes corruptas en este modo

    # Consolidamos los resultados de todas las imágenes
    # De momento simplemente promediamos todo lo detectado en las N fotos
    if not total_confidences:
        return PredictionResponse(predicciones=[])

    consolidated = [PredictionResult(variedad=cls, confianza=round((sum(confs)/len(confs))*100, 2))
                    for cls, confs in total_confidences.items()]

    consolidated.sort(key=lambda x: x.confianza, reverse=True)

    # Añadimos un análisis breve de ejemplo para el modo premium
    mock_analisis = (
        "Tras analizar las 4 capturas, se observa una hoja con senos laterales profundos y "
        "un envés con vellosidad media, características típicas de esta variedad. "
        "El racimo presenta una compacidad media y bayas de forma esferoide, lo que "
        "refuerza la identificación con una alta confianza."
    )

    return {
        "predicciones": consolidated,
        "analisis_premium": mock_analisis
    }
