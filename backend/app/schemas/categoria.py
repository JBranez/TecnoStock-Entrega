from __future__ import annotations

from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field, field_validator


class CategoriaCreate(BaseModel):
    nombre: str = Field(min_length=1, max_length=80)
    descripcion: str | None = Field(default=None, max_length=250)

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


class CategoriaUpdate(CategoriaCreate):
    pass


class CategoriaResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    nombre: str
    descripcion: str | None = None
    fecha_creacion: datetime


class CategoriaDeleteResponse(BaseModel):
    id: int
    eliminada: bool
