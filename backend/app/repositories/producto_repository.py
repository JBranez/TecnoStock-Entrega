"""Acceso al catálogo de productos mediante procedimientos almacenados."""

from __future__ import annotations

from typing import Any

from app.repositories.base_repository import BaseRepository


class ProductoRepository(BaseRepository):
    def list(
        self,
        *,
        search: str | None,
        categoria_id: int | None,
        estado: str,
        page: int,
        page_size: int,
    ) -> tuple[list[dict[str, Any]], int]:
        result_sets = self.execute(
            "dbo.usp_Producto_Listar",
            {
                "Busqueda": search,
                "CategoriaId": categoria_id,
                "Estado": estado,
                "Pagina": page,
                "TamanoPagina": page_size,
            },
        )
        total = int(result_sets[0][0]["total"]) if result_sets and result_sets[0] else 0
        items = result_sets[1] if len(result_sets) > 1 else []
        return items, total

    def get_by_id(self, product_id: int) -> dict[str, Any] | None:
        return self.first("dbo.usp_Producto_ObtenerPorId", {"Id": product_id})

    def create(self, payload: dict[str, Any]) -> dict[str, Any] | None:
        return self.first(
            "dbo.usp_Producto_Crear",
            {
                "Codigo": payload["codigo"],
                "Nombre": payload["nombre"],
                "Descripcion": payload.get("descripcion"),
                "CategoriaId": payload["categoria_id"],
                "PrecioCompra": payload["precio_compra"],
                "PrecioVenta": payload["precio_venta"],
                "StockMinimo": payload["stock_minimo"],
            },
        )

    def update(self, product_id: int, payload: dict[str, Any]) -> dict[str, Any] | None:
        return self.first(
            "dbo.usp_Producto_Actualizar",
            {
                "Id": product_id,
                "Codigo": payload["codigo"],
                "Nombre": payload["nombre"],
                "Descripcion": payload.get("descripcion"),
                "CategoriaId": payload["categoria_id"],
                "PrecioCompra": payload["precio_compra"],
                "PrecioVenta": payload["precio_venta"],
                "StockMinimo": payload["stock_minimo"],
            },
        )

    def change_status(self, product_id: int, active: bool) -> dict[str, Any] | None:
        return self.first(
            "dbo.usp_Producto_CambiarEstado",
            {"Id": product_id, "Activo": active},
        )

    def delete(self, product_id: int) -> dict[str, Any] | None:
        return self.first("dbo.usp_Producto_Eliminar", {"Id": product_id})

    def low_stock(self) -> list[dict[str, Any]]:
        result_sets = self.execute("dbo.usp_Producto_ListarStockBajo")
        return result_sets[0] if result_sets else []
