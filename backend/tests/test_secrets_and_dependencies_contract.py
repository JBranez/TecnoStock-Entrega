from __future__ import annotations
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def _env_values(path: Path) -> dict[str, str]:
    result: dict[str, str] = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        item = line.strip()
        if not item or item.startswith("#") or "=" not in item:
            continue
        key, value = item.split("=", 1)
        result[key.strip()] = value.strip().strip('"').strip("'")
    return result


def test_environment_examples_expose_only_placeholders_for_secrets() -> None:
    for path in (ROOT / ".env.example", ROOT / "backend" / ".env.example"):
        values = _env_values(path)
        for key in ("MSSQL_SA_PASSWORD", "DB_APP_PASSWORD", "JWT_SECRET_KEY", "SEED_ADMIN_PASSWORD"):
            assert key in values
            assert not values[key] or values[key].startswith(("CAMBIAR_", "GENERAR_"))


def test_gitignore_excludes_real_environment_files_and_python_artifacts() -> None:
    text = (ROOT / ".gitignore").read_text(encoding="utf-8")
    for pattern in (".env", "**/.env", "**/.venv/", "**/__pycache__/", "*.py[cod]"):
        assert pattern in text
    assert "!.env.example" in text


def test_runtime_connection_uses_the_application_login_not_sa() -> None:
    source = (ROOT / "backend" / "app" / "core" / "config.py").read_text(encoding="utf-8")
    assert "db_app_user" in source
    assert "UID={user}" in source
    connection = (ROOT / "backend" / "app" / "db" / "connection.py").read_text(encoding="utf-8")
    assert "database_connection_string()" in connection
    assert 'username="sa"' not in connection
