from __future__ import annotations

import re
from datetime import datetime
from decimal import Decimal
from typing import Annotated, Literal

from pydantic import BaseModel, ConfigDict, Field, PlainSerializer, field_validator

Precio = Annotated[Decimal, PlainSerializer(float, return_type=float, when_used="json")]


class ProductoCreate(BaseModel):
    codigo: str = Field(min_length=1, max_length=30, pattern=r"^[A-Z0-9][A-Z0-9._-]*$")
    nombre: str = Field(min_length=1, max_length=120)
    descripcion: str | None = Field(default=None, max_length=500)
    categoria_id: int = Field(gt=0, strict=True)
    precio_compra: Precio = Field(gt=0, max_digits=12, decimal_places=2)
    precio_venta: Precio = Field(gt=0, max_digits=12, decimal_places=2)
    stock_minimo: int = Field(default=0, ge=0, strict=True)

    @field_validator("codigo", mode="before")
    @classmethod
    def normalize_codigo(cls, value: object) -> object:
        return value.strip().upper() if isinstance(value, str) else value

    @field_validator("nombre", mode="before")
    @classmethod
    def normalize_nombre(cls, value: object) -> object:
        return value.strip() if isinstance(value, str) else value

    @field_validator("descripcion", mode="before")
    @classmethod
    def normalize_descripcion(cls, value: object) -> object:
        if isinstance(value, str):
            return value.strip() or None
        return value


class ProductoUpdate(ProductoCreate):
    pass


class ProductoEstadoUpdate(BaseModel):
    activo: bool


class ProductoResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    codigo: str
    nombre: str
    descripcion: str | None = None
    categoria_id: int
    categoria_nombre: str
    precio_compra: Precio
    precio_venta: Precio
    stock_actual: int
    stock_minimo: int
    activo: bool
    fecha_creacion: datetime
    fecha_actualizacion: datetime | None = None


class ProductoListResponse(BaseModel):
    items: list[ProductoResponse]
    total: int
    page: int
    page_size: int


class ProductoDeleteResponse(BaseModel):
    id: int
    eliminado: bool


EstadoProducto = Literal["activos", "inactivos", "todos"]
