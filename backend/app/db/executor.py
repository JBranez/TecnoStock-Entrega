"""Único punto de ejecución de procedimientos almacenados."""

from __future__ import annotations

import re
from typing import Any, Mapping

_PROCEDURE_PATTERN = re.compile(r"^dbo\.usp_\w+$")
_PARAMETER_PATTERN = re.compile(r"^[A-Za-z][A-Za-z0-9_]*$")


def call_procedure(
    connection: Any,
    procedure_name: str,
    parameters: Mapping[str, Any] | None = None,
) -> list[list[dict[str, Any]]]:
    """Ejecuta un SP con parámetros enlazados y devuelve todos sus result sets."""
    if not _PROCEDURE_PATTERN.fullmatch(procedure_name):
        raise ValueError("Nombre de procedimiento almacenado no permitido.")

    values = parameters or {}
    for parameter_name in values:
        if not _PARAMETER_PATTERN.fullmatch(parameter_name):
            raise ValueError("Nombre de parámetro no permitido.")

    assignments = ", ".join(f"@{name} = ?" for name in values)
    command = f"EXEC {procedure_name}" + (f" {assignments}" if assignments else "")
    cursor = connection.cursor()
    try:
        cursor.execute(command, *values.values())
        result_sets: list[list[dict[str, Any]]] = []
        while True:
            if cursor.description is not None:
                columns = [column[0] for column in cursor.description]
                result_sets.append(
                    [dict(zip(columns, tuple(row), strict=True)) for row in cursor.fetchall()]
                )
            if not cursor.nextset():
                break
        return result_sets
    finally:
        cursor.close()
