def _payload(**overrides):
    body = {
        "user_id": "user-abc",
        "home_lat": 40.7003,
        "home_lon": -73.9967,
        "radius_km": 10.0,
        "place_types": ["park", "waterfront"],
        "event": "sunset",
        "tz_name": "America/New_York",
        "preference_profile": {"golden_orange": 1.0, "dramatic_clouds": 0.5},
        "fcm_token": "fake-device-token",
        "notification_enabled": True,
        "match_threshold": 0.7,
    }
    body.update(overrides)
    return body


def test_submit_profile_returns_persisted_record(client):
    response = client.post("/profiles", json=_payload())
    body = response.json()

    assert response.status_code == 201
    assert body["id"]
    assert body["user_id"] == "user-abc"
    assert body["place_types"] == ["park", "waterfront"]
    assert body["preference_profile"]["golden_orange"] == 1.0
    assert body["notification_enabled"] is True
    assert body["match_threshold"] == 0.7


def test_list_profiles_filters_by_user_id(client):
    client.post("/profiles", json=_payload(user_id="user-a"))
    client.post("/profiles", json=_payload(user_id="user-a", event="sunrise"))
    client.post("/profiles", json=_payload(user_id="user-b"))

    response = client.get("/profiles", params={"user_id": "user-a"})
    body = response.json()

    assert response.status_code == 200
    assert len(body) == 2
    assert all(p["user_id"] == "user-a" for p in body)


def test_list_profiles_returns_empty_for_unknown_user(client):
    response = client.get("/profiles", params={"user_id": "no-such-user"})

    assert response.status_code == 200
    assert response.json() == []


def test_profile_without_fcm_token_is_allowed(client):
    payload = _payload()
    del payload["fcm_token"]

    response = client.post("/profiles", json=payload)
    body = response.json()

    assert response.status_code == 201
    assert body["fcm_token"] is None
