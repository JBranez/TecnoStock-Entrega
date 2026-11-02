from __future__ import annotations

import pytest

from app.db.executor import call_procedure


class FakeCursor:
    def __init__(self) -> None:
        self.description = [("Id",), ("Nombre",)]
        self.executed = None
        self.set_index = 0
        self.closed = False

    def execute(self, command, *parameters):
        self.executed = (command, parameters)
        return self

    def fetchall(self):
        if self.set_index == 0:
            return [(1, "Categoría A"), (2, "Categoría B")]
        return [(2,)]

    def nextset(self):
        self.set_index += 1
        if self.set_index == 1:
            self.description = [("Total",)]
            return True
        self.description = None
        return False

    def close(self):
        self.closed = True


class FakeConnection:
    def __init__(self) -> None:
        self.fake_cursor = FakeCursor()

    def cursor(self):
        return self.fake_cursor


def test_executor_binds_values_and_maps_all_result_sets() -> None:
    connection = FakeConnection()
    results = call_procedure(connection, "dbo.usp_Categoria_Listar", {"Id": 2, "Nombre": "A"})
    assert connection.fake_cursor.executed == (
        "EXEC dbo.usp_Categoria_Listar @Id = ?, @Nombre = ?",
        (2, "A"),
    )
    assert results[0] == [{"Id": 1, "Nombre": "Categoría A"}, {"Id": 2, "Nombre": "Categoría B"}]
    assert results[1] == [{"Total": 2}]
    assert connection.fake_cursor.closed is True


@pytest.mark.parametrize("name", ["SELECT 1", "dbo.Productos", "dbo.usp_x; DROP TABLE dbo.Productos", "usp_Listar"])
def test_executor_rejects_untrusted_procedure_names(name: str) -> None:
    with pytest.raises(ValueError):
        call_procedure(FakeConnection(), name)


def test_executor_rejects_parameter_name_injection() -> None:
    with pytest.raises(ValueError):
        call_procedure(FakeConnection(), "dbo.usp_Categoria_Listar", {"Id] = 1; SELECT 1--": 1})
