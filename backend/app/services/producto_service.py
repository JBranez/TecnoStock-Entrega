"""Reglas y orquestación de productos."""

from __future__ import annotations

from decimal import Decimal
from typing import Any

from app.core.exceptions import BusinessRuleError, NotFoundError
from app.repositories.producto_repository import ProductoRepository


class ProductoService:
    def __init__(self, repository: ProductoRepository) -> None:
        self.repository = repository

    def list(
        self,
        *,
        search: str | None,
        categoria_id: int | None,
        estado: str,
        page: int,
        page_size: int,
    ) -> dict[str, Any]:
        items, total = self.repository.list(
            search=search,
            categoria_id=categoria_id,
            estado=estado,
            page=page,
            page_size=page_size,
        )
        return {"items": items, "total": total, "page": page, "page_size": page_size}

    def get(self, product_id: int) -> dict[str, Any]:
        product = self.repository.get_by_id(product_id)
        if product is None:
            raise NotFoundError("PRODUCTO_NO_ENCONTRADO", "El producto solicitado no existe.")
        return product

    @staticmethod
    def _validate_business_fields(payload: dict[str, Any]) -> None:
        for field in ("precio_compra", "precio_venta"):
            value = Decimal(payload[field])
            if value <= 0 or value.as_tuple().exponent < -2:
                raise BusinessRuleError("DATOS_INVALIDOS", "Los precios deben ser mayores que cero y tener máximo dos decimales.")
        if payload["stock_minimo"] < 0:
            raise BusinessRuleError("DATOS_INVALIDOS", "El stock mínimo no puede ser negativo.")

    def create(self, payload: dict[str, Any]) -> dict[str, Any]:
        self._validate_business_fields(payload)
        product = self.repository.create(payload)
        if product is None:
            raise RuntimeError("El procedimiento de creación no devolvió el producto.")
        return product

    def update(self, product_id: int, payload: dict[str, Any]) -> dict[str, Any]:
        self._validate_business_fields(payload)
        self.get(product_id)
        product = self.repository.update(product_id, payload)
        if product is None:
            raise NotFoundError("PRODUCTO_NO_ENCONTRADO", "El producto solicitado no existe.")
        return product

    def change_status(self, product_id: int, active: bool) -> dict[str, Any]:
        product = self.repository.change_status(product_id, active)
        if product is None:
            raise NotFoundError("PRODUCTO_NO_ENCONTRADO", "El producto solicitado no existe.")
        return product

    def delete(self, product_id: int) -> dict[str, Any]:
        result = self.repository.delete(product_id)
        if result is None:
            raise NotFoundError("PRODUCTO_NO_ENCONTRADO", "El producto solicitado no existe.")
        return {"id": product_id, "eliminado": bool(result.get("eliminado", True))}

    def low_stock(self) -> list[dict[str, Any]]:
        return self.repository.low_stock()
