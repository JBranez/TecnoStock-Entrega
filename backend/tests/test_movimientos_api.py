from __future__ import annotations

from datetime import date, datetime, timedelta

from fastapi.testclient import TestClient

from app.apis.deps import get_current_user
from app.apis.movimientos import get_movimiento_service
from app.core.exceptions import ConflictError
from app.main import app


class FakeMovimientoService:
    def register_entry(self, payload, user_id):
        return self._movement(payload, user_id, "ENTRADA", 0, payload["cantidad"])

    def register_exit(self, payload, user_id):
        if payload["cantidad"] > 10:
            raise ConflictError("STOCK_INSUFICIENTE", "Stock disponible: 10.")
        return self._movement(payload, user_id, "SALIDA", 10, 10 - payload["cantidad"])

    def _movement(self, payload, user_id, movement_type, before, after):
        return {
            "id": 1, "producto_id": payload["producto_id"], "producto_codigo": "LAP-1",
            "producto_nombre": "Laptop", "tipo_movimiento": movement_type, "cantidad": payload["cantidad"],
            "fecha_movimiento": payload["fecha_movimiento"], "motivo": payload["motivo"],
            "stock_anterior": before, "stock_posterior": after, "usuario_id": user_id,
            "usuario_nombre": "Admin", "fecha_registro": datetime(2026, 11, 2),
        }

    def list(self, filters):
        return {"items": [], "total": 0, "page": filters["page"], "page_size": filters["page_size"]}


def setup_overrides() -> None:
    app.dependency_overrides[get_current_user] = lambda: {
        "id": 1, "username": "admin", "nombre_completo": "Administrador"
    }
    app.dependency_overrides[get_movimiento_service] = lambda: FakeMovimientoService()


def body(**changes):
    result = {"producto_id": 1, "cantidad": 10, "fecha_movimiento": date.today().isoformat(), "motivo": "Compra"}
    result.update(changes)
    return result


def test_entry_and_exit_return_stock_before_after() -> None:
    setup_overrides()
    try:
        client = TestClient(app)
        entry = client.post("/api/v1/movimientos/entradas", json=body(), headers={"Authorization": "Bearer fake"})
        exit_movement = client.post("/api/v1/movimientos/salidas", json=body(cantidad=3), headers={"Authorization": "Bearer fake"})
    finally:
        app.dependency_overrides.clear()
    assert entry.status_code == 201
    assert (entry.json()["stock_anterior"], entry.json()["stock_posterior"]) == (0, 10)
    assert exit_movement.status_code == 201
    assert (exit_movement.json()["stock_anterior"], exit_movement.json()["stock_posterior"]) == (10, 7)


def test_exit_insufficient_stock_returns_409() -> None:
    setup_overrides()
    try:
        response = TestClient(app).post(
            "/api/v1/movimientos/salidas", json=body(cantidad=20), headers={"Authorization": "Bearer fake"}
        )
    finally:
        app.dependency_overrides.clear()
    assert response.status_code == 409
    assert response.json()["code"] == "STOCK_INSUFICIENTE"
    assert "10" in response.json()["detail"]


def test_quantity_decimal_zero_and_future_date_are_rejected() -> None:
    setup_overrides()
    try:
        client = TestClient(app)
        decimal = client.post("/api/v1/movimientos/entradas", json=body(cantidad=1.5), headers={"Authorization": "Bearer fake"})
        zero = client.post("/api/v1/movimientos/entradas", json=body(cantidad=0), headers={"Authorization": "Bearer fake"})
        future = client.post(
            "/api/v1/movimientos/entradas",
            json=body(fecha_movimiento=(date.today() + timedelta(days=1)).isoformat()),
            headers={"Authorization": "Bearer fake"},
        )
    finally:
        app.dependency_overrides.clear()
    assert decimal.status_code == 422
    assert zero.status_code == 422
    assert future.status_code == 422


def test_movement_history_filters_and_pagination() -> None:
    setup_overrides()
    try:
        response = TestClient(app).get(
            "/api/v1/movimientos?producto_id=1&fecha_desde=2026-11-01&fecha_hasta=2026-11-02&tipo=ENTRADA&page=2&page_size=5",
            headers={"Authorization": "Bearer fake"},
        )
    finally:
        app.dependency_overrides.clear()
    assert response.status_code == 200
    assert response.json() == {"items": [], "total": 0, "page": 2, "page_size": 5}


def test_movement_history_rejects_inverted_date_range() -> None:
    setup_overrides()
    try:
        response = TestClient(app).get(
            "/api/v1/movimientos?fecha_desde=2026-11-03&fecha_hasta=2026-11-02",
            headers={"Authorization": "Bearer fake"},
        )
    finally:
        app.dependency_overrides.clear()
    assert response.status_code == 422
