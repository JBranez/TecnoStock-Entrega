from __future__ import annotations

from typing import Any

from fastapi import APIRouter, Depends

from app.apis.deps import get_current_user, get_db
from app.repositories.auth_repository import AuthRepository
from app.schemas.auth import LoginRequest, TokenResponse, UserResponse
from app.services.auth_service import AuthService

router = APIRouter(prefix="/auth", tags=["Autenticación"])


def get_auth_service(connection: Any = Depends(get_db)) -> AuthService:
    return AuthService(AuthRepository(connection))


@router.post("/login", response_model=TokenResponse, summary="Iniciar sesión")
def login(payload: LoginRequest, service: AuthService = Depends(get_auth_service)) -> dict[str, Any]:
    """Autentica las credenciales y devuelve un JWT Bearer."""
    return service.login(username=payload.username, password=payload.password)


@router.get("/me", response_model=UserResponse, summary="Consultar el usuario autenticado")
def me(user: dict[str, Any] = Depends(get_current_user)) -> dict[str, Any]:
    return AuthService.current_user(user)
