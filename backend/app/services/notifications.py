from abc import ABC, abstractmethod
import firebase_admin
from firebase_admin import credentials, messaging

from app.core.config import get_settings

class PushNotifier(ABC):
    @abstractmethod
    def send_notification(self, token: str, title: str, body: str) -> None:
        """Sends a push notification to the given device token."""


class UnconfiguredPushNotifier(PushNotifier):
    """Placeholder until Firebase Cloud Messaging credentials are set up."""

    def send_notification(self, token: str, title: str, body: str) -> None:
        raise NotImplementedError("No push notification provider (FCM) configured yet.")


def send_notification_safely(
    notifier: PushNotifier, token: str, title: str, body: str
) -> tuple[bool, str]:
    try:
        notifier.send_notification(token, title, body)
        return True, "sent"
    except NotImplementedError:
        return False, "not_configured"
    except Exception:
        return False, "error"

class FirebaseCloudMessagingNotifier(PushNotifier):
    """Sends real push notifications via Firebase Cloud Messaging."""

    def __init__(self, credentials_path: str | None = None):
        path = credentials_path or get_settings().firebase_credentials_path
        try:
            firebase_admin.get_app()
        except ValueError:
            firebase_admin.initialize_app(credentials.Certificate(path))

    def send_notification(self, token: str, title: str, body: str) -> None:
        message = messaging.Message(
            notification=messaging.Notification(title=title, body=body),
            token=token,
        )
        messaging.send(message)


def _get_default_notifier() -> PushNotifier:
    if get_settings().firebase_credentials_path:
        return FirebaseCloudMessagingNotifier()
    return UnconfiguredPushNotifier()