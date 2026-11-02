from __future__ import annotations

from pathlib import Path

DATABASE = Path(__file__).resolve().parents[2] / "database"


def test_required_tables_have_identity_primary_keys_and_expected_relations() -> None:
    sql = (DATABASE / "02_tables.sql").read_text(encoding="utf-8").upper()
    for table in ("USUARIOS", "CATEGORIAS", "PRODUCTOS", "MOVIMIENTOSINVENTARIO"):
        start = sql.index(f"CREATE TABLE DBO.{table}")
        end = sql.find("END;", start)
        definition = sql[start:end if end >= 0 else len(sql)]
        assert "ID INT IDENTITY(1,1) NOT NULL" in definition, table
        assert "PRIMARY KEY" in definition, table

    products = sql.split("CREATE TABLE DBO.PRODUCTOS", 1)[1].split("END;", 1)[0]
    movements = sql.split("CREATE TABLE DBO.MOVIMIENTOSINVENTARIO", 1)[1].split("END;", 1)[0]
    assert "UNIQUE (CODIGO)" in products
    assert "FOREIGN KEY (CATEGORIAID) REFERENCES DBO.CATEGORIAS(ID)" in products
    assert "CHECK (PRECIOCOMPRA > 0)" in products
    assert "CHECK (PRECIOVENTA > 0)" in products
    assert "CHECK (STOCKACTUAL >= 0)" in products
    assert "CHECK (STOCKMINIMO >= 0)" in products
    assert "FOREIGN KEY (PRODUCTOID) REFERENCES DBO.PRODUCTOS(ID)" in movements
    assert "FOREIGN KEY (USUARIOID) REFERENCES DBO.USUARIOS(ID)" in movements
    assert "CHECK (CANTIDAD > 0)" in movements
    assert "STOCKPOSTERIOR = STOCKANTERIOR + CANTIDAD" in movements
    assert "STOCKPOSTERIOR = STOCKANTERIOR - CANTIDAD" in movements
    assert "ON DELETE CASCADE" not in sql


def test_category_and_user_unique_keys_and_required_text_constraints_exist() -> None:
    sql = (DATABASE / "02_tables.sql").read_text(encoding="utf-8").upper()
    assert "UNIQUE (USERNAME)" in sql
    assert "UNIQUE (NOMBRE)" in sql
    assert "CK_CATEGORIAS_NOMBRE_NOVACIO" in sql
    assert "CK_USUARIOS_USERNAME_NOVACIO" in sql
    assert "CK_USUARIOS_NOMBRE_NOVACIO" in sql
