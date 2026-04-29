import cv2
import numpy as np
import json
import os

# ==========================================
# FUNCIONES TRADUCTORAS OIV (Sin cambios)
# ==========================================
def calcular_oiv_065(area_media_pixeles):
    if area_media_pixeles == 0: return "N/A"
    if area_media_pixeles < 800000: return 1
    elif 800000 <= area_media_pixeles < 1200000: return 3
    elif 1200000 <= area_media_pixeles < 1800000: return 5
    elif 1800000 <= area_media_pixeles < 2500000: return 7
    else: return 9

def calcular_oiv_067(forma_media, solidez_media):
    if forma_media == 0: return "N/A", "Desconocida"
    if forma_media < 0.85: return 2, "Cuneiforme"
    elif forma_media > 1.15: return 5, "Reniforme"
    else:
        if solidez_media > 0.90: return 4, "Orbicular"
        elif solidez_media < 0.80: return 3, "Pentagonal"
        else: return 1, "Cordiforme"

def calcular_oiv_068(num_senos_profundos):
    if num_senos_profundos <= 1: return 1, "1 Lóbulo (Entera)"
    elif num_senos_profundos in [2, 3]: return 2, "3 Lóbulos"
    elif num_senos_profundos in [4, 5]: return 3, "5 Lóbulos"
    elif num_senos_profundos in [6, 7]: return 4, "7 Lóbulos"
    else: return 5, "Más de 7 Lóbulos"

def calcular_oiv_202(longitud_media_pixeles):
    if longitud_media_pixeles == 0: return "N/A"
    if longitud_media_pixeles < 800: return 1
    elif 800 <= longitud_media_pixeles < 1500: return 3
    elif 1500 <= longitud_media_pixeles < 2500: return 5
    elif 2500 <= longitud_media_pixeles < 3500: return 7
    else: return 9

def calcular_oiv_204(compacidad_media):
    if compacidad_media == 0: return "N/A", "Desconocida"
    if compacidad_media < 0.50: return 1, "Muy suelto"
    elif 0.50 <= compacidad_media < 0.60: return 3, "Suelto"
    elif 0.60 <= compacidad_media < 0.70: return 5, "Medio"
    elif 0.70 <= compacidad_media < 0.80: return 7, "Denso"
    else: return 9, "Muy denso"

def calcular_oiv_208(forma_media):
    if forma_media == 0: return "N/A", "Desconocida"
    if forma_media < 0.45: return 1, "Cilíndrica"
    elif 0.45 <= forma_media < 0.70: return 2, "Cónica"
    else: return 3, "Forma de embudo"

def calcular_oiv_220(longitud_media_pixeles):
    if longitud_media_pixeles == 0: return "N/A"
    if longitud_media_pixeles < 200: return 1
    elif 200 <= longitud_media_pixeles < 300: return 3
    elif 300 <= longitud_media_pixeles < 400: return 5
    elif 400 <= longitud_media_pixeles < 500: return 7
    else: return 9

def calcular_oiv_223_avanzado(ratio_forma, desplazamiento_y, solidez):
    if ratio_forma == 0: return "N/A", "Desconocida"
    if solidez < 0.85: return 9, "Forma de cuerno / Irregular"
    if desplazamiento_y > 0.04: return 7, "Ovoide (Gorda por abajo)"
    elif desplazamiento_y < -0.04: return 8, "Ovoide inversa (Gorda por arriba)"
    if ratio_forma < 1.05: return 2, "Esférica"
    elif 1.05 <= ratio_forma < 1.15: return 3, "Elíptica corta"
    elif 1.15 <= ratio_forma < 1.35: return 4, "Elíptica larga"
    else: return 5, "Cilíndrica / Muy alargada"

def calcular_oiv_225(r, g, b):
    if r == 0 and g == 0 and b == 0: return "N/A", "Desconocido"
    luminosidad = r + g + b
    if b > g and b > r:
        if luminosidad < 380: return 6, "Azul negro"
        else: return 5, "Rojo violeta oscuro"
    elif g > (b + 15) and r > (b + 15): return 1, "Verde amarillento"
    elif r > (g + 15) and r > (b + 15):
        if luminosidad > 400: return 2, "Rosa"
        else: return 3, "Rojo"
    else: 
        if b >= g and b >= r: return 6, "Azul negro (Con mucha pruina)"
        return 4, "Gris"


# ==========================================
# NUEVO MOTOR PARA APP (Devuelve JSON/Dict)
# ==========================================

