from fastapi import APIRouter, UploadFile, File, HTTPException
from app.ia.model_loader import model, premium_model
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
    Combina los resultados de las capturas usando el nuevo motor OIV.
    """
    if not files:
        raise HTTPException(status_code=400, detail="Se requiere al menos una imagen.")

    from app.modules.biblioteca.oiv_engine import analizar_imagenes_camara, comparar_variedades
    import numpy as np
    import cv2

    lista_imagenes_cv2 = []

    for file in files:
        if file.content_type.split("/")[0] != "image":
            continue
        
        image_bytes = await file.read()
        try:
            # Convert to numpy array for cv2
            img_array = np.frombuffer(image_bytes, np.uint8)
            img_cv2 = cv2.imdecode(img_array, cv2.IMREAD_COLOR)
            if img_cv2 is not None:
                lista_imagenes_cv2.append(img_cv2)
        except Exception as e:
            print(f"Error procesando imagen: {e}")
            continue

    if not lista_imagenes_cv2:
        return PredictionResponse(predicciones=[])

    # Llamar al nuevo motor usando el modelo premium
    resultados_ia = analizar_imagenes_camara(lista_imagenes_cv2, premium_model)
    
    # Comparar con la base de datos local JSON
    comparacion = comparar_variedades(resultados_ia)
    
    if isinstance(comparacion, dict) and "error" in comparacion:
        raise HTTPException(status_code=500, detail=comparacion["error"])

    # Convertir el resultado a la estructura PredictionResult
    consolidated = []
    for c in comparacion:
        # Solo devolver las que tengan algo de similitud, o podemos devolver top 5
        consolidated.append(
            PredictionResult(
                variedad=c["nombre"], 
                confianza=c["similitud"]
            )
        )
        
    # Limitar a las top 5 para no saturar la UI
    consolidated = consolidated[:5]

    hojas_dict = resultados_ia.get('hojas') or {}
    racimos_dict = resultados_ia.get('racimos') or {}
    bayas_dict = resultados_ia.get('bayas') or {}

    # --- Generación de Reporte Premium Detallado ---
    detalles = []
    
    if hojas_dict and hojas_dict.get('muestras_detectadas', 0) > 0:
        # Ejemplo: "oiv_067" es la forma de la hoja
        desc_h = hojas_dict.get('oiv_067', {}).get('descripcion', 'detectada')
        detalles.append(f"Hojas con morfología {desc_h.lower()}")
    
    if racimos_dict and racimos_dict.get('muestras_detectadas', 0) > 0:
        # Ejemplo: "oiv_204" es la compacidad
        desc_r = racimos_dict.get('oiv_204', {}).get('descripcion', 'detectada')
        detalles.append(f"Racimos de compacidad {desc_r.lower()}")
        
    if bayas_dict and bayas_dict.get('muestras_detectadas', 0) > 0:
        # Ejemplo: "oiv_225" es el color
        desc_b = bayas_dict.get('oiv_225', {}).get('descripcion', 'detectado')
        # Ejemplo: "oiv_223" es la forma de la baya
        desc_f = bayas_dict.get('oiv_223', {}).get('descripcion', 'detectada')
        detalles.append(f"Bayas {desc_b.lower()} de forma {desc_f.lower()}")

    if detalles:
        analisis_texto = "Análisis morfológico avanzado: " + ", ".join(detalles) + ". "
        analisis_texto += f"Se han evaluado {resultados_ia.get('hojas', {}).get('muestras_detectadas', 0)} hojas, {resultados_ia.get('racimos', {}).get('muestras_detectadas', 0)} racimos y {resultados_ia.get('bayas', {}).get('muestras_detectadas', 0)} bayas."
    else:
        analisis_texto = "El análisis multiespectral no ha podido extraer suficientes descriptores morfológicos claros. Se recomienda repetir las capturas con mejor iluminación."

    return {
        "predicciones": consolidated,
        "analisis_premium": analisis_texto
    }
