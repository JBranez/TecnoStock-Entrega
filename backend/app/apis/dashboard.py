from __future__ import annotations

from typing import Any, Annotated

from fastapi import APIRouter, Depends, Query

from app.apis.deps import get_current_user, get_protected_db
from app.repositories.dashboard_repository import DashboardRepository
from app.schemas.dashboard import DashboardFiltros, DashboardResponse
from app.services.dashboard_service import DashboardService

router = APIRouter(prefix="/dashboard", tags=["Dashboard"], dependencies=[Depends(get_current_user)])


def get_dashboard_service(connection: Any = Depends(get_protected_db)) -> DashboardService:
    return DashboardService(DashboardRepository(connection))


@router.get("/indicadores", response_model=DashboardResponse, summary="Obtener indicadores del inventario")
def get_indicators(
    filters: Annotated[DashboardFiltros, Query()],
    service: DashboardService = Depends(get_dashboard_service),
) -> dict[str, Any]:
    return service.get_indicators(date_from=filters.fecha_desde, date_to=filters.fecha_hasta)
