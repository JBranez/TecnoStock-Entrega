"""Crea datos de demostración usando únicamente procedimientos almacenados.

Uso: python backend/scripts/seed.py (con el entorno virtual activo).
"""

from __future__ import annotations

import sys
from datetime import date
from decimal import Decimal
from pathlib import Path
from typing import Any

BACKEND_DIR = Path(__file__).resolve().parents[1]
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from app.core.config import get_settings  # noqa: E402
from app.core.security import hash_password  # noqa: E402
from app.db.connection import connect_db  # noqa: E402
from app.db.executor import call_procedure  # noqa: E402

CATEGORIES = [
    ("Laptops", "Equipos portátiles y estaciones móviles."),
    ("Monitores", "Pantallas y monitores para trabajo y entretenimiento."),
    ("Periféricos", "Teclados, mouse, cámaras y accesorios de entrada."),
    ("Almacenamiento", "Unidades SSD, discos y memorias extraíbles."),
    ("Redes", "Routers, switches y adaptadores de conectividad."),
]

PRODUCTS = [
    ("LAP-0142", "Laptop Lenovo ThinkPad E14", "ThinkPad E14, Core i5, 16 GB RAM y SSD 512 GB.", "Laptops", "2650.00", "3199.00", 12, 3),
    ("LAP-0150", "Laptop HP ProBook 440 G10", "Portátil empresarial de 14 pulgadas.", "Laptops", "2480.00", "2999.00", 7, 2),
    ("LAP-0162", "Laptop ASUS VivoBook 15", "Portátil de 15.6 pulgadas para uso general.", "Laptops", "1890.00", "2299.00", 8, 3),
    ("MON-0021", "Monitor Dell P2422H", "Monitor IPS de 24 pulgadas Full HD.", "Monitores", "620.00", "799.00", 9, 3),
    ("MON-0034", "Monitor LG 27MP400", "Monitor IPS de 27 pulgadas Full HD.", "Monitores", "570.00", "729.00", 4, 3),
    ("MON-0040", "Monitor Samsung T350 24", "Monitor de 24 pulgadas con panel IPS.", "Monitores", "490.00", "629.00", 2, 2),
    ("ACC-0088", "Mouse Logitech M185", "Mouse inalámbrico compacto USB.", "Periféricos", "38.00", "59.00", 2, 8),
    ("ACC-0115", "Teclado mecánico Redragon Kumara", "Teclado mecánico compacto retroiluminado.", "Periféricos", "145.00", "189.00", 8, 5),
    ("ACC-0049", "Webcam Logitech C920", "Cámara web Full HD para videoconferencias.", "Periféricos", "245.00", "319.00", 4, 8),
    ("ALM-0031", "SSD Kingston NV2 1 TB", "Unidad NVMe M.2 de 1 TB.", "Almacenamiento", "225.00", "299.00", 3, 10),
    ("ALM-0044", "SSD WD Blue SN580 1 TB", "Unidad NVMe M.2 de 1 TB.", "Almacenamiento", "260.00", "339.00", 8, 5),
    ("ALM-0058", "Memoria USB Kingston 128 GB", "Memoria USB 3.2 de 128 GB.", "Almacenamiento", "24.00", "39.00", 25, 10),
    ("RED-0008", "Router TP-Link Archer AX23", "Router Wi-Fi 6 de doble banda.", "Redes", "185.00", "249.00", 6, 3),
    ("RED-0012", "Switch TP-Link TL-SG108", "Switch Gigabit de 8 puertos.", "Redes", "125.00", "169.00", 3, 3),
    ("RED-0025", "Adaptador TP-Link Archer T3U", "Adaptador inalámbrico USB AC1300.", "Redes", "65.00", "89.00", 8, 5),
]


def result_sets(connection: Any, procedure: str, parameters: dict[str, Any] | None = None) -> list[list[dict[str, Any]]]:
    return call_procedure(connection, procedure, parameters)


def first_row(connection: Any, procedure: str, parameters: dict[str, Any] | None = None) -> dict[str, Any] | None:
    for result_set in result_sets(connection, procedure, parameters):
        if result_set:
            return result_set[0]
    return None


def rows_of_last_set(connection: Any, procedure: str, parameters: dict[str, Any] | None = None) -> list[dict[str, Any]]:
    sets = result_sets(connection, procedure, parameters)
    return sets[-1] if sets else []


