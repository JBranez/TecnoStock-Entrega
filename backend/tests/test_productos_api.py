from __future__ import annotations

from datetime import datetime
from decimal import Decimal

from fastapi.testclient import TestClient

from app.apis.deps import get_current_user
from app.apis.productos import get_producto_service
from app.core.exceptions import ConflictError, NotFoundError
from app.main import app


class FakeProductoService:
    def __init__(self):
        self.product = {
            "id": 4, "codigo": "LAP-004", "nombre": "Laptop prueba", "descripcion": None,
            "categoria_id": 1, "categoria_nombre": "Laptops", "precio_compra": Decimal("2000.00"),
            "precio_venta": Decimal("2500.00"), "stock_actual": 0, "stock_minimo": 2,
            "activo": True, "fecha_creacion": datetime(2026, 1, 1), "fecha_actualizacion": None,
        }

    def list(self, **filters):
        return {"items": [self.product], "total": 1, "page": filters["page"], "page_size": filters["page_size"]}

    def create(self, payload):
        if payload["codigo"] == "LAP-004":
            raise ConflictError("CODIGO_DUPLICADO", "Ya existe un producto con ese código.")
        return {**self.product, **payload}

    def get(self, product_id):
        if product_id != 4:
            raise NotFoundError("PRODUCTO_NO_ENCONTRADO", "El producto solicitado no existe.")
        return self.product

    def update(self, product_id, payload):
        return {**self.product, **payload}

    def change_status(self, product_id, active):
        return {**self.product, "activo": active}

    def delete(self, product_id):
        raise ConflictError("PRODUCTO_CON_MOVIMIENTOS", "El producto tiene historial; desactívalo.")

    def low_stock(self):
        return [self.product]


def setup_overrides() -> None:
    app.dependency_overrides[get_current_user] = lambda: {
        "id": 1, "username": "admin", "nombre_completo": "Administrador"
    }
    app.dependency_overrides[get_producto_service] = lambda: FakeProductoService()


def payload(**changes):
    result = {
        "codigo": "LAP-005", "nombre": "Laptop de prueba", "descripcion": "", "categoria_id": 1,
        "precio_compra": 2000, "precio_venta": 2500, "stock_minimo": 2,
    }
    result.update(changes)
    return result


def test_product_list_and_low_stock_returns_api_data() -> None:
    setup_overrides()
    try:
        client = TestClient(app)
        listed = client.get("/api/v1/productos?search=LAP&page=1&page_size=10", headers={"Authorization": "Bearer fake"})
        low = client.get("/api/v1/productos/stock-bajo", headers={"Authorization": "Bearer fake"})
    finally:
        app.dependency_overrides.clear()
    assert listed.status_code == 200
    assert listed.json()["total"] == 1
    assert listed.json()["items"][0]["precio_compra"] == 2000.0
    assert low.status_code == 200
    assert len(low.json()) == 1


def test_create_product_normalizes_code_and_duplicate_is_409() -> None:
    setup_overrides()
    try:
        client = TestClient(app)
        created = client.post("/api/v1/productos", json=payload(codigo="  lap-006 "), headers={"Authorization": "Bearer fake"})
        duplicate = client.post("/api/v1/productos", json=payload(codigo="LAP-004"), headers={"Authorization": "Bearer fake"})
    finally:
        app.dependency_overrides.clear()
    assert created.status_code == 201
    assert created.json()["codigo"] == "LAP-006"
    assert duplicate.status_code == 409
    assert duplicate.json()["code"] == "CODIGO_DUPLICADO"


def test_product_rejects_zero_price_and_decimal_stock_minimum() -> None:
    setup_overrides()
    try:
        client = TestClient(app)
        zero = client.post("/api/v1/productos", json=payload(precio_compra=0), headers={"Authorization": "Bearer fake"})
        decimal_stock = client.post("/api/v1/productos", json=payload(stock_minimo=1.5), headers={"Authorization": "Bearer fake"})
    finally:
        app.dependency_overrides.clear()
    assert zero.status_code == 422
    assert decimal_stock.status_code == 422


def test_product_not_found_and_physical_delete_conflict() -> None:
    setup_overrides()
    try:
        client = TestClient(app)
        missing = client.get("/api/v1/productos/999", headers={"Authorization": "Bearer fake"})
        rejected = client.delete("/api/v1/productos/4", headers={"Authorization": "Bearer fake"})
    finally:
        app.dependency_overrides.clear()
    assert missing.status_code == 404
    assert rejected.status_code == 409
    assert rejected.json()["code"] == "PRODUCTO_CON_MOVIMIENTOS"
