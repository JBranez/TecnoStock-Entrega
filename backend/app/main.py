"""Punto de entrada de la API TecnoStock."""

from __future__ import annotations

import logging

from fastapi import FastAPI, HTTPException, Request
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from app.apis.health import router as health_router
from app.apis.auth import router as auth_router
from app.apis.categorias import router as categorias_router
from app.apis.productos import router as productos_router
from app.apis.movimientos import router as movimientos_router
from app.apis.dashboard import router as dashboard_router
from app.core.config import get_settings
from app.core.exceptions import AppError
from app.core.logging import configure_logging

configure_logging()
logger = logging.getLogger("tecnostock.api")
settings = get_settings()

app = FastAPI(
    title="TecnoStock API",
    description="API del sistema de inventario TecnoStock S.A.C.",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origin_list,
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
    allow_headers=["Authorization", "Content-Type"],
)


@app.middleware("http")
async def disable_api_cache(request: Request, call_next):
    response = await call_next(request)
    if request.method == "GET" and (request.url.path.startswith("/api/") or request.url.path == "/health"):
        response.headers["Cache-Control"] = "no-store, no-cache, must-revalidate, max-age=0"
        response.headers["Pragma"] = "no-cache"
    return response


@app.exception_handler(AppError)
async def app_error_handler(_: Request, exc: AppError) -> JSONResponse:
    return JSONResponse(
        status_code=exc.status_code,
        content={"code": exc.code, "detail": exc.message, "errors": []},
    )


@app.exception_handler(RequestValidationError)
async def validation_error_handler(_: Request, exc: RequestValidationError) -> JSONResponse:
    errors = []
    for error in exc.errors():
        location = [str(part) for part in error.get("loc", ()) if part not in {"body", "query", "path"}]
        field = ".".join(location) or "solicitud"
        error_type = error.get("type", "")
        message = error.get("msg", "El valor ingresado no es válido.")
        if error_type == "missing":
            message = "Este campo es obligatorio."
        elif error_type in {"greater_than", "greater_than_equal"}:
            message = "El valor no cumple el mínimo permitido."
        elif error_type in {"string_too_long", "too_long"}:
            message = "El texto supera la longitud máxima permitida."
        elif error_type in {"string_too_short", "too_short"}:
            message = "El texto es demasiado corto."
        errors.append({"field": field, "message": message})
    return JSONResponse(
        status_code=422,
        content={"code": "DATOS_INVALIDOS", "detail": "Revisa los datos enviados.", "errors": errors},
    )


@app.exception_handler(HTTPException)
async def http_error_handler(_: Request, exc: HTTPException) -> JSONResponse:
    code = "NO_AUTORIZADO" if exc.status_code == 401 else "ERROR_HTTP"
    detail = exc.detail if isinstance(exc.detail, str) else "La solicitud no pudo procesarse."
    return JSONResponse(
        status_code=exc.status_code,
        content={"code": code, "detail": detail, "errors": []},
        headers=exc.headers,
    )


@app.exception_handler(Exception)
async def unexpected_error_handler(_: Request, exc: Exception) -> JSONResponse:
    logger.exception("Error interno no controlado", exc_info=exc)
    return JSONResponse(
        status_code=500,
        content={"code": "ERROR_INTERNO", "detail": "Ocurrió un error interno. Intenta nuevamente.", "errors": []},
    )


app.include_router(health_router)
app.include_router(auth_router, prefix="/api/v1")
app.include_router(categorias_router, prefix="/api/v1")
app.include_router(productos_router, prefix="/api/v1")
app.include_router(movimientos_router, prefix="/api/v1")
app.include_router(dashboard_router, prefix="/api/v1")

