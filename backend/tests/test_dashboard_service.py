from __future__ import annotations

from datetime import date
from decimal import Decimal

import pytest

from app.core.exceptions import BusinessRuleError
from app.services.dashboard_service import DashboardService


class FakeDashboardRepository:
    def get_indicators(self, *, date_from, date_to):
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


def test_dashboard_service_returns_indicators_and_date_range() -> None:
    result = DashboardService(FakeDashboardRepository()).get_indicators(
        date_from=date(2026, 11, 1), date_to=date(2026, 11, 2)
    )
    assert result["productos_activos"] == 15
    assert result["valor_referencial"] == Decimal("12500.50")
    assert result["total_movimientos"] == 18
    assert result["fecha_hasta"] == date(2026, 11, 2)


def test_dashboard_service_rejects_inverted_range() -> None:
    with pytest.raises(BusinessRuleError):
        DashboardService(FakeDashboardRepository()).get_indicators(
            date_from=date(2026, 11, 3), date_to=date(2026, 11, 2)
        )
