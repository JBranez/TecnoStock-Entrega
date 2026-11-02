"""Persistencia de usuarios mediante SP."""

from __future__ import annotations

from typing import Any

from app.repositories.base_repository import BaseRepository


class AuthRepository(BaseRepository):
    def get_by_username(self, username: str) -> dict[str, Any] | None:
        return self.first("dbo.usp_Usuario_ObtenerPorUsername", {"Username": username})

    def create(self, *, username: str, full_name: str, password_hash: str) -> dict[str, Any] | None:
        return self.first(
            "dbo.usp_Usuario_Crear",
            {"Username": username, "NombreCompleto": full_name, "PasswordHash": password_hash},
        )
