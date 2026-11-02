"""Casos de uso para movimientos. La BD decide el stock definitivo."""

from __future__ import annotations

from datetime import date
from typing import Any

from app.core.exceptions import BusinessRuleError
from app.repositories.movimiento_repository import MovimientoRepository


class MovimientoService:
    def __init__(self, repository: MovimientoRepository) -> None:
        self.repository = repository

    @staticmethod
    def _validate_create(payload: dict[str, Any]) -> None:
        quantity = payload.get("cantidad")
        if isinstance(quantity, bool) or not isinstance(quantity, int) or quantity <= 0:
            raise BusinessRuleError("DATOS_INVALIDOS", "La cantidad debe ser un entero mayor que cero.")
        movement_date = payload.get("fecha_movimiento")
        if movement_date is None or movement_date > date.today():
            raise BusinessRuleError("DATOS_INVALIDOS", "La fecha del movimiento no puede ser futura.")
        reason = payload.get("motivo")
        if not isinstance(reason, str) or not reason.strip() or len(reason.strip()) > 200:
            raise BusinessRuleError("DATOS_INVALIDOS", "El motivo es obligatorio y admite máximo 200 caracteres.")

    def register_entry(self, payload: dict[str, Any], user_id: int) -> dict[str, Any]:
        self._validate_create(payload)
        movement = self.repository.register_entry(
            product_id=payload["producto_id"],
            quantity=payload["cantidad"],
            movement_date=payload["fecha_movimiento"],
            reason=payload["motivo"].strip(),
            user_id=user_id,
        )
        if movement is None:
            raise RuntimeError("El procedimiento de entrada no devolvió el movimiento.")
        return movement

    def register_exit(self, payload: dict[str, Any], user_id: int) -> dict[str, Any]:
        self._validate_create(payload)
        movement = self.repository.register_exit(
            product_id=payload["producto_id"],
            quantity=payload["cantidad"],
            movement_date=payload["fecha_movimiento"],
            reason=payload["motivo"].strip(),
            user_id=user_id,
        )
        if movement is None:
            raise RuntimeError("El procedimiento de salida no devolvió el movimiento.")
        return movement

    def list(self, filters: dict[str, Any]) -> dict[str, Any]:
        date_from = filters.get("fecha_desde")
        date_to = filters.get("fecha_hasta")
        if date_from and date_to and date_from > date_to:
            raise BusinessRuleError("DATOS_INVALIDOS", "La fecha inicial no puede ser posterior a la fecha final.")
        items, total = self.repository.list(
            product_id=filters.get("producto_id"),
            date_from=date_from,
            date_to=date_to,
            movement_type=filters.get("tipo"),
            page=filters["page"],
            page_size=filters["page_size"],
        )
        return {"items": items, "total": total, "page": filters["page"], "page_size": filters["page_size"]}
