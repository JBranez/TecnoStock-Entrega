from __future__ import annotations

from typing import Any

from fastapi import APIRouter, Depends, status

from app.apis.deps import get_current_user, get_protected_db
from app.repositories.categoria_repository import CategoriaRepository
from app.schemas.categoria import CategoriaCreate, CategoriaDeleteResponse, CategoriaResponse, CategoriaUpdate
from app.services.categoria_service import CategoriaService

router = APIRouter(prefix="/categorias", tags=["Categorías"], dependencies=[Depends(get_current_user)])


def get_categoria_service(connection: Any = Depends(get_protected_db)) -> CategoriaService:
    return CategoriaService(CategoriaRepository(connection))


@router.get("", response_model=list[CategoriaResponse], summary="Listar categorías")
def list_categories(service: CategoriaService = Depends(get_categoria_service)) -> list[dict[str, Any]]:
    return service.list()


@router.post("", response_model=CategoriaResponse, status_code=status.HTTP_201_CREATED, summary="Crear categoría")
def create_category(
    payload: CategoriaCreate,
    service: CategoriaService = Depends(get_categoria_service),
) -> dict[str, Any]:
    return service.create(payload.model_dump())


@router.get("/{category_id}", response_model=CategoriaResponse, summary="Obtener categoría")
def get_category(
    category_id: int,
    service: CategoriaService = Depends(get_categoria_service),
) -> dict[str, Any]:
    return service.get(category_id)


@router.put("/{category_id}", response_model=CategoriaResponse, summary="Actualizar categoría")
def update_category(
    category_id: int,
    payload: CategoriaUpdate,
    service: CategoriaService = Depends(get_categoria_service),
) -> dict[str, Any]:
    return service.update(category_id, payload.model_dump())


@router.delete("/{category_id}", response_model=CategoriaDeleteResponse, summary="Eliminar categoría")
def delete_category(
    category_id: int,
    service: CategoriaService = Depends(get_categoria_service),
) -> dict[str, Any]:
    return service.delete(category_id)
