import app.api.internal as internal_module


def _set_secret(monkeypatch, secret: str):
    monkeypatch.setattr(
        internal_module,
        "get_settings",
        lambda: type("S", (), {"internal_api_secret": secret})(),
    )


def test_rejects_missing_secret_header(client, monkeypatch):
    _set_secret(monkeypatch, "correct-secret")

    response = client.post("/internal/rescore-notifications")

    assert response.status_code == 401


def test_rejects_wrong_secret(client, monkeypatch):
    _set_secret(monkeypatch, "correct-secret")

    response = client.post(
        "/internal/rescore-notifications",
        headers={"X-Internal-Secret": "wrong-secret"},
    )

    assert response.status_code == 401


def test_rejects_any_secret_when_none_configured(client, monkeypatch):
    _set_secret(monkeypatch, "")

    response = client.post(
        "/internal/rescore-notifications",
        headers={"X-Internal-Secret": ""},
    )

    assert response.status_code == 401


def test_accepts_correct_secret_and_runs_rescore(client, monkeypatch):
    _set_secret(monkeypatch, "correct-secret")
    calls = []
    monkeypatch.setattr(
        internal_module,
        "rescore_saved_profiles",
        lambda db: calls.append(db) or [{"profile_id": "p1", "status": "sent"}],
    )

    response = client.post(
        "/internal/rescore-notifications",
        headers={"X-Internal-Secret": "correct-secret"},
    )

    assert response.status_code == 200
    assert response.json() == [{"profile_id": "p1", "status": "sent"}]
    assert len(calls) == 1
