"""Orquesta una comprobación de disponibilidad de la base de datos."""

from app.repositories.health_repository import HealthRepository


class HealthService:
    def __init__(self, repository: HealthRepository) -> None:
        self.repository = repository

    def check(self) -> dict[str, str]:
        self.repository.check()
        return {"status": "ok", "database": "ok"}
