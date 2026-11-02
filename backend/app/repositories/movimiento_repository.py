"""Persistencia de entradas, salidas e historial mediante SP."""

from __future__ import annotations

from typing import Any

from app.repositories.base_repository import BaseRepository


class MovimientoRepository(BaseRepository):
    def register_entry(self, *, product_id: int, quantity: int, movement_date, reason: str, user_id: int) -> dict[str, Any] | None:
        return self.first(
            "dbo.usp_Movimiento_RegistrarEntrada",
            {
                "ProductoId": product_id,
                "Cantidad": quantity,
                "FechaMovimiento": movement_date,
                "Motivo": reason,
                "UsuarioId": user_id,
            },
        )

    def register_exit(self, *, product_id: int, quantity: int, movement_date, reason: str, user_id: int) -> dict[str, Any] | None:
        return self.first(
            "dbo.usp_Movimiento_RegistrarSalida",
            {
                "ProductoId": product_id,
                "Cantidad": quantity,
                "FechaMovimiento": movement_date,
                "Motivo": reason,
                "UsuarioId": user_id,
            },
        )

    def list(
        self,
        *,
        product_id: int | None,
        date_from,
        date_to,
        movement_type: str | None,
        page: int,
        page_size: int,
    ) -> tuple[list[dict[str, Any]], int]:
        result_sets = self.execute(
            "dbo.usp_Movimiento_Listar",
            {
                "ProductoId": product_id,
                "FechaDesde": date_from,
                "FechaHasta": date_to,
                "Tipo": movement_type,
                "Pagina": page,
                "TamanoPagina": page_size,
            },
        )
        total = int(result_sets[0][0]["total"]) if result_sets and result_sets[0] else 0
        items = result_sets[1] if len(result_sets) > 1 else []
        return items, total
