def _payload(**overrides):
    body = {
        "location_id": "osm:node/123",
        "location_name": "Brooklyn Bridge Park",
        "location_type": "waterfront",
        "event": "sunset",
        "event_date": "2026-07-20",
        "photo_storage_path": "gs://vesper-feedback/user-abc/photo1.jpg",
        "preference_profile": {"golden_orange": 1.0, "dramatic_clouds": 0.5},
        "forecast_snapshot": {
            "cloud_cover_summary": "partly cloudy (high clouds)",
            "visibility_likelihood": 0.85,
            "color_probabilities": {
                "pink": 0.3,
                "purple": 0.2,
                "orange": 0.8,
                "red": 0.1,
                "golden": 0.9,
            },
            "preference_match_score": 0.78,
        },
        "user_id": "user-abc",
    }
    body.update(overrides)
    return body


def test_submit_feedback_returns_persisted_record(client):
    response = client.post("/feedback", json=_payload())
    body = response.json()

    assert response.status_code == 201
    assert body["id"]
    assert body["location_id"] == "osm:node/123"
    assert body["photo_storage_path"] == "gs://vesper-feedback/user-abc/photo1.jpg"
    assert body["preference_profile"]["golden_orange"] == 1.0
    assert body["forecast_snapshot"]["preference_match_score"] == 0.78
    assert body["created_at"]


def test_list_feedback_filters_by_location_id(client):
    client.post("/feedback", json=_payload(location_id="loc-a"))
    client.post("/feedback", json=_payload(location_id="loc-a", user_id="user-2"))
    client.post("/feedback", json=_payload(location_id="loc-b"))

    response = client.get("/feedback", params={"location_id": "loc-a"})
    body = response.json()

    assert response.status_code == 200
    assert len(body) == 2
    assert all(entry["location_id"] == "loc-a" for entry in body)


def test_list_feedback_returns_empty_for_unknown_location(client):
    response = client.get("/feedback", params={"location_id": "no-such-location"})

    assert response.status_code == 200
    assert response.json() == []


def test_feedback_without_user_id_is_allowed(client):
    payload = _payload()
    del payload["user_id"]

    response = client.post("/feedback", json=payload)
    body = response.json()

    assert response.status_code == 201
    assert body["user_id"] is None
