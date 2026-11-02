from __future__ import annotations

import pytest

from app.core.exceptions import NotFoundError
from app.services.categoria_service import CategoriaService


class FakeCategoriaRepository:
    def __init__(self, category=None):
        self.category = category
        self.saved = None

    def list(self):
        return [self.category] if self.category else []

    def get_by_id(self, category_id: int):
        return self.category if self.category and self.category["id"] == category_id else None

    def create(self, *, nombre: str, descripcion: str | None):
        self.saved = {"id": 4, "nombre": nombre, "descripcion": descripcion}
        return self.saved

    def update(self, category_id: int, *, nombre: str, descripcion: str | None):
        self.saved = {"id": category_id, "nombre": nombre, "descripcion": descripcion}
        return self.saved

    def delete(self, category_id: int):
        return {"id": category_id, "eliminado": True}


def test_categoria_service_creates_and_updates_categories() -> None:
    repository = FakeCategoriaRepository({"id": 4, "nombre": "Redes"})
    service = CategoriaService(repository)
    created = service.create({"nombre": "Monitores", "descripcion": None})
    updated = service.update(4, {"nombre": "Redes y Wi-Fi", "descripcion": "Conectividad"})
    assert created["nombre"] == "Monitores"
    assert updated["nombre"] == "Redes y Wi-Fi"


def test_categoria_service_returns_not_found_for_unknown_id() -> None:
    service = CategoriaService(FakeCategoriaRepository())
    with pytest.raises(NotFoundError) as raised:
        service.get(999)
    assert raised.value.code == "CATEGORIA_NO_ENCONTRADA"


def test_categoria_service_delete_returns_confirmation() -> None:
    result = CategoriaService(FakeCategoriaRepository()).delete(8)
    assert result == {"id": 8, "eliminada": True}