def analizar_imagenes_camara(lista_imagenes, modelo):
    """
    Recibe una lista de imágenes (numpy arrays) y el modelo YOLO cargado.
    Devuelve un diccionario estructurado con los resultados OIV.
    """
    datos_hojas = {'area': [], 'forma': [], 'solidez': []}
    datos_racimos = {'longitud': [], 'compacidad': [], 'forma': []}
    datos_bayas = {'longitud': [], 'forma_real': [], 'desplazamiento_y': [], 'solidez': [], 'color_r': [], 'color_g': [], 'color_b': []}

    # Bucle principal: Analizar foto a foto desde la memoria
    for imagen in lista_imagenes:
        if imagen is None: continue

        resultados = modelo(imagen, verbose=False)

        for resultado in resultados:
            if resultado.masks is not None:
                for mascara_puntos, clase_id in zip(resultado.masks.xy, resultado.boxes.cls):
                    clase_id = int(clase_id)
                    contorno = np.array(mascara_puntos, dtype=np.int32)
                    area = cv2.contourArea(contorno)
                    
                    if area < 500: continue 

                    x, y, w, h = cv2.boundingRect(contorno)

                    # --- HOJAS (0) ---
                    if clase_id == 0:
                        datos_hojas['area'].append(area)
                        datos_hojas['forma'].append(w / float(h) if h > 0 else 0)
                        
                        perimetro = cv2.arcLength(contorno, True)
                        epsilon = 0.002 * perimetro 
                        contorno_suavizado = cv2.approxPolyDP(contorno, epsilon, True)
                        
                        try:
                            hull_indices = cv2.convexHull(contorno_suavizado, returnPoints=False)
                            if hull_indices is not None and len(hull_indices) > 3: 
                                defectos = cv2.convexityDefects(contorno_suavizado, hull_indices)
                                senos_profundos = 0
                                if defectos is not None:
                                    for i in range(defectos.shape[0]):
                                        s, e, f, d = defectos[i, 0] 
                                        profundidad = d / 256.0 
                                        if profundidad > (w * 0.10): 
                                            senos_profundos += 1
                                datos_hojas['solidez'].append(senos_profundos)
                            else:
                                datos_hojas['solidez'].append(0)
                        except cv2.error:
                            datos_hojas['solidez'].append(0)

                    # --- RACIMOS (1) ---
                    elif clase_id == 1:
                        datos_racimos['longitud'].append(h)
                        area_caja = w * h
                        compacidad = float(area) / area_caja if area_caja > 0 else 0
                        datos_racimos['compacidad'].append(compacidad)
                        datos_racimos['forma'].append(w / float(h) if h > 0 else 0)

                    # --- BAYAS (2) ---
                    elif clase_id == 2:
                        rect = cv2.minAreaRect(contorno)
                        (ancho_rot, alto_rot) = rect[1]
                        largo_real = max(ancho_rot, alto_rot)
                        ancho_real = min(ancho_rot, alto_rot)
                        
                        datos_bayas['longitud'].append(largo_real) 
                        ratio_real = largo_real / ancho_real if ancho_real > 0 else 0
                        datos_bayas['forma_real'].append(ratio_real)
                        
                        M = cv2.moments(contorno)
                        if M["m00"] != 0:
                            cy = int(M["m01"] / M["m00"])
                        else:
                            cy = y + h/2

                        centro_caja_y = y + (h / 2)
                        desplazamiento_y = (cy - centro_caja_y) / float(h) if h > 0 else 0
                        datos_bayas['desplazamiento_y'].append(desplazamiento_y)
                        
                        hull = cv2.convexHull(contorno)
                        area_hull = cv2.contourArea(hull)
                        solidez = float(area) / area_hull if area_hull > 0 else 1
                        datos_bayas['solidez'].append(solidez)
                        
                        mascara_uva = np.zeros(imagen.shape[:2], dtype=np.uint8)
                        cv2.drawContours(mascara_uva, [contorno], -1, 255, -1)
                        color_medio = cv2.mean(imagen, mask=mascara_uva)
                        
                        datos_bayas['color_b'].append(color_medio[0])
                        datos_bayas['color_g'].append(color_medio[1])
                        datos_bayas['color_r'].append(color_medio[2])

    # ==========================================
    # CONSTRUCCIÓN DEL DICCIONARIO DE RESPUESTA
    # ==========================================
    def media(lista):
        return sum(lista)/len(lista) if len(lista) > 0 else 0

    respuesta_app = {
        "hojas": None,
        "racimos": None,
        "bayas": None,
        "status": "success"
    }

    # Procesar Hojas
    if len(datos_hojas['area']) > 0:
        area_m = media(datos_hojas['area'])
        forma_m = media(datos_hojas['forma'])
        senos_m = round(media(datos_hojas['solidez']))
        
        v_065 = calcular_oiv_065(area_m)
        v_067, n_067 = calcular_oiv_067(forma_m, senos_m)
        v_068, n_068 = calcular_oiv_068(senos_m)
        
        respuesta_app["hojas"] = {
            "muestras_detectadas": len(datos_hojas['area']),
            "oiv_065": {"valor": v_065, "descripcion": f"Media: {area_m:.0f} px"},
            "oiv_067": {"valor": v_067, "descripcion": n_067},
            "oiv_068": {"valor": v_068, "descripcion": n_068}
        }

    # Procesar Racimos
    if len(datos_racimos['longitud']) > 0:
        long_m = media(datos_racimos['longitud'])
        forma_m = media(datos_racimos['forma'])
        comp_m = media(datos_racimos['compacidad'])
        
        v_202 = calcular_oiv_202(long_m)
        v_204, n_204 = calcular_oiv_204(comp_m)
        v_208, n_208 = calcular_oiv_208(forma_m)
        
        respuesta_app["racimos"] = {
            "muestras_detectadas": len(datos_racimos['longitud']),
            "oiv_202": {"valor": v_202, "descripcion": f"Media: {long_m:.0f} px"},
            "oiv_204": {"valor": v_204, "descripcion": n_204},
            "oiv_208": {"valor": v_208, "descripcion": n_208}
        }

    # Procesar Bayas
    if len(datos_bayas['longitud']) > 0:
        long_m = media(datos_bayas['longitud'])
        forma_m = media(datos_bayas['forma_real']) 
        desplazamiento = media(datos_bayas['desplazamiento_y'])
        solidez = media(datos_bayas['solidez'])
        
        r_med = media(datos_bayas['color_r'])
        g_med = media(datos_bayas['color_g'])
        b_med = media(datos_bayas['color_b'])
        
        v_220 = calcular_oiv_220(long_m)
        v_223, n_223 = calcular_oiv_223_avanzado(forma_m, desplazamiento, solidez)
        v_225, n_225 = calcular_oiv_225(r_med, g_med, b_med)
        
        respuesta_app["bayas"] = {
            "muestras_detectadas": len(datos_bayas['longitud']),
            "oiv_220": {"valor": v_220, "descripcion": f"Media: {long_m:.0f} px"},
            "oiv_223": {"valor": v_223, "descripcion": n_223},
            "oiv_225": {"valor": v_225, "descripcion": n_225},
            "tecnico": {
                "rgb_medio": f"R:{r_med:.0f} G:{g_med:.0f} B:{b_med:.0f}",
                "ratio_real": round(forma_m, 2),
                "asimetria": round(desplazamiento, 3)
            }
        }

    return respuesta_app

