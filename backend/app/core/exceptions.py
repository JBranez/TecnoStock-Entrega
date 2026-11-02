"""Excepciones de dominio independientes de HTTP y de SQL Server."""


class AppError(Exception):
    def __init__(self, code: str, message: str, status_code: int = 500) -> None:
        super().__init__(message)
        self.code = code
        self.message = message
        self.status_code = status_code


class NotFoundError(AppError):
    def __init__(self, code: str, message: str) -> None:
        super().__init__(code, message, 404)


class ConflictError(AppError):
    def __init__(self, code: str, message: str) -> None:
        super().__init__(code, message, 409)


class BusinessRuleError(AppError):
    def __init__(self, code: str, message: str) -> None:
        super().__init__(code, message, 422)


class AuthenticationError(AppError):
    def __init__(self, message: str = "Usuario o contraseña incorrectos.") -> None:
        super().__init__("CREDENCIALES_INVALIDAS", message, 401)


class AuthorizationError(AppError):
    def __init__(self, message: str = "No tienes permisos para realizar esta operación.") -> None:
        super().__init__("ACCESO_DENEGADO", message, 403)


class DatabaseUnavailableError(AppError):
    def __init__(self, message: str = "No se pudo conectar con la base de datos.") -> None:
        super().__init__("BASE_DATOS_NO_DISPONIBLE", message, 503)
