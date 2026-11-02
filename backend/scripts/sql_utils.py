"""Utilidades pequeñas para ejecutar scripts SQL Server que usan separadores GO."""

from __future__ import annotations

import re

_GO_PATTERN = re.compile(r"(?im)^\s*GO\s*(?:--.*)?$")


def split_batches(script: str) -> list[str]:
    """Divide un script por GO aislado en una línea, sin romper texto entrecomillado."""
    return [batch.strip() for batch in _GO_PATTERN.split(script) if batch.strip()]


def quote_sql_identifier(value: str) -> str:
    """Devuelve un identificador SQL Server entre corchetes de forma segura."""
    if not value or not value.strip():
        raise ValueError("El identificador SQL no puede estar vacío.")
    return "[" + value.replace("]", "]]" ) + "]"


def replace_sql_placeholders(
    script: str,
    *,
    db_name: str,
    app_user: str,
    app_password: str,
) -> str:
    """Sustituye únicamente los marcadores conocidos con escape de SQL Server."""
    escaped_password = app_password.replace("'", "''")
    escaped_user = app_user.replace("'", "''")
    escaped_db_name = db_name.replace("'", "''")
    return (
        script.replace("__DB_NAME_TEXT__", escaped_db_name)
        .replace("__DB_NAME__", quote_sql_identifier(db_name))
        .replace("__DB_APP_USER__", escaped_user)
        .replace("__DB_APP_PASSWORD__", escaped_password)
    )
