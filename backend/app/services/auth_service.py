"""Casos de uso de autenticación."""

from __future__ import annotations

from typing import Any

from app.core.exceptions import AuthenticationError
from app.core.security import create_access_token, verify_password
from app.repositories.auth_repository import AuthRepository


class AuthService:
    def __init__(self, repository: AuthRepository) -> None:
        self.repository = repository

    def login(self, *, username: str, password: str) -> dict[str, Any]:
        user = self.repository.get_by_username(username)
        if not user:
            raise AuthenticationError()
        if not user.get("activo") or not verify_password(password, str(user.get("password_hash", ""))):
            raise AuthenticationError()

        token, expires_in = create_access_token(
            user_id=int(user["id"]),
            username=str(user["username"]),
            full_name=str(user["nombre_completo"]),
        )
        return {
            "access_token": token,
            "token_type": "bearer",
            "expires_in": expires_in,
            "user": {
                "id": int(user["id"]),
                "username": str(user["username"]),
                "nombre_completo": str(user["nombre_completo"]),
            },
        }

    @staticmethod
    def current_user(user: dict[str, Any]) -> dict[str, Any]:
        return {
            "id": int(user["id"]),
            "username": str(user["username"]),
            "nombre_completo": str(user["nombre_completo"]),
        }
