from __future__ import annotations

from datetime import date, timedelta

import pytest

from app.core.exceptions import BusinessRuleError, ConflictError
from app.services.movimiento_service import MovimientoService


class FakeMovimientoRepository:
    def __init__(self):
        self.stock = 0
        self.movements = []

    def register_entry(self, *, product_id, quantity, movement_date, reason, user_id):
        before = self.stock
        self.stock += quantity
        movement = {
            "id": len(self.movements) + 1, "producto_id": product_id,
            "producto_codigo": "LAP-1", "producto_nombre": "Laptop", "tipo_movimiento": "ENTRADA",
            "cantidad": quantity, "fecha_movimiento": movement_date, "motivo": reason,
            "stock_anterior": before, "stock_posterior": self.stock, "usuario_id": user_id,
            "usuario_nombre": "Admin", "fecha_registro": None,
        }
        self.movements.append(movement)
        return movement

    def register_exit(self, *, product_id, quantity, movement_date, reason, user_id):
        if quantity > self.stock:
            raise ConflictError("STOCK_INSUFICIENTE", f"Stock disponible: {self.stock}.")
        before = self.stock
        self.stock -= quantity
        movement = {
            "id": len(self.movements) + 1, "producto_id": product_id,
            "producto_codigo": "LAP-1", "producto_nombre": "Laptop", "tipo_movimiento": "SALIDA",
            "cantidad": quantity, "fecha_movimiento": movement_date, "motivo": reason,
            "stock_anterior": before, "stock_posterior": self.stock, "usuario_id": user_id,
            "usuario_nombre": "Admin", "fecha_registro": None,
        }
        self.movements.append(movement)
        return movement

    def list(self, **filters):
        return self.movements, len(self.movements)


def payload(quantity=10):
    return {"producto_id": 1, "cantidad": quantity, "fecha_movimiento": date.today(), "motivo": "Compra"}


def test_movement_service_updates_stock_and_returns_before_after() -> None:
    repository = FakeMovimientoRepository()
    service = MovimientoService(repository)
    entry = service.register_entry(payload(10), user_id=7)
    exit_movement = service.register_exit(payload(3), user_id=7)
    assert (entry["stock_anterior"], entry["stock_posterior"]) == (0, 10)
    assert (exit_movement["stock_anterior"], exit_movement["stock_posterior"]) == (10, 7)
    assert repository.stock == 7


def test_movement_service_rejects_zero_negative_decimal_and_boolean() -> None:
    service = MovimientoService(FakeMovimientoRepository())
    for quantity in (0, -1, 1.5, True):
        with pytest.raises(BusinessRuleError):
            service.register_entry(payload(quantity), user_id=1)


def test_movement_service_rejects_future_date_and_blank_reason() -> None:
    service = MovimientoService(FakeMovimientoRepository())
    future = payload(1)
    future["fecha_movimiento"] = date.today() + timedelta(days=1)
    with pytest.raises(BusinessRuleError):
        service.register_entry(future, user_id=1)
    blank_reason = payload(1)
    blank_reason["motivo"] = "   "
    with pytest.raises(BusinessRuleError):
        service.register_entry(blank_reason, user_id=1)


def test_movement_service_does_not_let_exit_exceed_stock() -> None:
    repository = FakeMovimientoRepository()
    service = MovimientoService(repository)
    service.register_entry(payload(10), user_id=1)
    with pytest.raises(ConflictError) as raised:
        service.register_exit(payload(20), user_id=1)
    assert raised.value.code == "STOCK_INSUFICIENTE"
    assert repository.stock == 10
    assert len(repository.movements) == 1


def test_movement_list_returns_pagination_metadata() -> None:
    service = MovimientoService(FakeMovimientoRepository())
    result = service.list({"producto_id": 1, "fecha_desde": None, "fecha_hasta": None,
                           "tipo": "ENTRADA", "page": 1, "page_size": 10})
    assert result["total"] == 0
    assert result["page_size"] == 10
