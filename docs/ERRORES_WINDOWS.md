# Diagnóstico y correcciones de instalación en Windows

Este documento registra los problemas observados al montar TecnoStock en Windows y cómo resolverlos sin exponer credenciales ni modificar datos de la instancia local.

## 1. Errores de compilación Angular 22.2.4

Los errores `TS2322`, `TS2349`, `NG8022` y `TS2304` del registro se corrigieron en el código fuente:

- **`TS2322` en `<app-field-error>`:** `errors()` de Signal Forms devuelve errores `WithFieldTree`; la propiedad `message` es opcional (`string | undefined`). El componente compartido acepta ahora ese contrato y solo renderiza el mensaje cuando existe.
- **`TS2349` en `ProductosPage.confirmAction()`:** `delete()` y `changeStatus()` devolvían Observables de tipos distintos. Ambos resultados se normalizan con RxJS `map(() => void 0)` antes de llamar a `subscribe()`.
- **`NG8022` en inputs numéricos:** se retiraron los atributos HTML estáticos `min`. Los límites se declaran mediante los validadores `min()` de Signal Forms, que también publican la restricción al control nativo.
- **`TS2304` en `MovimientosPage`:** se incorporó el import explícito de `firstValueFrom` desde `rxjs`.
- **`NG8113` en `MovimientosPage`:** se retiró `DatePipe` de los imports del componente porque su plantilla no lo utiliza.

La documentación oficial de Signal Forms confirma que el mensaje de validación es opcional y que `min()` es el validador que expone el límite al control asociado.

Después de actualizar el proyecto, el `run.ps1` actualizado detecta los cambios en `package.json` y `package-lock.json` mediante un marcador dentro de `node_modules`; por ello ejecuta `npm ci` automáticamente una sola vez. Si prefieres hacerlo manualmente, usa:

```powershell
Set-Location C:\Dev\TecnoStock\frontend
Remove-Item -Recurse -Force node_modules -ErrorAction SilentlyContinue
npm ci
npm run build
npm test -- --watch=false
Set-Location ..
```

El `package.json` autoriza por versión exacta los cuatro scripts de instalación que npm 11 reportó (`@parcel/watcher`, `esbuild`, `lmdb` y `msgpackr-extract`). Son dependencias del árbol de Angular resueltas por el lockfile. No se utiliza `--dangerously-allow-all-scripts`.

## 2. `init_db.py` dice que falta pyodbc

El registro instaló `pyodbc` dentro de `backend/.venv`, pero después ejecutó:

```powershell
py -3.12 backend/scripts/init_db.py
```

`py -3.12` selecciona el Python global 3.12 aunque el prompt muestre `(.venv)`. Por eso el intérprete global no encontró el paquete instalado en el entorno virtual.

Usa el ejecutable exacto del entorno virtual:

```powershell
.\backend\.venv\Scripts\python.exe .\backend\scripts\init_db.py
.\backend\.venv\Scripts\python.exe .\backend\scripts\seed.py
```

O ejecuta ambos correctamente con el ayudante incluido:

```powershell
.\database.ps1 -Action all
```

El inicializador ahora detecta el uso de Python global y muestra la ruta del intérprete correcto. También comprueba que ODBC Driver 18 esté registrado en Windows.

## 3. El comando `seed.py` termina con `Invalid argument`

En el registro aparece un carácter de control `^F` al final de `seed.py`. No forma parte del nombre del archivo: se introdujo al pegar/escribir el comando. Vuelve a escribirlo sin caracteres adicionales o utiliza `database.ps1`.

## 4. Mensaje de `setup.ps1` sobre los archivos `.env`

El mensaje `Los dos archivos .env ya existen. No se sobrescribirán tus credenciales.` es informativo, no un error. El script conserva intencionalmente los secretos locales.

Los dos archivos `.env` contienen la misma configuración: el archivo de la raíz conserva los valores compartidos y FastAPI lee `backend/.env`. `run.ps1` comprueba que ambas copias coincidan. Si informa una diferencia, iguala manualmente la variable indicada sin publicar ni compartir el valor.

