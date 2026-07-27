import app.services.notifications as notifications_module
from app.services.notifications import (
    FirebaseCloudMessagingNotifier,
    UnconfiguredPushNotifier,
    _get_default_notifier,
)


def test_default_notifier_is_unconfigured_without_credentials_path(monkeypatch):
    monkeypatch.setattr(
        notifications_module,
        "get_settings",
        lambda: type("S", (), {"firebase_credentials_path": ""})(),
    )

    assert isinstance(_get_default_notifier(), UnconfiguredPushNotifier)


def test_default_notifier_is_firebase_with_credentials_path(monkeypatch):
    monkeypatch.setattr(
        notifications_module,
        "get_settings",
        lambda: type("S", (), {"firebase_credentials_path": "fake.json"})(),
    )
    monkeypatch.setattr(notifications_module.firebase_admin, "get_app", lambda: object())

    assert isinstance(_get_default_notifier(), FirebaseCloudMessagingNotifier)


def test_firebase_notifier_sends_via_messaging(monkeypatch):
    # get_app succeeding (not raising ValueError) short-circuits __init__ past
    # credentials.Certificate/initialize_app, so no real service account file
    # is needed for this test.
    monkeypatch.setattr(notifications_module.firebase_admin, "get_app", lambda: object())
    sent = {}

    def fake_send(message):
        sent["token"] = message.token
        sent["title"] = message.notification.title
        sent["body"] = message.notification.body

    monkeypatch.setattr(notifications_module.messaging, "send", fake_send)

    notifier = FirebaseCloudMessagingNotifier(credentials_path="unused.json")
    notifier.send_notification("token-123", "Sunset alert", "Great match tonight")

    assert sent == {
        "token": "token-123",
        "title": "Sunset alert",
        "body": "Great match tonight",
    }