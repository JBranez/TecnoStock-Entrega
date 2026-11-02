from __future__ import annotations

from typing import Any

from fastapi import APIRouter, Depends, Query, status

from app.apis.deps import get_current_user, get_protected_db
from app.repositories.producto_repository import ProductoRepository
from app.schemas.producto import (
    EstadoProducto,
    ProductoCreate,
    ProductoDeleteResponse,
    ProductoEstadoUpdate,
    ProductoListResponse,
    ProductoResponse,
    ProductoUpdate,
)
from app.services.producto_service import ProductoService

router = APIRouter(prefix="/productos", tags=["Productos"], dependencies=[Depends(get_current_user)])


def get_producto_service(connection: Any = Depends(get_protected_db)) -> ProductoService:
    return ProductoService(ProductoRepository(connection))


@router.get("/stock-bajo", response_model=list[ProductoResponse], summary="Listar productos con stock bajo")
def low_stock(service: ProductoService = Depends(get_producto_service)) -> list[dict[str, Any]]:
    return service.low_stock()


@router.get("", response_model=ProductoListResponse, summary="Listar y filtrar productos")
def list_products(
    search: str | None = Query(default=None, max_length=120),
    categoria_id: int | None = Query(default=None, gt=0),
    estado: EstadoProducto = Query(default="activos"),
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=10, ge=1, le=100),
    service: ProductoService = Depends(get_producto_service),
) -> dict[str, Any]:
    return service.list(
        search=search,
        categoria_id=categoria_id,
        estado=estado,
        page=page,
        page_size=page_size,
    )


@router.post("", response_model=ProductoResponse, status_code=status.HTTP_201_CREATED, summary="Registrar producto")
def create_product(
    payload: ProductoCreate,
    service: ProductoService = Depends(get_producto_service),
) -> dict[str, Any]:
    return service.create(payload.model_dump())


@router.get("/{product_id}", response_model=ProductoResponse, summary="Consultar producto")
def get_product(product_id: int, service: ProductoService = Depends(get_producto_service)) -> dict[str, Any]:
    return service.get(product_id)


@router.put("/{product_id}", response_model=ProductoResponse, summary="Actualizar producto")
def update_product(
    product_id: int,
    payload: ProductoUpdate,
    service: ProductoService = Depends(get_producto_service),
) -> dict[str, Any]:
    return service.update(product_id, payload.model_dump())


@router.patch("/{product_id}/estado", response_model=ProductoResponse, summary="Activar o desactivar producto")
def change_product_status(
    product_id: int,
    payload: ProductoEstadoUpdate,
    service: ProductoService = Depends(get_producto_service),
) -> dict[str, Any]:
    return service.change_status(product_id, payload.activo)


@router.delete("/{product_id}", response_model=ProductoDeleteResponse, summary="Eliminar producto sin movimientos")
def delete_product(
    product_id: int,
    service: ProductoService = Depends(get_producto_service),
) -> dict[str, Any]:
    return service.delete(product_id)
