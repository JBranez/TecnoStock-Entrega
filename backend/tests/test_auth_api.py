from __future__ import annotations

from fastapi.testclient import TestClient

from app.apis.auth import get_auth_service
from app.apis.deps import get_current_user
from app.core.exceptions import AuthenticationError
from app.main import app


class FakeAuthService:
    def login(self, *, username: str, password: str):
        if username != "admin" or password != "clave-correcta":
            raise AuthenticationError()
        return {
            "access_token": "jwt-de-prueba",
            "token_type": "bearer",
            "expires_in": 3600,
            "user": {"id": 1, "username": "admin", "nombre_completo": "Administrador"},
        }


def test_login_valid_and_invalid_credentials() -> None:
    app.dependency_overrides[get_auth_service] = lambda: FakeAuthService()
    try:
        client = TestClient(app)
        valid = client.post("/api/v1/auth/login", json={"username": "admin", "password": "clave-correcta"})
        invalid = client.post("/api/v1/auth/login", json={"username": "admin", "password": "incorrecta"})
    finally:
        app.dependency_overrides.clear()
    assert valid.status_code == 200
    assert valid.json()["access_token"] == "jwt-de-prueba"
    assert "password_hash" not in valid.text
    assert invalid.status_code == 401
    assert invalid.json()["code"] == "CREDENCIALES_INVALIDAS"


def test_me_requires_token_before_opening_database() -> None:
    response = TestClient(app).get("/api/v1/auth/me")
    assert response.status_code == 401
    assert response.json()["code"] == "CREDENCIALES_INVALIDAS"


def test_me_returns_current_user_without_hash(monkeypatch) -> None:
    app.dependency_overrides[get_current_user] = lambda: {
        "id": 1, "username": "admin", "nombre_completo": "Administrador"
    }
    try:
        response = TestClient(app).get("/api/v1/auth/me", headers={"Authorization": "Bearer token-falso"})
    finally:
        app.dependency_overrides.clear()
    assert response.status_code == 200
    assert response.json() == {"id": 1, "username": "admin", "nombre_completo": "Administrador"}


def test_protected_category_endpoint_rejects_missing_token() -> None:
    response = TestClient(app).get("/api/v1/categorias")
    assert response.status_code == 401
    assert response.json()["code"] == "CREDENCIALES_INVALIDAS"
