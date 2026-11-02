"""Traducción de mensajes THROW de SQL Server a errores del dominio."""

from __future__ import annotations

import re
from typing import NoReturn

from app.core.exceptions import BusinessRuleError, ConflictError, NotFoundError

_ERROR_PATTERN = re.compile(r"(?P<code>[A-Z][A-Z0-9_]+)\|(?P<message>[^\r\n]+)")

_NOT_FOUND = {
    "PRODUCTO_NO_ENCONTRADO",
    "CATEGORIA_NO_ENCONTRADA",
    "USUARIO_NO_ENCONTRADO",
}
_CONFLICT = {
    "CODIGO_DUPLICADO",
    "CATEGORIA_DUPLICADA",
    "USUARIO_DUPLICADO",
    "STOCK_INSUFICIENTE",
    "PRODUCTO_INACTIVO",
    "PRODUCTO_CON_MOVIMIENTOS",
    "CATEGORIA_CON_PRODUCTOS",
}
_BUSINESS = {"DATOS_INVALIDOS"}


def parse_database_error_message(error: object) -> tuple[str, str] | None:
    text = str(error)
    match = _ERROR_PATTERN.search(text)
    if not match:
        return None
    message = match.group("message").strip()
    message = re.sub(r"\s*\(SQLExecDirectW\)[\]\)'\" ]*$", "", message, flags=re.IGNORECASE)
    message = re.sub(r"\s*\(\d+\)[\]\)'\" ]*$", "", message)
    message = message.rstrip(" '\"]")
    return match.group("code"), message


def raise_database_error(error: Exception, *, procedure_name: str | None = None) -> NoReturn:
    parsed = parse_database_error_message(error)
    if parsed:
        code, message = parsed
        if code in _NOT_FOUND:
            raise NotFoundError(code, message) from error
        if code in _CONFLICT:
            raise ConflictError(code, message) from error
        if code in _BUSINESS:
            raise BusinessRuleError(code, message) from error

    # Las restricciones UNIQUE cubren las carreras entre dos solicitudes concurrentes.
    message_text = str(error)
    if "2601" in message_text or "2627" in message_text:
        if procedure_name and "Categoria" in procedure_name:
            raise ConflictError("CATEGORIA_DUPLICADA", "Ya existe una categoría con ese nombre.") from error
        if procedure_name and "Usuario" in procedure_name:
            raise ConflictError("USUARIO_DUPLICADO", "El nombre de usuario ya está registrado.") from error
        if procedure_name and "Producto" in procedure_name:
            raise ConflictError("CODIGO_DUPLICADO", "Ya existe un producto con ese código.") from error

    if "547" in message_text and procedure_name and "Categoria_Eliminar" in procedure_name:
        raise ConflictError("CATEGORIA_CON_PRODUCTOS", "No se puede eliminar una categoría que tiene productos asociados.") from error
    raise error
