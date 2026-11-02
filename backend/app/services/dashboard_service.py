"""Orquestación de los indicadores principales del inventario."""

from __future__ import annotations

from datetime import date
from typing import Any

from app.core.exceptions import BusinessRuleError
from app.repositories.dashboard_repository import DashboardRepository


class DashboardService:
    def __init__(self, repository: DashboardRepository) -> None:
        self.repository = repository

    def get_indicators(
        self,
        *,
        date_from: date | None = None,
        date_to: date | None = None,
    ) -> dict[str, Any]:
        if date_from and date_to and date_from > date_to:
            raise BusinessRuleError("DATOS_INVALIDOS", "La fecha inicial no puede ser posterior a la fecha final.")
        return self.repository.get_indicators(date_from=date_from, date_to=date_to)