def comparar_variedades(resultados_ia, ruta_json=None):
    """
    Compara los resultados de la IA con el archivo JSON y devuelve las mejores coincidencias.
    """
    if ruta_json is None:
        ruta_json = os.path.join(os.path.dirname(__file__), "variedades.json")
        
    # 1. Cargar la base de datos de variedades
    try:
        with open(ruta_json, 'r', encoding='utf-8') as archivo:
            base_datos = json.load(archivo)
    except FileNotFoundError:
        return {"error": f"No se encontró el archivo {ruta_json}"}

    # 2. Extraer solo los valores numéricos detectados por la IA
    datos_detectados = {}
    
    if resultados_ia.get("hojas"):
        datos_detectados["065"] = resultados_ia["hojas"]["oiv_065"]["valor"]
        datos_detectados["067"] = resultados_ia["hojas"]["oiv_067"]["valor"]
        datos_detectados["068"] = resultados_ia["hojas"]["oiv_068"]["valor"]
        
    if resultados_ia.get("racimos"):
        datos_detectados["202"] = resultados_ia["racimos"]["oiv_202"]["valor"]
        datos_detectados["204"] = resultados_ia["racimos"]["oiv_204"]["valor"]
        datos_detectados["208"] = resultados_ia["racimos"]["oiv_208"]["valor"]
        
    if resultados_ia.get("bayas"):
        datos_detectados["220"] = resultados_ia["bayas"]["oiv_220"]["valor"]
        datos_detectados["223"] = resultados_ia["bayas"]["oiv_223"]["valor"]
        datos_detectados["225"] = resultados_ia["bayas"]["oiv_225"]["valor"]

    resultados_comparacion = []

    # 3. Comparar con cada variedad
    for variedad in base_datos:
        puntuacion_total = 0
        descriptores_evaluados = 0
        oiv_reales = variedad["descriptores_oiv"]
        
        for codigo_oiv, valor_ia in datos_detectados.items():
            if valor_ia == "N/A" or not isinstance(valor_ia, (int, float)):
                continue
                
            if codigo_oiv in oiv_reales:
                valor_real = oiv_reales[codigo_oiv]
                diferencia = abs(valor_ia - valor_real)
                
                # Sistema de puntuación
                if diferencia == 0: puntuacion = 100
                elif diferencia <= 1.5: puntuacion = 80
                elif diferencia <= 2.5: puntuacion = 50
                elif diferencia <= 4: puntuacion = 20
                else: puntuacion = 0
                    
                puntuacion_total += puntuacion
                descriptores_evaluados += 1
                
        # 4. Calcular porcentaje
        if descriptores_evaluados > 0:
            porcentaje_similitud = puntuacion_total / descriptores_evaluados
            # Inferencia de color desde OIV 225 (Antocianos)
            oiv_225 = oiv_reales.get("225")
            color_inferido = "Blanca" if oiv_225 == 1 else "Tinta"

            resultados_comparacion.append({
                "nombre": variedad["nombre"],
                "similitud": round(porcentaje_similitud, 1),
                "descriptores_usados": descriptores_evaluados,
                "color": color_inferido
            })
        
    # Ordenar de mayor a menor similitud
    return sorted(resultados_comparacion, key=lambda x: x["similitud"], reverse=True)
