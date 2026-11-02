from __future__ import annotations

from fastapi.testclient import TestClient

from app.apis.health import get_health_service
from app.main import app


class FakeHealthService:
    def check(self):
        return {"status": "ok", "database": "ok"}


def test_health_is_public_and_reports_database_status() -> None:
    app.dependency_overrides[get_health_service] = lambda: FakeHealthService()
    try:
        response = TestClient(app).get("/health")
    finally:
        app.dependency_overrides.clear()
    assert response.status_code == 200
    assert response.json() == {"status": "ok", "database": "ok"}


def test_health_get_response_is_not_cached() -> None:
    app.dependency_overrides[get_health_service] = lambda: FakeHealthService()
    try:
        response = TestClient(app).get("/health")
    finally:
        app.dependency_overrides.clear()
    assert response.headers["cache-control"].startswith("no-store")
