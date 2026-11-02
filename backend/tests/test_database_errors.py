from __future__ import annotations

import pytest

from app.core.exceptions import BusinessRuleError, ConflictError, NotFoundError
from app.repositories.db_errors import parse_database_error_message, raise_database_error


def test_parse_actual_pyodbc_thrown_business_error() -> None:
    message = "('42000', '[Microsoft][ODBC Driver 18 for SQL Server][SQL Server] STOCK_INSUFICIENTE|Stock disponible: 7. (50003) (SQLExecDirectW)')"
    assert parse_database_error_message(message) == ("STOCK_INSUFICIENTE", "Stock disponible: 7.")


def test_parse_actual_pyodbc_invalid_data_error() -> None:
    message = "[42000] [Microsoft][SQL Server] DATOS_INVALIDOS|La cantidad debe ser mayor que cero. (50010)"
    assert parse_database_error_message(message) == (
        "DATOS_INVALIDOS",
        "La cantidad debe ser mayor que cero.",
    )


def test_database_error_maps_not_found() -> None:
    with pytest.raises(NotFoundError) as raised:
        raise_database_error(Exception("PRODUCTO_NO_ENCONTRADO|El producto no existe."))
    assert raised.value.status_code == 404


def test_database_error_maps_conflict() -> None:
    with pytest.raises(ConflictError) as raised:
        raise_database_error(Exception("STOCK_INSUFICIENTE|Stock disponible: 4."))
    assert raised.value.status_code == 409


def test_database_error_maps_invalid_data() -> None:
    with pytest.raises(BusinessRuleError) as raised:
        raise_database_error(Exception("DATOS_INVALIDOS|Cantidad inválida."))
    assert raised.value.status_code == 422


def test_unique_constraint_uses_repository_context() -> None:
    with pytest.raises(ConflictError) as raised:
        raise_database_error(Exception("Violation of UNIQUE KEY constraint. Error 2627"), procedure_name="dbo.usp_Producto_Crear")
    assert raised.value.code == "CODIGO_DUPLICADO"
