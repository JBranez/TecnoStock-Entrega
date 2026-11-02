"""Dependencias compartidas de FastAPI."""

from __future__ import annotations

from collections.abc import Generator
from typing import Any

from fastapi import Depends
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from app.core.exceptions import AuthenticationError
from app.core.security import decode_access_token
from app.db.connection import connect_db

bearer_scheme = HTTPBearer(auto_error=False)


def get_db() -> Generator[Any, None, None]:
    connection = connect_db()
    try:
        yield connection
    finally:
        connection.close()


def get_protected_db(
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer_scheme),
) -> Generator[Any, None, None]:
    """Valida el JWT antes de abrir una conexión y la comparte dentro del request."""
    if credentials is None or credentials.scheme.lower() != "bearer":
        raise AuthenticationError("Debes iniciar sesión para continuar.")
    decode_access_token(credentials.credentials)
    connection = connect_db()
    try:
        yield connection
    finally:
        connection.close()


def get_current_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer_scheme),
    connection: Any = Depends(get_protected_db),
) -> dict[str, Any]:
    if credentials is None or credentials.scheme.lower() != "bearer":
        raise AuthenticationError("Debes iniciar sesión para continuar.")
    payload = decode_access_token(credentials.credentials)
    username = payload.get("sub")
    if not isinstance(username, str) or not username:
        raise AuthenticationError("La sesión no es válida. Inicia sesión nuevamente.")

    from app.repositories.auth_repository import AuthRepository

    user = AuthRepository(connection).get_by_username(username)
    if not user or not user.get("activo"):
        raise AuthenticationError("La cuenta no existe o está desactivada.")
    return {
        "id": int(user["id"]),
        "username": user["username"],
        "nombre_completo": user["nombre_completo"],
    }
