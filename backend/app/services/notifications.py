from abc import ABC, abstractmethod


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
