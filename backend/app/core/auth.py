import firebase_admin
from fastapi import Header, HTTPException
from firebase_admin import auth, credentials

from app.core.config import get_settings


def get_current_user_id(authorization: str | None = Header(default=None)) -> str:
    """Verifies a Firebase ID token from the Authorization header and returns
    the signed-in user's uid. Raises 401 on a missing/invalid/expired token.
    """
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Missing or invalid Authorization header.")

    token = authorization.removeprefix("Bearer ")

    try:
        firebase_admin.get_app()
    except ValueError:
        path = get_settings().firebase_credentials_path
        if not path:
            raise HTTPException(
                status_code=503,
                detail="Sign-in verification is not configured on this server.",
            )
        firebase_admin.initialize_app(credentials.Certificate(path))

    try:
        decoded = auth.verify_id_token(token)
    except Exception:
        raise HTTPException(status_code=401, detail="Invalid or expired sign-in token.")

    return decoded["uid"]
