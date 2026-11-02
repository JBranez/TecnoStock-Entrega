"""Repositorio de salud: ejecuta un SP real para comprobar la conexión."""

from __future__ import annotations

from typing import Any

from app.db.executor import call_procedure
from app.repositories.db_errors import raise_database_error


class HealthRepository:
    def __init__(self, connection: Any) -> None:
        self.connection = connection

    def check(self) -> None:
        try:
            call_procedure(
                self.connection,
                "dbo.usp_Dashboard_ObtenerIndicadores",
                {"FechaDesde": None, "FechaHasta": None},
            )
        except Exception as exc:
            raise_database_error(exc, procedure_name="dbo.usp_Dashboard_ObtenerIndicadores")
