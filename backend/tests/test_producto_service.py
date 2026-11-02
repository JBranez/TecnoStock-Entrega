from __future__ import annotations

from decimal import Decimal

import pytest

from app.core.exceptions import NotFoundError
from app.services.producto_service import ProductoService


class FakeProductoRepository:
    def __init__(self):
        self.product = {
            "id": 1, "codigo": "LAP-1", "nombre": "Laptop", "precio_compra": Decimal("100.00"),
            "precio_venta": Decimal("120.00"), "categoria_id": 1, "stock_minimo": 2,
        }
        self.saved = None

    def list(self, **filters):
        self.filters = filters
        return [self.product], 1

    def get_by_id(self, product_id):
        return self.product if product_id == 1 else None

    def create(self, payload):
        self.saved = payload
        return {**payload, **self.product}

    def update(self, product_id, payload):
        self.saved = payload
        return {**payload, **self.product}

    def change_status(self, product_id, active):
        return {**self.product, "activo": active}

    def delete(self, product_id):
        return {"id": product_id, "eliminado": True}

    def low_stock(self):
        return [{**self.product, "stock_actual": 1}]


def valid_payload():
    return {
        "codigo": "LAP-1", "nombre": "Laptop", "descripcion": None, "categoria_id": 1,
        "precio_compra": Decimal("100.00"), "precio_venta": Decimal("120.00"), "stock_minimo": 2,
    }


def test_product_list_preserves_filters_and_pagination() -> None:
    repository = FakeProductoRepository()
    result = ProductoService(repository).list(
        search="LAP", categoria_id=1, estado="activos", page=2, page_size=5
    )
    assert result["total"] == 1
    assert result["page"] == 2
    assert repository.filters["search"] == "LAP"


def test_product_service_creates_with_valid_business_values() -> None:
    repository = FakeProductoRepository()
    product = ProductoService(repository).create(valid_payload())
    assert product["codigo"] == "LAP-1"


def test_product_service_rejects_invalid_prices() -> None:
    payload = valid_payload()
    payload["precio_compra"] = Decimal("0")
    with pytest.raises(Exception) as raised:
        ProductoService(FakeProductoRepository()).create(payload)
    assert getattr(raised.value, "code", None) == "DATOS_INVALIDOS"


def test_product_service_404_and_change_state() -> None:
    service = ProductoService(FakeProductoRepository())
    with pytest.raises(NotFoundError):
        service.get(999)
    assert service.change_status(1, False)["activo"] is False


def test_product_service_stock_bajo_and_delete() -> None:
    service = ProductoService(FakeProductoRepository())
    assert service.low_stock()[0]["stock_actual"] == 1
    assert service.delete(1) == {"id": 1, "eliminado": True}
