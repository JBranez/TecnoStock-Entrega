from __future__ import annotations

from typing import Any, Annotated

from fastapi import APIRouter, Depends, Query, status

from app.apis.deps import get_current_user, get_protected_db
from app.repositories.movimiento_repository import MovimientoRepository
from app.schemas.movimiento import MovimientoCreate, MovimientoFiltros, MovimientoListResponse, MovimientoResponse
from app.services.movimiento_service import MovimientoService

router = APIRouter(prefix="/movimientos", tags=["Movimientos"], dependencies=[Depends(get_current_user)])


def get_movimiento_service(connection: Any = Depends(get_protected_db)) -> MovimientoService:
    return MovimientoService(MovimientoRepository(connection))


@router.post("/entradas", response_model=MovimientoResponse, status_code=status.HTTP_201_CREATED, summary="Registrar entrada de inventario")
def register_entry(
    payload: MovimientoCreate,
    user: dict[str, Any] = Depends(get_current_user),
    service: MovimientoService = Depends(get_movimiento_service),
) -> dict[str, Any]:
    return service.register_entry(payload.model_dump(), int(user["id"]))


@router.post("/salidas", response_model=MovimientoResponse, status_code=status.HTTP_201_CREATED, summary="Registrar salida de inventario")
def register_exit(
    payload: MovimientoCreate,
    user: dict[str, Any] = Depends(get_current_user),
    service: MovimientoService = Depends(get_movimiento_service),
) -> dict[str, Any]:
    return service.register_exit(payload.model_dump(), int(user["id"]))


@router.get("", response_model=MovimientoListResponse, summary="Consultar historial de movimientos")
def list_movements(
    filters: Annotated[MovimientoFiltros, Query()],
    service: MovimientoService = Depends(get_movimiento_service),
) -> dict[str, Any]:
    return service.list(filters.model_dump())
