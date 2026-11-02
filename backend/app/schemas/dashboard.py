from __future__ import annotations

from datetime import date
from decimal import Decimal
from typing import Annotated

from pydantic import BaseModel, Field, PlainSerializer, model_validator

ValorMonetario = Annotated[Decimal, PlainSerializer(float, return_type=float, when_used="json")]


class DashboardFiltros(BaseModel):
    fecha_desde: date | None = None
    fecha_hasta: date | None = None

    @model_validator(mode="after")
    def date_range_is_valid(self) -> "DashboardFiltros":
        if self.fecha_desde and self.fecha_hasta and self.fecha_desde > self.fecha_hasta:
            raise ValueError("La fecha inicial no puede ser posterior a la fecha final.")
        return self


class DashboardResponse(BaseModel):
    productos_activos: int = Field(ge=0)
    productos_stock_bajo: int = Field(ge=0)
    valor_referencial: ValorMonetario
    total_entradas: int = Field(ge=0)
    total_salidas: int = Field(ge=0)
    total_movimientos: int = Field(ge=0)
    fecha_desde: date | None = None
    fecha_hasta: date | None = None
