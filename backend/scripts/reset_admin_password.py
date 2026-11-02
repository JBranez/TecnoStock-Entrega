"""Restablece la contraseña de una cuenta mediante el SP de usuarios.

Uso desde la raíz del repositorio:
    .\\backend\\.venv\\Scripts\\python.exe .\\backend\\scripts\\reset_admin_password.py

La conexión utiliza DB_APP_USER desde backend/.env. La contraseña se solicita
con getpass, se transforma a Argon2id en Python y solo el hash llega a SQL Server.
"""

from __future__ import annotations

import sys
from pathlib import Path
from getpass import getpass
from typing import Any

BACKEND_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(BACKEND_DIR))

from app.core.config import get_settings  # noqa: E402
from app.core.security import hash_password  # noqa: E402
from app.db.connection import connect_db  # noqa: E402
from app.db.executor import call_procedure  # noqa: E402


def _first_row(result_sets: list[list[dict[str, Any]]]) -> dict[str, Any] | None:
    """Devuelve la primera fila de cualquier result set no vacío."""
    for result_set in result_sets:
        if result_set:
            return result_set[0]
    return None


def main() -> int:
    print("\n=== RESTABLECIMIENTO DE CONTRASEÑA TECNOSTOCK ===\n")
    username = input("Usuario a restablecer [admin]: ").strip() or "admin"
    if not username or len(username) > 50:
        raise ValueError("El usuario debe contener entre 1 y 50 caracteres.")

    password = getpass("Nueva contraseña: ")
    confirmation = getpass("Confirma la contraseña: ")

    if password != confirmation:
        raise ValueError("Las contraseñas no coinciden.")
    if len(password) < 12:
        raise ValueError("La contraseña debe tener al menos 12 caracteres.")

    settings = get_settings()
    connection = connect_db(settings)
    try:
        results = call_procedure(
            connection,
            "dbo.usp_Usuario_ActualizarPassword",
            {
                "Username": username,
                "PasswordHash": hash_password(password),
            },
        )
        row = _first_row(results)
        if row is None:
            raise RuntimeError(
                "El procedimiento no devolvió el usuario actualizado. "
                "Comprueba que el usuario exista y que se ejecutó database/04_sp_usuarios.sql."
            )
        if not bool(row.get("Activo")):
            raise RuntimeError(
                f"La contraseña se actualizó, pero la cuenta '{username}' está desactivada."
            )
        print(f"\nContraseña actualizada correctamente para '{row.get('Username', username)}'.")
        print("La contraseña no se ha mostrado ni guardado en archivos del proyecto.")
        return 0
    finally:
        connection.close()


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        raise SystemExit(1)
