from __future__ import annotations

from datetime import date, datetime
from typing import Literal

from pydantic import BaseModel, Field, field_validator, model_validator


class MovimientoCreate(BaseModel):
    producto_id: int = Field(gt=0, strict=True)
    cantidad: int = Field(gt=0, strict=True)
    fecha_movimiento: date
    motivo: str = Field(min_length=1, max_length=200)

    @field_validator("fecha_movimiento")
    @classmethod
    def date_not_in_future(cls, value: date) -> date:
        if value > date.today():
            raise ValueError("La fecha del movimiento no puede ser futura.")
        return value

    @field_validator("motivo", mode="before")
    @classmethod
    def normalize_motivo(cls, value: object) -> object:
        return value.strip() if isinstance(value, str) else value


class MovimientoFiltros(BaseModel):
    producto_id: int | None = Field(default=None, gt=0)
    fecha_desde: date | None = None
    fecha_hasta: date | None = None
    tipo: Literal["ENTRADA", "SALIDA"] | None = None
    page: int = Field(default=1, ge=1)
    page_size: int = Field(default=10, ge=1, le=100)

    @model_validator(mode="after")
    def date_range_is_valid(self) -> "MovimientoFiltros":
        if self.fecha_desde and self.fecha_hasta and self.fecha_desde > self.fecha_hasta:
            raise ValueError("La fecha inicial no puede ser posterior a la fecha final.")
        return self


class MovimientoResponse(BaseModel):
    id: int
    producto_id: int
    producto_codigo: str
    producto_nombre: str
    tipo_movimiento: Literal["ENTRADA", "SALIDA"]
    cantidad: int
    fecha_movimiento: date
    motivo: str
    stock_anterior: int
    stock_posterior: int
    usuario_id: int
    usuario_nombre: str
    fecha_registro: datetime


class MovimientoListResponse(BaseModel):
    items: list[MovimientoResponse]
    total: int
    page: int
    page_size: int
