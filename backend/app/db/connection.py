"""Creación de conexiones pyodbc para la API."""

from __future__ import annotations

from typing import Any

from app.core.config import Settings, get_settings
from app.core.exceptions import DatabaseUnavailableError


def connect_db(settings: Settings | None = None) -> Any:
    config = settings or get_settings()
    if not config.db_app_password:
        raise DatabaseUnavailableError("Configura DB_APP_PASSWORD en backend/.env.")
    try:
        import pyodbc

        return pyodbc.connect(config.database_connection_string(), autocommit=True, timeout=10)
    except ImportError as exc:
        raise DatabaseUnavailableError("Falta instalar pyodbc y el ODBC Driver 18 for SQL Server.") from exc
    except Exception as exc:
        # No se adjunta la cadena de conexión ni el mensaje del driver a la respuesta HTTP.
        raise DatabaseUnavailableError() from exc
