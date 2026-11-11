from datetime import date
from types import SimpleNamespace

import pytest
from pydantic import ValidationError

from app.core.config import Settings, get_settings
from app.services.image_limits import ImageLimitExceeded, ensure_within_daily_limit, record_usage
from app.services.simulation import OpenAIImageProvider

# A day no real usage row exists for, so the dev database can't interfere.
QUIET_DAY = date(2031, 1, 1)


def _settings(**changes):
    return get_settings().model_copy(update=changes)


def test_defaults_are_fifty_a_day_across_the_app_at_medium_quality():
    defaults = Settings(_env_file=None)

    assert defaults.preview_global_daily_limit == 50
    assert defaults.image_quality == "medium"


def test_the_app_wide_preview_cap_comes_from_settings(db_session, monkeypatch):
    monkeypatch.setattr(
        "app.services.image_limits.get_settings", lambda: _settings(preview_global_daily_limit=2)
    )
    record_usage(db_session, "user-a", QUIET_DAY)
    ensure_within_daily_limit(db_session, "user-c", QUIET_DAY)  # 1 of 2 used: fine

    record_usage(db_session, "user-b", QUIET_DAY)

    with pytest.raises(ImageLimitExceeded, match="across all users"):
        ensure_within_daily_limit(db_session, "user-c", QUIET_DAY)


def test_raising_the_cap_reopens_previews(db_session, monkeypatch):
    for user in ("user-a", "user-b"):
        record_usage(db_session, user, QUIET_DAY)
    monkeypatch.setattr(
        "app.services.image_limits.get_settings", lambda: _settings(preview_global_daily_limit=3)
    )

    ensure_within_daily_limit(db_session, "user-c", QUIET_DAY)


def test_the_image_provider_uses_the_configured_quality(monkeypatch):
    asked = {}

    class FakeImages:
        def generate(self, **kwargs):
            asked.update(kwargs)
            return SimpleNamespace(data=[SimpleNamespace(b64_json="AAAA")])

    monkeypatch.setattr(
        "app.services.simulation.get_settings", lambda: _settings(image_quality="low")
    )

    OpenAIImageProvider(client=SimpleNamespace(images=FakeImages())).generate_image("a sunset")

    assert asked["quality"] == "low"


def test_an_unknown_quality_is_rejected():
    with pytest.raises(ValidationError):
        Settings(_env_file=None, image_quality="ultra")
