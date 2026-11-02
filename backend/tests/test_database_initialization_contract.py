from __future__ import annotations

from pathlib import Path

DATABASE = Path(__file__).resolve().parents[2] / "database"
ROOT = DATABASE.parent


def test_required_indexes_are_idempotent_and_cover_common_filters() -> None:
    sql = (DATABASE / "03_indexes.sql").read_text(encoding="utf-8").upper()
    for index_name in (
        "IX_PRODUCTOS_NOMBRE",
        "IX_PRODUCTOS_CATEGORIAID",
        "IX_MOVIMIENTOS_PRODUCTO_FECHA",
        "IX_MOVIMIENTOS_FECHA",
    ):
        assert index_name in sql
    assert sql.count("IF NOT EXISTS") == 4


def test_initialization_runs_database_scripts_in_dependency_order() -> None:
    source = (ROOT / "backend" / "scripts" / "init_db.py").read_text(encoding="utf-8")
    expected = [
        "01_create_database.sql", "02_tables.sql", "03_indexes.sql", "04_sp_usuarios.sql",
        "05_sp_categorias.sql", "06_sp_productos.sql", "07_sp_movimientos.sql",
        "08_sp_dashboard.sql", "09_permissions.sql", "10_seed_data.sql",
    ]
    positions = [source.index(f'"{filename}"') for filename in expected]
    assert positions == sorted(positions)
    assert "split_batches(rendered)" in source
    assert "autocommit=True" in source


def test_local_sql_server_is_database_startup_path() -> None:
    run_script = (ROOT / "run.ps1").read_text(encoding="utf-8")
    assert "DB_SERVICE_NAME" in run_script
    assert "Test-NetConnection" in run_script
    assert (ROOT / "docs" / "INSTALACION_SQL_SERVER_LOCAL.md").exists()


def test_env_examples_define_local_sql_instance_and_port() -> None:
    for path in (ROOT / ".env.example", ROOT / "backend" / ".env.example"):
        values = {}
        for line in path.read_text(encoding="utf-8").splitlines():
            if "=" in line and not line.lstrip().startswith("#"):
                key, value = line.split("=", 1)
                values[key.strip()] = value.strip()
        assert values["DB_SERVER"] == "localhost"
        assert values["DB_PORT"] == "1433"
        assert values["DB_SERVICE_NAME"] == "MSSQL$SQLEXPRESS"
