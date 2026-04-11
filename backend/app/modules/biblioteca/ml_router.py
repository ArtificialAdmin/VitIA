from fastapi import APIRouter, UploadFile, File, HTTPException
from app.ia.model_loader import model
import io
from PIL import Image
from typing import List

router = APIRouter(prefix="/ia", tags=["IA Inference"])

@router.post("/predict")
async def predict_image(file: UploadFile = File(...)):
    """Predicción de variedad de uva mediante IA."""
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

    averaged = [{ "variedad": cls, "confianza": round((sum(confs)/len(confs))*100, 2)}
                for cls, confs in class_confidences.items()]

    averaged.sort(key=lambda x: x["confianza"], reverse=True)

    return {"predicciones": averaged}
