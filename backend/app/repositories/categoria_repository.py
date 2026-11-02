"""Acceso a categorías por procedimientos almacenados."""

from __future__ import annotations

from typing import Any

from app.repositories.base_repository import BaseRepository


class CategoriaRepository(BaseRepository):
    def list(self) -> list[dict[str, Any]]:
        result_sets = self.execute("dbo.usp_Categoria_Listar")
        return result_sets[0] if result_sets else []

    def get_by_id(self, category_id: int) -> dict[str, Any] | None:
        return self.first("dbo.usp_Categoria_ObtenerPorId", {"Id": category_id})

    def create(self, *, nombre: str, descripcion: str | None) -> dict[str, Any] | None:
        return self.first(
            "dbo.usp_Categoria_Crear",
            {"Nombre": nombre, "Descripcion": descripcion},
        )

    def update(self, category_id: int, *, nombre: str, descripcion: str | None) -> dict[str, Any] | None:
        return self.first(
            "dbo.usp_Categoria_Actualizar",
            {"Id": category_id, "Nombre": nombre, "Descripcion": descripcion},
        )

    def delete(self, category_id: int) -> dict[str, Any] | None:
        return self.first("dbo.usp_Categoria_Eliminar", {"Id": category_id})
