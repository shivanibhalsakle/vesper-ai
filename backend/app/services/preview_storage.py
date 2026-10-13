import base64
import io
from datetime import timedelta
from typing import Protocol

import firebase_admin
from firebase_admin import credentials, storage
from PIL import Image

from app.core.config import get_settings

# Signed links are re-issued on every list, so they only need to outlive one
# viewing session.
SIGNED_URL_TTL = timedelta(hours=1)
WEBP_QUALITY = 82


class PreviewStorage(Protocol):
    def upload(self, path: str, data: bytes, content_type: str) -> None: ...
    def signed_url(self, path: str) -> str: ...
    def delete(self, path: str) -> None: ...


class FirebasePreviewStorage:
    """Previews live in the project's Firebase Storage bucket, written and
    read by the backend only (the client never gets write access).
    """

    def __init__(self, bucket_name: str):
        try:
            firebase_admin.get_app()
        except ValueError:
            path = get_settings().firebase_credentials_path
            firebase_admin.initialize_app(credentials.Certificate(path))
        self._bucket = storage.bucket(bucket_name)

    def upload(self, path: str, data: bytes, content_type: str) -> None:
        self._bucket.blob(path).upload_from_string(data, content_type=content_type)

    def signed_url(self, path: str) -> str:
        return self._bucket.blob(path).generate_signed_url(
            version="v4", expiration=SIGNED_URL_TTL, method="GET"
        )

    def delete(self, path: str) -> None:
        self._bucket.blob(path).delete()


def get_default_storage() -> PreviewStorage | None:
    """The configured store, or None when no bucket is set up (previews then
    still generate, just without being saved)."""
    settings = get_settings()
    if not settings.firebase_storage_bucket or not settings.firebase_credentials_path:
        return None
    return FirebasePreviewStorage(settings.firebase_storage_bucket)


def decode_data_uri(image_url: str) -> bytes | None:
    """The image bytes inside a `data:image/...;base64,...` URI, or None for
    anything else (a hosted URL can't be re-encoded here)."""
    if not image_url.startswith("data:"):
        return None
    try:
        return base64.b64decode(image_url.split(",", 1)[1])
    except (IndexError, ValueError):
        return None


def to_webp(image_bytes: bytes) -> bytes:
    """WebP bytes for this image: roughly a tenth of a PNG's size, which is
    what keeps saving every preview inside the free storage quota (and keeps
    the Redis cache and the response small). Already-WebP input is returned
    untouched, so it is never re-compressed."""
    with Image.open(io.BytesIO(image_bytes)) as image:
        if image.format == "WEBP":
            return image_bytes
        out = io.BytesIO()
        image.convert("RGB").save(out, format="WEBP", quality=WEBP_QUALITY, method=4)
        return out.getvalue()


def shrink_data_uri(image_url: str) -> str:
    """A `data:image/webp` URI for a data-URI image; anything else, or an
    image that can't be re-encoded, comes back unchanged."""
    data = decode_data_uri(image_url)
    if data is None:
        return image_url
    try:
        webp = to_webp(data)
    except Exception:
        return image_url
    return "data:image/webp;base64," + base64.b64encode(webp).decode()
