import logging
import os
import firebase_admin
from firebase_admin import credentials, messaging

logger = logging.getLogger(__name__)

# Inicializar Firebase Admin SDK si no está inicializado
try:
    if not firebase_admin._apps:
        # Busca el archivo en la raíz del backend
        cred_path = os.path.join(os.path.dirname(__file__), "../../firebase-adminsdk.json")
        if os.path.exists(cred_path):
            cred = credentials.Certificate(cred_path)
            firebase_admin.initialize_app(cred)
            logger.info("Firebase Admin SDK inicializado correctamente.")
        else:
            logger.warning(f"No se encontró {cred_path}. Las notificaciones Push no funcionarán.")
except Exception as e:
    logger.error(f"Error inicializando Firebase Admin SDK: {e}")

def send_push_notification(tokens: list[str], title: str, body: str, data: dict = None):
    """
    Envía una notificación Push a través de FCM usando firebase-admin.
    """
    if not tokens:
        return
    
    logger.info(f"Enviando PUSH a {len(tokens)} tokens: {title} - {body} | Data: {data}")
    
    if not firebase_admin._apps:
        logger.warning("FCM no está inicializado. Notificación omitida.")
        return
        
    try:
        # Convertimos los valores del diccionario data a strings (FCM lo requiere)
        stringified_data = {}
        if data:
            for k, v in data.items():
                stringified_data[str(k)] = str(v)
                
        message = messaging.MulticastMessage(
            notification=messaging.Notification(
                title=title,
                body=body,
            ),
            data=stringified_data,
            tokens=tokens,
        )
        
        response = messaging.send_each_for_multicast(message)
        logger.info(f"Notificaciones enviadas: {response.success_count} exitosas, {response.failure_count} fallidas.")
    except Exception as e:
        logger.error(f"Error al enviar notificación push: {e}")
