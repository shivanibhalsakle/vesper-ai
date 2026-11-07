"""Deleting a user's account and everything stored about them.

Required by Google Play for any app that lets people create an account. It
removes the user's files, their database rows, and finally their sign-in.
"""

import logging
from collections.abc import Callable

from firebase_admin import auth as firebase_auth
from sqlalchemy.orm import Session

from app.models.feedback import FeedbackEntry
from app.models.generated_preview import GeneratedPreview
from app.models.image_usage import ImageGenerationUsage
from app.models.saved_date import SavedDate
from app.models.saved_profile import SavedProfile
from app.models.user_preferences import UserPreferences
from app.models.user_profile import UserProfile
from app.services.preview_storage import PreviewStorage

logger = logging.getLogger(__name__)

# Per-user folders in the Firebase Storage bucket: feedback photos (uploaded by
# the app), profile pictures (uploaded by the app) and generated sky previews.
STORAGE_FOLDERS = ("feedback", "profiles", "previews")

# Every table with a user_id column.
OWNED_MODELS = (
    FeedbackEntry,
    GeneratedPreview,
    ImageGenerationUsage,
    SavedDate,
    SavedProfile,
    UserPreferences,
    UserProfile,
)


class AccountDeletionFailed(Exception):
    """A step failed. Everything is safe to retry: each step can run again."""

    def __init__(self, step: str):
        super().__init__(f"Account deletion failed at: {step}")
        self.step = step


def delete_firebase_user(user_id: str) -> None:
    try:
        firebase_auth.delete_user(user_id)
    except firebase_auth.UserNotFoundError:
        pass  # already gone: a retry after a half-finished attempt


def delete_account(
    db: Session,
    user_id: str,
    storage: PreviewStorage | None,
    delete_sign_in: Callable[[str], None] = delete_firebase_user,
) -> None:
    """Deletes files first, then database rows, and the sign-in last. The
    order matters: once the sign-in is gone the user can't call us again, so
    anything still left over could never be cleaned up by a retry.
    """
    if not user_id or "/" in user_id:
        raise ValueError("Unsafe user id")

    if storage is not None:
        try:
            for folder in STORAGE_FOLDERS:
                storage.delete_prefix(f"{folder}/{user_id}/")
        except Exception as exc:
            logger.warning("Account deletion: removing files failed", exc_info=True)
            raise AccountDeletionFailed("files") from exc

    try:
        for model in OWNED_MODELS:
            db.query(model).filter(model.user_id == user_id).delete(synchronize_session=False)
        db.commit()
    except Exception as exc:
        db.rollback()
        logger.warning("Account deletion: removing data failed", exc_info=True)
        raise AccountDeletionFailed("data") from exc

    try:
        delete_sign_in(user_id)
    except Exception as exc:
        logger.warning("Account deletion: removing sign-in failed", exc_info=True)
        raise AccountDeletionFailed("sign-in") from exc
