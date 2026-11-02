"""Hash Argon2 y tokens JWT para la autenticación de la API.

En la instalación objetivo se utiliza pwdlib[argon2]. El adaptador alternativo
solo permite ejecutar pruebas aisladas en entornos sin esa dependencia instalada;
ambos formatos son Argon2id y compatibles con la validación correspondiente.
"""

from __future__ import annotations

from datetime import datetime, timedelta, timezone
from typing import Any

import jwt

from app.core.config import get_settings
from app.core.exceptions import AuthenticationError

try:
    from pwdlib import PasswordHash

    _password_hash = PasswordHash.recommended()
    _argon2_fallback = None
except ImportError:  # entorno de pruebas restringido; pwdlib se instala en el proyecto real
    from argon2 import PasswordHasher

    _password_hash = None
    _argon2_fallback = PasswordHasher()


def hash_password(password: str) -> str:
    if _password_hash is not None:
        return _password_hash.hash(password)
    assert _argon2_fallback is not None
    return _argon2_fallback.hash(password)


def verify_password(password: str, password_hash: str) -> bool:
    try:
        if _password_hash is not None:
            return _password_hash.verify(password, password_hash)
        assert _argon2_fallback is not None
        return _argon2_fallback.verify(password_hash, password)
    except Exception:
        return False


def create_access_token(*, user_id: int, username: str, full_name: str) -> tuple[str, int]:
    settings = get_settings()
    if len(settings.jwt_secret_key) < 32:
        raise RuntimeError("JWT_SECRET_KEY debe contener al menos 32 caracteres.")
    expires_in = settings.access_token_expire_minutes
    now = datetime.now(timezone.utc)
    payload: dict[str, Any] = {
        "sub": username,
        "uid": user_id,
        "name": full_name,
        "iat": now,
        "exp": now + timedelta(minutes=expires_in),
    }
    token = jwt.encode(payload, settings.jwt_secret_key, algorithm=settings.jwt_algorithm)
    return token, expires_in * 60


def decode_access_token(token: str) -> dict[str, Any]:
    settings = get_settings()
    if len(settings.jwt_secret_key) < 32:
        raise AuthenticationError("La autenticación no está configurada correctamente.")
    try:
        return jwt.decode(token, settings.jwt_secret_key, algorithms=[settings.jwt_algorithm])
    except jwt.InvalidTokenError as exc:
        raise AuthenticationError("La sesión expiró o no es válida. Inicia sesión nuevamente.") from exc
