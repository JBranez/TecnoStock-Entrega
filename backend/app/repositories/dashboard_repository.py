"""Consultas de indicadores ejecutadas exclusivamente en SQL Server mediante SP."""

from __future__ import annotations

from datetime import date
from typing import Any

from app.repositories.base_repository import BaseRepository


class DashboardRepository(BaseRepository):
    def get_indicators(
        self,
        *,
        date_from: date | None,
        date_to: date | None,
    ) -> dict[str, Any]:
        row = self.first(
            "dbo.usp_Dashboard_ObtenerIndicadores",
            {"FechaDesde": date_from, "FechaHasta": date_to},
        )
        if row is None:
            raise RuntimeError("El procedimiento de indicadores no devolvió datos.")
        return row
