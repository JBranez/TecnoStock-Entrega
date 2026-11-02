from __future__ import annotations

import pytest

from app.core.exceptions import AuthenticationError
from app.core.security import hash_password
from app.services import auth_service
from app.services.auth_service import AuthService


class FakeAuthRepository:
    def __init__(self, user):
        self.user = user

    def get_by_username(self, username: str):
        return self.user if self.user and self.user["username"] == username else None


def test_auth_service_returns_safe_user_and_bearer_token(monkeypatch) -> None:
    password_hash = hash_password("clave-larga-de-prueba")
    repository = FakeAuthRepository({
        "id": 3,
        "username": "admin",
        "nombre_completo": "Admin Demo",
        "password_hash": password_hash,
        "activo": True,
    })
    monkeypatch.setattr(auth_service, "create_access_token", lambda **_: ("jwt-falso", 3600))
    result = AuthService(repository).login(username="admin", password="clave-larga-de-prueba")
    assert result["access_token"] == "jwt-falso"
    assert result["token_type"] == "bearer"
    assert result["user"] == {"id": 3, "username": "admin", "nombre_completo": "Admin Demo"}
    assert "password_hash" not in result["user"]


@pytest.mark.parametrize("user,password", [
    (None, "clave-larga-de-prueba"),
    ({"id": 1, "username": "admin", "nombre_completo": "Admin", "password_hash": hash_password("otra-clave"), "activo": True}, "clave-larga-de-prueba"),
    ({"id": 1, "username": "admin", "nombre_completo": "Admin", "password_hash": hash_password("clave-larga-de-prueba"), "activo": False}, "clave-larga-de-prueba"),
])
def test_auth_service_rejects_invalid_inactive_or_unknown_user(user, password: str) -> None:
    with pytest.raises(AuthenticationError):
        AuthService(FakeAuthRepository(user)).login(username="admin", password=password)
