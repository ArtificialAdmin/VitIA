import base64
import os
from datetime import datetime
from imagekitio import ImageKit
from imagekitio.models.UploadFileRequestOptions import UploadFileRequestOptions
from app.core.config import settings

# Inicialización del cliente usando settings de core
imagekit = ImageKit(
    private_key=settings.IMAGEKIT_PRIVATE_KEY,
    public_key=settings.IMAGEKIT_PUBLIC_KEY,
    url_endpoint=settings.IMAGEKIT_URL_ENDPOINT
)

def upload_image_to_imagekit(file_bytes: bytes, filename: str, folder: str = "/vitia") -> str:
    """Sube una imagen a ImageKit y devuelve su URL."""
    try:
        encoded_string = base64.b64encode(file_bytes).decode("utf-8")
        unique_filename = f"{datetime.utcnow().timestamp()}_{filename}"

        upload = imagekit.upload_file(
            file=encoded_string,
            file_name=unique_filename,
            options=UploadFileRequestOptions(
                folder=folder,
                is_private_file=False,
                use_unique_file_name=True,
                tags=["vitia-app"]
            )
        )

        image_url = upload.url 
        if not image_url:
            raise Exception("La respuesta de ImageKit no contiene URL")

        return image_url
    except Exception as e:
        print("EXCEPCIÓN EN IMAGEKIT:", str(e))
        raise