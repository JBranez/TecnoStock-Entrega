"""Funciones comunes para repositorios basados exclusivamente en procedimientos."""

from __future__ import annotations

import re
from typing import Any

from app.db.executor import call_procedure
from app.repositories.db_errors import raise_database_error

_CAMEL_BOUNDARY = re.compile(r"([a-z0-9])([A-Z])")


def normalize_row(row: dict[str, Any]) -> dict[str, Any]:
    """Convierte aliases PascalCase/SQL a snake_case para los schemas Pydantic."""
    return {_CAMEL_BOUNDARY.sub(r"\1_\2", key).lower(): value for key, value in row.items()}


class BaseRepository:
    def __init__(self, connection: Any) -> None:
        self.connection = connection

    def execute(self, procedure_name: str, parameters: dict[str, Any] | None = None) -> list[list[dict[str, Any]]]:
        try:
            return [
                [normalize_row(row) for row in result_set]
                for result_set in call_procedure(self.connection, procedure_name, parameters)
            ]
        except Exception as exc:
            raise_database_error(exc, procedure_name=procedure_name)

    def first(self, procedure_name: str, parameters: dict[str, Any] | None = None) -> dict[str, Any] | None:
        result_sets = self.execute(procedure_name, parameters)
        for result_set in result_sets:
            if result_set:
                return result_set[0]
        return None
