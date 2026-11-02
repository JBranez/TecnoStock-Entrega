from __future__ import annotations

from datetime import date
from decimal import Decimal

from fastapi.testclient import TestClient

from app.apis.dashboard import get_dashboard_service
from app.apis.deps import get_current_user
from app.main import app


class FakeDashboardService:
    def get_indicators(self, *, date_from=None, date_to=None):
        return {
            "productos_activos": 15,
            "productos_stock_bajo": 4,
            "valor_referencial": Decimal("12500.50"),
            "total_entradas": 10,
            "total_salidas": 8,
            "total_movimientos": 18,
            "fecha_desde": date_from,
            "fecha_hasta": date_to,
        }


def setup_overrides() -> None:
    app.dependency_overrides[get_current_user] = lambda: {
        "id": 1, "username": "admin", "nombre_completo": "Administrador"
    }
    app.dependency_overrides[get_dashboard_service] = lambda: FakeDashboardService()


def test_dashboard_indicators_and_decimal_json_number() -> None:
    setup_overrides()
    try:
        response = TestClient(app).get(
            "/api/v1/dashboard/indicadores?fecha_desde=2026-11-01&fecha_hasta=2026-11-02",
            headers={"Authorization": "Bearer fake"},
        )
    finally:
        app.dependency_overrides.clear()
    assert response.status_code == 200
    assert response.json()["valor_referencial"] == 12500.5
    assert response.json()["total_movimientos"] == 18
    assert response.json()["fecha_hasta"] == "2026-11-02"


def test_dashboard_rejects_inverted_dates() -> None:
    setup_overrides()
    try:
        response = TestClient(app).get(
            "/api/v1/dashboard/indicadores?fecha_desde=2026-11-03&fecha_hasta=2026-11-02",
            headers={"Authorization": "Bearer fake"},
        )
    finally:
        app.dependency_overrides.clear()
    assert response.status_code == 422
