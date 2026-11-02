from __future__ import annotations

from typing import Any

from fastapi import APIRouter, Depends

from app.apis.deps import get_db
from app.repositories.health_repository import HealthRepository
from app.services.health_service import HealthService

router = APIRouter(tags=["Salud"])


def get_health_service(connection: Any = Depends(get_db)) -> HealthService:
    return HealthService(HealthRepository(connection))


@router.get("/health", summary="Comprobar la API y la base de datos")
def health(service: HealthService = Depends(get_health_service)) -> dict[str, str]:
    """Comprueba conectividad mediante un procedimiento almacenado permitido."""
    return service.check()
