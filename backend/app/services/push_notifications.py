import logging

logger = logging.getLogger(__name__)

def send_push_notification(tokens: list[str], title: str, body: str, data: dict = None):
    """
    Simulación de envío de notificaciones Push (FCM).
    Si hay un SDK de Firebase configurado, aquí se llamaría a firebase_admin.messaging.
    """
    if not tokens:
        return
    
    logger.info(f"Simulando PUSH a {len(tokens)} tokens: {title} - {body} | Data: {data}")
    # TODO: Implementar integración real con FCM (firebase-admin)
    print(f"--> [PUSH] To: {tokens} | Title: {title} | Body: {body}")
