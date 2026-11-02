# Recuperar la contraseña de un usuario

TecnoStock almacena las contraseñas mediante Argon2id. No es posible recuperar
la contraseña original a partir del hash; se debe establecer una nueva.

## Preparar el procedimiento almacenado

El procedimiento `dbo.usp_Usuario_ActualizarPassword` forma parte de
`database/04_sp_usuarios.sql`. El inicializador ejecuta ese archivo al ejecutar
la inicialización de la base de datos.

Desde PowerShell, en la raíz del repositorio:

```powershell
.\database.ps1 -Action init
```

Esto vuelve a aplicar los scripts de esquema y procedimientos. Es idempotente;
no ejecuta el seed de datos demo.

También se puede verificar desde SSMS:

```sql
USE [TecnoStockDB];
GO
SELECT OBJECT_ID('dbo.usp_Usuario_ActualizarPassword', 'P') AS ProcedimientoId;
GO
```

`ProcedimientoId` debe ser distinto de `NULL`.

## Restablecer la contraseña

El script utiliza `backend/.env`, se conecta con `DB_APP_USER` y solicita la nueva
contraseña de forma oculta. La convierte a Argon2id en Python y envía únicamente
el hash al procedimiento almacenado.

```powershell
.\backend\.venv\Scripts\python.exe .\backend\scripts\reset_admin_password.py
```

Por defecto propone el usuario `admin`; se puede indicar otro usuario existente.
La contraseña debe tener al menos 12 caracteres y se solicita dos veces.

## Seguridad y alcance

- No ejecutar ni versionar `.env` o `backend/.env`.
- No escribir contraseñas en argumentos de línea de comandos ni en logs.
- El script es una herramienta administrativa local; debe ejecutarse solo por
  una persona autorizada que tenga acceso al archivo `backend/.env`.
- El procedimiento solo actualiza `PasswordHash`; no cambia el usuario, su
  estado ni el historial de movimientos.
- No agregar hashes ni contraseñas reales a Git, incidencias o documentación.
