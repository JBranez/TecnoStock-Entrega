"""Inicializa TecnoStockDB en la instancia local SQL Server 2022 desde los scripts versionados.

Uso desde la raíz del repositorio: python backend/scripts/init_db.py
Lee las credenciales del login administrativo sa desde backend/.env; nunca las imprime.
"""

from __future__ import annotations

import os
import re
import sys
from pathlib import Path

from sql_utils import replace_sql_placeholders, split_batches

ROOT = Path(__file__).resolve().parents[2]
BACKEND_ENV = ROOT / "backend" / ".env"
ROOT_ENV = ROOT / ".env"
DATABASE_DIR = ROOT / "database"


def load_env_file(path: Path) -> None:
    """Carga variables sencillas KEY=VALUE sin sobrescribir el entorno del proceso."""
    if not path.exists():
        return
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        value = value.strip().strip('"').strip("'")
        os.environ.setdefault(key.strip(), value)


def required_env(name: str) -> str:
    value = os.getenv(name, "").strip()
    if not value or value.startswith("CAMBIAR_") or value.startswith("GENERAR_"):
        raise RuntimeError(f"Configura {name} en backend/.env antes de inicializar la BD.")
    return value


def connection_string(*, database: str, server: str, port: str, driver: str, username: str, password: str, trust: str) -> str:
    server_name = server if "\\" in server or not port else f"{server},{port}"
    safe_password = password.replace("}", "}}")
    return (
        f"DRIVER={{{driver}}};SERVER={server_name};DATABASE={database};"
        f"UID={username};PWD={{{safe_password}}};Encrypt=yes;"
        f"TrustServerCertificate={trust};Connection Timeout=15;"
    )


def execute_script(cursor, script_path: Path, *, db_name: str, app_user: str, app_password: str) -> int:
    source = script_path.read_text(encoding="utf-8-sig")
    rendered = replace_sql_placeholders(
        source,
        db_name=db_name,
        app_user=app_user,
        app_password=app_password,
    )
    count = 0
    for batch in split_batches(rendered):
        cursor.execute(batch)
        count += 1
    return count


def require_project_venv() -> None:
    """Evita ejecutar el inicializador con el Python global sin las dependencias del proyecto."""
    if sys.prefix == sys.base_prefix:
        if os.name == "nt":
            expected = ROOT / "backend" / ".venv" / "Scripts" / "python.exe"
        else:
            expected = ROOT / "backend" / ".venv" / "bin" / "python"
        raise RuntimeError(
            "Se está usando Python global (" + sys.executable + "). "
            "Ejecuta este script con el entorno virtual del proyecto: " + str(expected)
        )


def main() -> int:
    require_project_venv()
    load_env_file(BACKEND_ENV)
    load_env_file(ROOT_ENV)

    try:
        import pyodbc
    except ImportError as exc:
        raise RuntimeError(
            "pyodbc no está instalado en el entorno virtual " + sys.executable + ". "
            "Ejecuta: python -m pip install -r backend/requirements-dev.txt"
        ) from exc

    db_name = os.getenv("DB_NAME", "TecnoStockDB").strip()
    server = os.getenv("DB_SERVER", "localhost").strip()
    port = os.getenv("DB_PORT", "1433").strip()
    driver = os.getenv("DB_DRIVER", "ODBC Driver 18 for SQL Server").strip()
    trust = os.getenv("DB_TRUST_SERVER_CERTIFICATE", "yes").strip().lower()
    if driver not in pyodbc.drivers():
        available = ", ".join(pyodbc.drivers()) or "ninguno"
        raise RuntimeError(
            f"No se encontró '{driver}' en Windows. Controladores ODBC detectados: {available}. "
            "Instala Microsoft ODBC Driver 18 for SQL Server de 64 bits y vuelve a abrir PowerShell."
        )
    sa_password = required_env("MSSQL_SA_PASSWORD")
    app_user = os.getenv("DB_APP_USER", "tecnostock_app").strip()
    app_password = required_env("DB_APP_PASSWORD")

    scripts = [
        "01_create_database.sql",
        "02_tables.sql",
        "03_indexes.sql",
        "04_sp_usuarios.sql",
        "05_sp_categorias.sql",
        "06_sp_productos.sql",
        "07_sp_movimientos.sql",
        "08_sp_dashboard.sql",
        "09_permissions.sql",
        "10_seed_data.sql",
    ]
    conn_master = pyodbc.connect(
        connection_string(
            database="master", server=server, port=port, driver=driver,
            username="sa", password=sa_password, trust=trust,
        ),
        autocommit=True,
    )
    try:
        cursor = conn_master.cursor()
        first = DATABASE_DIR / scripts[0]
        execute_script(cursor, first, db_name=db_name, app_user=app_user, app_password=app_password)
        cursor.close()
    finally:
        conn_master.close()

    conn_db = pyodbc.connect(
        connection_string(
            database=db_name, server=server, port=port, driver=driver,
            username="sa", password=sa_password, trust=trust,
        ),
        autocommit=True,
    )
    try:
        cursor = conn_db.cursor()
        total_batches = 0
        for filename in scripts[1:]:
            total_batches += execute_script(
                cursor,
                DATABASE_DIR / filename,
                db_name=db_name,
                app_user=app_user,
                app_password=app_password,
            )
            print(f"[OK] {filename}")
        cursor.close()
    finally:
        conn_db.close()

    print(f"Base de datos '{db_name}' inicializada correctamente.")
    print(f"Lotes ejecutados después de crear la BD: {total_batches}.")
    print("Siguiente paso: python backend/scripts/seed.py")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:  # el mensaje no contiene contraseñas ni cadenas de conexión
        print(f"ERROR al inicializar la base de datos: {exc}", file=sys.stderr)
        raise SystemExit(1)
