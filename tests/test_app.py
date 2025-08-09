from fastapi.testclient import TestClient
from app.main import app


client = TestClient(app)


def test_health():
    resp = client.get("/")
    assert resp.status_code == 200
    assert resp.json()["status"] == "ok"


def test_analyze_counts():
    payload = {"text": "I love cloud engineering!"}
    resp = client.post("/analyze", json=payload)
    assert resp.status_code == 200
    data = resp.json()
    assert data["original_text"] == payload["text"]
    assert data["word_count"] == 4
    # character_count excludes spaces; "I"(1)+"love"(4)+"cloud"(5)+
    # "engineering"(11)+"!"(1)=22
    assert data["character_count"] == 22