## 5. SQL Server local no responde en `localhost:1433`

El proyecto utiliza SQL Server 2022 Express instalado como servicio de Windows. Comprueba el estado de la instancia y el puerto:

```powershell
Get-Service 'MSSQL$SQLEXPRESS'
Test-NetConnection -ComputerName localhost -Port 1433
```

- Si el servicio no existe, verifica que el motor Database Engine Services esté instalado y que la instancia se llame `SQLEXPRESS`.
- Si el servicio está detenido, inícialo desde SQL Server Configuration Manager o `services.msc`.
- Si `TcpTestSucceeded` es `False`, activa TCP/IP en **SQL Server Network Configuration → Protocols for SQLEXPRESS**, fija el puerto `1433` en `IPAll` (con `TCP Dynamic Ports` vacío) y reinicia SQL Server (SQLEXPRESS).
- Si otra instancia ocupa `1433`, selecciona un puerto libre como `14330` y actualiza `DB_PORT` tanto en `.env` como en `backend/.env`.

## 6. Error de inicio de sesión `sa` (SQL Server 18456)

El inicializador usa `sa` solo para crear la base de datos y el login restringido de la API. Verifica en SSMS que la instancia esté en **Mixed Mode**, que `sa` esté habilitado y que `MSSQL_SA_PASSWORD` en ambos `.env` coincida con la contraseña real configurada durante la instalación. Si ya existían `.env` de una configuración anterior, `setup.ps1` no reemplaza secretos: debes corregir esa variable manualmente. FastAPI utiliza `tecnostock_app`, nunca `sa`.

## 7. Error `IM002` o ausencia de ODBC Driver 18

Instala Microsoft ODBC Driver 18 for SQL Server en su versión x64 y abre una nueva terminal. Comprueba:

```powershell
Get-OdbcDriver -Name 'ODBC Driver 18 for SQL Server'
```

El backend usa Python de 64 bits; el driver debe estar registrado para esa arquitectura.

## 8. Arranque recomendado después de corregir el entorno

Desde la raíz del repositorio:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
.\run.ps1
```

`run.ps1` usa explícitamente `backend/.venv/Scripts/python.exe` para `init_db.py`, `seed.py` y pytest. También comprueba la coherencia de los dos `.env`, pyodbc/ODBC Driver, el servicio local de SQL Server, la conexión TCP y la compilación y pruebas Angular antes de abrir las ventanas de los servicios.

## 9. Qué se verificó en esta corrección

- `python -m compileall -q backend/app backend/scripts`: correcto.
- `python -m pytest backend/tests -q`: 76 pruebas aprobadas.
- El arreglo estático del frontend cubre los errores concretos reportados en el registro. En este entorno no se pudo repetir `ng build` porque el entorno de trabajo no dispone de Node 26.13 ni puede descargar paquetes desde npm; después de instalar el ZIP actualizado, el comando `npm run build` del paso 1 es la verificación definitiva en el mismo Windows/Node del registro.
- La conexión real a SQL Server debe validarse en Windows con el servicio local, ODBC Driver 18 y los datos de acceso configurados.

## Referencias oficiales

- Angular Signal Forms — tipo `ValidationError`: https://angular.dev/api/forms/signals/ValidationError
- Angular Signal Forms — validación nativa y restricciones reflejadas: https://angular.dev/guide/forms/signals/validation#native-html-validation
- npm 11 — autorización de scripts de instalación (`allowScripts`): https://docs.npmjs.com/cli/v11/commands/npm-install-scripts/
- SQL Server — configurar puerto TCP: https://learn.microsoft.com/es-es/sql/database-engine/configure-windows/configure-a-server-to-listen-on-a-specific-tcp-port?view=sql-server-ver17
- SQL Server — habilitar protocolos de red: https://learn.microsoft.com/en-us/sql/database-engine/configure-windows/enable-or-disable-a-server-network-protocol?view=sql-server-ver16
