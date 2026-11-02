from __future__ import annotations

from app.core.config import Settings
from app.core import security
from app.core.exceptions import AuthenticationError


def test_password_hash_is_argon2_and_verifies() -> None:
    hashed = security.hash_password("clave-demostracion-segura")
    assert hashed.startswith("$argon2")
    assert security.verify_password("clave-demostracion-segura", hashed)
    assert not security.verify_password("otra-clave", hashed)


def test_jwt_round_trip(monkeypatch) -> None:
    settings = Settings(_env_file=None, jwt_secret_key="x" * 48, access_token_expire_minutes=30)
    monkeypatch.setattr(security, "get_settings", lambda: settings)
    token, expires_in = security.create_access_token(user_id=5, username="admin", full_name="Administrador")
    assert expires_in == 1800
    payload = security.decode_access_token(token)
    assert payload["sub"] == "admin"
    assert payload["uid"] == 5


def test_invalid_jwt_raises_domain_authentication_error(monkeypatch) -> None:
    settings = Settings(_env_file=None, jwt_secret_key="x" * 48)
    monkeypatch.setattr(security, "get_settings", lambda: settings)
    try:
        security.decode_access_token("no-es-un-token")
    except AuthenticationError as exc:
        assert exc.status_code == 401
    else:
        raise AssertionError("Se esperaba AuthenticationError")
