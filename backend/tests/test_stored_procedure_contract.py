from __future__ import annotations

import re
from pathlib import Path

DATABASE = Path(__file__).resolve().parents[2] / "database"
EXPECTED_PROCEDURES = {
    "usp_Usuario_ObtenerPorUsername", "usp_Usuario_Crear",
    "usp_Categoria_Crear", "usp_Categoria_Actualizar", "usp_Categoria_ObtenerPorId",
    "usp_Categoria_Listar", "usp_Categoria_Eliminar",
    "usp_Producto_Crear", "usp_Producto_Actualizar", "usp_Producto_ObtenerPorId",
    "usp_Producto_Listar", "usp_Producto_CambiarEstado", "usp_Producto_Eliminar",
    "usp_Producto_ListarStockBajo",
    "usp_Movimiento_RegistrarEntrada", "usp_Movimiento_RegistrarSalida", "usp_Movimiento_Listar",
    "usp_Dashboard_ObtenerIndicadores",
    "usp_Usuario_ActualizarPassword",
}


def procedures() -> dict[str, str]:
    found: dict[str, str] = {}
    for path in DATABASE.glob("*_sp_*.sql"):
        text = path.read_text(encoding="utf-8")
        matches = list(re.finditer(r"CREATE\s+OR\s+ALTER\s+PROCEDURE\s+dbo\.(usp_\w+)", text, re.I))
        for index, match in enumerate(matches):
            end = matches[index + 1].start() if index + 1 < len(matches) else len(text)
            found[match.group(1)] = text[match.start():end]
    return found


def test_required_stored_procedures_exist() -> None:
    assert set(procedures()) == EXPECTED_PROCEDURES


def test_every_stored_procedure_has_standard_session_settings() -> None:
    for name, body in procedures().items():
        upper = body.upper()
        assert "SET NOCOUNT ON" in upper, f"{name} debe usar SET NOCOUNT ON"
        assert "SET XACT_ABORT ON" in upper, f"{name} debe usar SET XACT_ABORT ON"


def test_inventory_writes_are_transactional_and_lock_stock_row() -> None:
    sql = (DATABASE / "07_sp_movimientos.sql").read_text(encoding="utf-8").upper()
    assert sql.count("BEGIN TRAN") == 2
    assert sql.count("COMMIT TRAN") == 2
    assert sql.count("ROLLBACK TRAN") == 2
    assert sql.count("WITH (UPDLOCK, ROWLOCK)") == 2


def test_movement_history_has_no_update_or_delete_procedure() -> None:
    names = set(procedures())
    assert not any(name.startswith("usp_Movimiento_Actualizar") for name in names)
    assert not any(name.startswith("usp_Movimiento_Eliminar") for name in names)


def test_movement_history_uses_inclusive_end_date_predicate() -> None:
    sql = (DATABASE / "07_sp_movimientos.sql").read_text(encoding="utf-8").upper()
    assert "M.FECHAMOVIMIENTO < DATEADD(DAY, 1, @FECHAHASTA)" in sql


def test_dashboard_metrics_are_computed_in_the_dashboard_procedure() -> None:
    sql = (DATABASE / "08_sp_dashboard.sql").read_text(encoding="utf-8").upper()
    for alias in (
        "AS PRODUCTOSACTIVOS", "AS PRODUCTOSSTOCKBAJO", "AS VALORREFERENCIAL",
        "AS TOTALENTRADAS", "AS TOTALSALIDAS", "AS TOTALMOVIMIENTOS",
    ):
        assert alias in sql
    assert "STOCKACTUAL) * PRECIOCOMPRA" in sql


def test_created_movement_procedures_return_the_complete_api_projection() -> None:
    found = procedures()
    required_aliases = (
        "AS PRODUCTOCODIGO",
        "AS PRODUCTONOMBRE",
        "AS USUARIONOMBRE",
        "M.STOCKANTERIOR",
        "M.STOCKPOSTERIOR",
        "M.FECHAREGISTRO",
    )
    for name in ("usp_Movimiento_RegistrarEntrada", "usp_Movimiento_RegistrarSalida"):
        upper = found[name].upper()
        for alias in required_aliases:
            assert alias in upper, f"{name} debe devolver el campo {alias} requerido por MovimientoResponse"
        assert "INNER JOIN DBO.PRODUCTOS" in upper
        assert "INNER JOIN DBO.USUARIOS" in upper


def test_application_database_user_has_execute_without_direct_table_access() -> None:
    sql = (DATABASE / "09_permissions.sql").read_text(encoding="utf-8").upper()
    assert "GRANT EXECUTE ON SCHEMA::DBO" in sql
    assert "DENY SELECT, INSERT, UPDATE, DELETE ON SCHEMA::DBO" in sql
