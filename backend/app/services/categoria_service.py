"""Reglas y orquestación del catálogo de categorías."""

from __future__ import annotations

from typing import Any

from app.core.exceptions import NotFoundError
from app.repositories.categoria_repository import CategoriaRepository


class CategoriaService:
    def __init__(self, repository: CategoriaRepository) -> None:
        self.repository = repository

    def list(self) -> list[dict[str, Any]]:
        return self.repository.list()

    def get(self, category_id: int) -> dict[str, Any]:
        category = self.repository.get_by_id(category_id)
        if category is None:
            raise NotFoundError("CATEGORIA_NO_ENCONTRADA", "La categoría solicitada no existe.")
        return category

    def create(self, payload: dict[str, Any]) -> dict[str, Any]:
        category = self.repository.create(nombre=payload["nombre"], descripcion=payload.get("descripcion"))
        if category is None:
            raise RuntimeError("El procedimiento de creación no devolvió la categoría.")
        return category

    def update(self, category_id: int, payload: dict[str, Any]) -> dict[str, Any]:
        self.get(category_id)
        category = self.repository.update(
            category_id,
            nombre=payload["nombre"],
            descripcion=payload.get("descripcion"),
        )
        if category is None:
            raise NotFoundError("CATEGORIA_NO_ENCONTRADA", "La categoría solicitada no existe.")
        return category

    def delete(self, category_id: int) -> dict[str, Any]:
        result = self.repository.delete(category_id)
        if result is None:
            raise NotFoundError("CATEGORIA_NO_ENCONTRADA", "La categoría solicitada no existe.")
        return {"id": category_id, "eliminada": bool(result.get("eliminado", True))}
