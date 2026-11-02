from __future__ import annotations

from datetime import datetime

from fastapi.testclient import TestClient

from app.apis.categorias import get_categoria_service
from app.apis.deps import get_current_user
from app.core.exceptions import ConflictError
from app.main import app


class FakeCategoriaService:
    def list(self):
        return [{"id": 1, "nombre": "Laptops", "descripcion": "Portátiles", "fecha_creacion": datetime(2026, 1, 1)}]

    def create(self, payload):
        if payload["nombre"] == "Laptops":
            raise ConflictError("CATEGORIA_DUPLICADA", "Ya existe una categoría con ese nombre.")
        return {"id": 2, **payload, "fecha_creacion": datetime(2026, 1, 1)}

    def get(self, category_id):
        if category_id != 1:
            from app.core.exceptions import NotFoundError
            raise NotFoundError("CATEGORIA_NO_ENCONTRADA", "La categoría no existe.")
        return self.list()[0]

    def update(self, category_id, payload):
        return {"id": category_id, **payload, "fecha_creacion": datetime(2026, 1, 1)}

    def delete(self, category_id):
        return {"id": category_id, "eliminada": True}


def setup_overrides() -> None:
    app.dependency_overrides[get_current_user] = lambda: {
        "id": 1, "username": "admin", "nombre_completo": "Administrador"
    }
    app.dependency_overrides[get_categoria_service] = lambda: FakeCategoriaService()


def test_list_and_create_categories() -> None:
    setup_overrides()
    try:
        client = TestClient(app)
        listed = client.get("/api/v1/categorias", headers={"Authorization": "Bearer fake"})
        created = client.post(
            "/api/v1/categorias",
            json={"nombre": "  Monitores  ", "descripcion": "  Pantallas  "},
            headers={"Authorization": "Bearer fake"},
        )
    finally:
        app.dependency_overrides.clear()
    assert listed.status_code == 200
    assert listed.json()[0]["nombre"] == "Laptops"
    assert created.status_code == 201
    assert created.json()["nombre"] == "Monitores"
    assert created.json()["descripcion"] == "Pantallas"


def test_duplicate_category_returns_409() -> None:
    setup_overrides()
    try:
        response = TestClient(app).post(
            "/api/v1/categorias",
            json={"nombre": "Laptops"},
            headers={"Authorization": "Bearer fake"},
        )
    finally:
        app.dependency_overrides.clear()
    assert response.status_code == 409
    assert response.json()["code"] == "CATEGORIA_DUPLICADA"


def test_invalid_category_returns_422_with_field_errors() -> None:
    setup_overrides()
    try:
        response = TestClient(app).post(
            "/api/v1/categorias",
            json={"nombre": "   "},
            headers={"Authorization": "Bearer fake"},
        )
    finally:
        app.dependency_overrides.clear()
    assert response.status_code == 422
    assert response.json()["code"] == "DATOS_INVALIDOS"
    assert response.json()["errors"][0]["field"] == "nombre"
