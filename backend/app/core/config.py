"""Configuración centralizada de la aplicación desde backend/.env."""

from __future__ import annotations

from functools import lru_cache
from pathlib import Path

from pydantic import Field, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

BACKEND_DIR = Path(__file__).resolve().parents[2]


class Settings(BaseSettings):
    app_env: str = "development"
    db_server: str = "localhost"
    db_port: int = Field(default=1433, ge=1, le=65535)
    db_name: str = "TecnoStockDB"
    db_driver: str = "ODBC Driver 18 for SQL Server"
    db_trust_server_certificate: bool = True
    db_app_user: str = "tecnostock_app"
    db_app_password: str = ""
    mssql_sa_password: str = ""
    jwt_secret_key: str = ""
    jwt_algorithm: str = "HS256"
    access_token_expire_minutes: int = Field(default=60, ge=1, le=1440)
    cors_origins: str = "http://localhost:4200"
    seed_admin_username: str = "admin"
    seed_admin_password: str = ""

    model_config = SettingsConfigDict(
        env_file=BACKEND_DIR / ".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore",
    )

    @field_validator("jwt_secret_key", "db_app_password", "mssql_sa_password", "seed_admin_password", mode="before")
    @classmethod
    def strip_secret(cls, value: object) -> object:
        return value.strip() if isinstance(value, str) else value

    @field_validator("db_server", "db_name", "db_driver", "db_app_user", mode="before")
    @classmethod
    def strip_connection_values(cls, value: object) -> object:
        return value.strip() if isinstance(value, str) else value

    @property
    def cors_origin_list(self) -> list[str]:
        return [origin.strip() for origin in self.cors_origins.split(",") if origin.strip()]

    @property
    def sql_server_address(self) -> str:
        if "\\" in self.db_server:
            return self.db_server
        return f"{self.db_server},{self.db_port}"

    def database_connection_string(self, *, username: str | None = None, password: str | None = None) -> str:
        user = username or self.db_app_user
        secret = self.db_app_password if password is None else password
        safe_password = secret.replace("}", "}}")
        return (
            f"DRIVER={{{self.db_driver}}};SERVER={self.sql_server_address};DATABASE={self.db_name};"
            f"UID={user};PWD={{{safe_password}}};Encrypt=yes;"
            f"TrustServerCertificate={'yes' if self.db_trust_server_certificate else 'no'};"
            "Connection Timeout=10;"
        )


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    return Settings()