def main() -> int:
    if sys.prefix == sys.base_prefix:
        if sys.platform == "win32":
            expected = BACKEND_DIR / ".venv" / "Scripts" / "python.exe"
        else:
            expected = BACKEND_DIR / ".venv" / "bin" / "python"
        raise RuntimeError(
            "Se está usando Python global (" + sys.executable + "). "
            "Ejecuta seed.py con el entorno virtual del proyecto: " + str(expected)
        )
    settings = get_settings()
    if len(settings.seed_admin_password) < 12 or settings.seed_admin_password.startswith("CAMBIAR_"):
        raise RuntimeError("Configura SEED_ADMIN_PASSWORD con al menos 12 caracteres en backend/.env.")

    connection = connect_db(settings)
    try:
        admin = first_row(
            connection,
            "dbo.usp_Usuario_ObtenerPorUsername",
            {"Username": settings.seed_admin_username},
        )
        if admin is None:
            admin = first_row(
                connection,
                "dbo.usp_Usuario_Crear",
                {
                    "Username": settings.seed_admin_username,
                    "NombreCompleto": "Administrador TecnoStock",
                    "PasswordHash": hash_password(settings.seed_admin_password),
                },
            )
            print(f"[OK] Usuario administrador '{settings.seed_admin_username}' creado.")
        else:
            print(f"[OK] Usuario administrador '{settings.seed_admin_username}' ya existe.")

        if admin is None:
            raise RuntimeError("El procedimiento de creación de usuario no devolvió el registro.")
        user_id = int(admin.get("Id", admin.get("id")))

        category_rows = rows_of_last_set(connection, "dbo.usp_Categoria_Listar")
        category_ids = {str(row["Nombre"]): int(row["Id"]) for row in category_rows}
        for name, description in CATEGORIES:
            if name not in category_ids:
                row = first_row(
                    connection,
                    "dbo.usp_Categoria_Crear",
                    {"Nombre": name, "Descripcion": description},
                )
                if row is None:
                    raise RuntimeError(f"No se pudo crear la categoría {name}.")
                category_ids[name] = int(row["Id"])
                print(f"[OK] Categoría creada: {name}")

        existing_products = rows_of_last_set(
            connection,
            "dbo.usp_Producto_Listar",
            {"Busqueda": None, "CategoriaId": None, "Estado": "todos", "Pagina": 1, "TamanoPagina": 100},
        )
        product_ids = {str(row["Codigo"]): int(row["Id"]) for row in existing_products}
        for code, name, description, category, buy, sell, stock, minimum in PRODUCTS:
            if code not in product_ids:
                row = first_row(
                    connection,
                    "dbo.usp_Producto_Crear",
                    {
                        "Codigo": code,
                        "Nombre": name,
                        "Descripcion": description,
                        "CategoriaId": category_ids[category],
                        "PrecioCompra": Decimal(buy),
                        "PrecioVenta": Decimal(sell),
                        "StockMinimo": minimum,
                    },
                )
                if row is None:
                    raise RuntimeError(f"No se pudo crear el producto {code}.")
                product_ids[code] = int(row["Id"])
                print(f"[OK] Producto creado: {code}")

        today = date.today()
        for index, (code, name, _description, _category, _buy, _sell, stock, _minimum) in enumerate(PRODUCTS):
            product_id = product_ids[code]
            sets = result_sets(
                connection,
                "dbo.usp_Movimiento_Listar",
                {
                    "ProductoId": product_id,
                    "FechaDesde": None,
                    "FechaHasta": None,
                    "Tipo": None,
                    "Pagina": 1,
                    "TamanoPagina": 1,
                },
            )
            total = int(sets[0][0]["Total"]) if sets and sets[0] else 0
            if total == 0:
                first_row(
                    connection,
                    "dbo.usp_Movimiento_RegistrarEntrada",
                    {
                        "ProductoId": product_id,
                        "Cantidad": stock,
                        "FechaMovimiento": today,
                        "Motivo": "Stock inicial de demostración",
                        "UsuarioId": user_id,
                    },
                )
                if index == 0:
                    first_row(
                        connection,
                        "dbo.usp_Movimiento_RegistrarSalida",
                        {
                            "ProductoId": product_id,
                            "Cantidad": 2,
                            "FechaMovimiento": today,
                            "Motivo": "Salida de demostración",
                            "UsuarioId": user_id,
                        },
                    )
        print("[OK] Datos demo verificados: 5 categorías, 15 productos y movimientos consistentes.")
        print("[OK] Los productos con existencias bajo el mínimo quedan disponibles para probar las alertas.")
    finally:
        connection.close()
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(f"ERROR al cargar datos demo: {exc}", file=sys.stderr)
        raise SystemExit(1)
