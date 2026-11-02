# TecnoStock — instalación y configuración de SQL Server 2022 Express, SSMS y ODBC

Esta guía instala el motor SQL Server 2022 directamente en Windows y configura la instancia que requiere TecnoStock. No se usa Docker.

## 1. Componentes: motor, SSMS y ODBC son distintos

| Componente | Para qué sirve | Instalación |
|---|---|---|
| SQL Server 2022 Express — Database Engine | Servicio que almacena y procesa la base de datos | Instalador SQL Server 2022 Express |
| SQL Server Management Studio 22 (SSMS) | Interfaz gráfica para conectarse, ejecutar consultas, administrar tablas, usuarios y backups | WinGet o instalador oficial |
| ODBC Driver 18 (x64) | Controlador que utiliza `pyodbc` para conectar Python con SQL Server | MSI x64 de Microsoft |
| SQL Server Configuration Manager | Configurar servicios y protocolos de red TCP/IP | Se instala con SQL Server |

Instalar SSMS **no instala el motor**. TecnoStock necesita Database Engine Services activo; SSMS es una herramienta de administración y ODBC es el controlador de conexión para el backend.

## 2. Descargar SQL Server 2022 Express

Usa el [Microsoft Download Center — SQL Server 2022 Express](https://www.microsoft.com/es-es/download/details.aspx?id=104781).

1. Descarga `SQLServer2022-SSEI-Expr.exe` desde la página oficial.
2. Ejecuta el archivo como administrador.
3. Selecciona **Custom** para abrir el centro de instalación y tener acceso a la configuración detallada. No elijas una instalación básica si necesitas definir explícitamente nombre de instancia, autenticación y administradores.
4. En SQL Server Installation Center, abre **Installation**.
5. Selecciona **New SQL Server stand-alone installation or add features to an existing installation**.
6. Sigue las comprobaciones de reglas y requisitos previos. Acepta los términos de licencia.
7. En **Feature Selection**, selecciona **Database Engine Services**. Para TecnoStock no necesitas Analysis Services ni Reporting Services.
8. En **Instance Configuration**, elige **Named instance** y escribe exactamente:

   ```text
   SQLEXPRESS
   ```

   Confirma que la ruta de la instancia corresponde a esa instancia nombrada. El servicio resultante debe llamarse `SQL Server (SQLEXPRESS)` y su nombre de servicio de Windows será `MSSQL$SQLEXPRESS`. No elijas `MSSQLSERVER` (instancia predeterminada), porque los scripts de TecnoStock comprueban `SQLEXPRESS`.

9. En **Server Configuration**, conserva la cuenta de servicio recomendada por el instalador, salvo que tengas un requerimiento administrativo distinto.
10. En **Database Engine Configuration → Server Configuration**, selecciona **Mixed Mode (SQL Server authentication and Windows authentication)**.
11. Define una contraseña fuerte para el login integrado `sa`. Guárdala: `setup.ps1` la solicitará para inicializar la base y crear el usuario restringido de la API. No uses una contraseña de ejemplo ni una contraseña vacía.
12. En **SQL Server Administrators**, pulsa **Add Current User**. Verifica que tu cuenta de Windows aparezca en la lista de administradores del motor. Debe quedar al menos un administrador de SQL Server.
13. Revisa la pestaña **Data Directories** si quieres cambiar las carpetas de datos y logs; para la instalación académica puedes conservar las rutas predeterminadas.
14. Revisa el resumen y pulsa **Install**. Comprueba que la instalación finalice correctamente.

Referencias de Microsoft: [instalación mediante el asistente gráfico](https://learn.microsoft.com/es-es/sql/database-engine/install-windows/install-sql-server-from-the-installation-wizard-setup) y [requisitos de SQL Server 2022](https://learn.microsoft.com/en-us/sql/sql-server/install/hardware-and-software-requirements-for-installing-sql-server-2022).

**Importante:** `sa` se usa solo durante la inicialización de la base y el login de aplicación. FastAPI debe conectarse como `tecnostock_app`, no como `sa`.

## 3. Confirmar que el motor está instalado y activo

Abre PowerShell y ejecuta:

```powershell
Get-Service -Name 'MSSQL$SQLEXPRESS'
```

El resultado esperado tiene `Status = Running`. Si el estado es `Stopped`, abre SQL Server Configuration Manager → **SQL Server Services**, clic derecho en **SQL Server (SQLEXPRESS)** y selecciona **Start**.

También puedes abrir el Administrador de configuración de SQL Server 2022 desde PowerShell:

```powershell
Start-Process "$env:windir\SysWOW64\SQLServerManager16.msc"
```

Si el archivo no se encuentra, busca **SQL Server 2022 Configuration Manager** en Inicio. SQL Server Configuration Manager se instala con el motor y su complemento MMC usa `SQLServerManager16.msc` para SQL Server 2022. Referencia: [SQL Server Configuration Manager](https://learn.microsoft.com/en-us/sql/relational-databases/sql-server-configuration-manager?view=sql-server-ver16).

## 4. Comprobar que el puerto 1433 esté libre

Antes de configurar el puerto, verifica que otro proceso no lo esté usando:

```powershell
Get-NetTCPConnection -LocalPort 1433 -State Listen -ErrorAction SilentlyContinue |
    Select-Object LocalAddress, LocalPort, OwningProcess
```

Si aparece un proceso, identifica el propietario antes de decidir qué hacer. No finalices procesos desconocidos para liberar el puerto. Puedes configurar SQL Server en otro puerto libre (por ejemplo, `14330`) y luego poner el mismo valor en `DB_PORT` de los dos archivos `.env`.

## 5. Habilitar TCP/IP para SQLEXPRESS

1. Abre **SQL Server Configuration Manager**.
2. En el panel izquierdo, expande **SQL Server Network Configuration**.
3. Selecciona **Protocols for SQLEXPRESS**.
4. En el panel derecho, haz clic derecho en **TCP/IP** → **Enable**. Deja **Shared Memory** habilitado para conexiones locales; `Named Pipes` no es necesario para esta aplicación.
5. Haz doble clic en **TCP/IP** → abre la pestaña **IP Addresses**.
6. Desplázate hasta **IPAll**.
7. En **TCP Dynamic Ports**, elimina `0` o cualquier valor y deja el campo completamente vacío.
8. En **TCP Port**, escribe `1433`.
9. Si **Listen All** está en `Yes`, los valores de IPAll son los que usa el motor. Conserva `Yes` para la configuración sencilla de desarrollo local.
10. Pulsa **Apply** y **OK**.
11. En el panel izquierdo, selecciona **SQL Server Services**.
12. Clic derecho en **SQL Server (SQLEXPRESS)** → **Restart**.

Si configuraste otro puerto, por ejemplo `14330`, utiliza ese número en **TCP Port** y también en `DB_PORT` de `.env` y `backend/.env`.

Microsoft explica el procedimiento en [Configurar SQL Server para escuchar en un puerto TCP específico](https://learn.microsoft.com/es-es/sql/database-engine/configure-windows/configure-a-server-to-listen-on-a-specific-tcp-port?view=sql-server-ver17). Después de cambiar protocolos o puertos, debes reiniciar el motor para que los cambios surtan efecto.

## 6. Validar el puerto y el servicio desde PowerShell

Para la configuración estándar con puerto 1433:

```powershell
Get-Service -Name 'MSSQL$SQLEXPRESS'
Test-NetConnection -ComputerName localhost -Port 1433
Get-NetTCPConnection -LocalPort 1433 -State Listen -ErrorAction SilentlyContinue
```

Resultados esperados:

- `MSSQL$SQLEXPRESS` debe estar `Running`.
- `TcpTestSucceeded` debe ser `True`.
- Debe aparecer una entrada `Listen` en TCP 1433.

Si `TcpTestSucceeded` es `False`, comprueba que TCP/IP esté habilitado, que el puerto esté escrito en `IPAll`, que el servicio se haya reiniciado y que el puerto no esté ocupado. Para una conexión local desde la misma PC, no es necesario abrir el puerto en el firewall para acceso externo. No abras 1433 a Internet.

## 7. Instalar SQL Server Management Studio 22

SSMS se instala por separado. Desde PowerShell como administrador ejecuta:

```powershell
winget install --id Microsoft.SQLServerManagementStudio.22 --exact --source winget --accept-source-agreements --accept-package-agreements
```

El instalador de SSMS 22 utiliza Visual Studio Installer y puede solicitar elevación de privilegios. Si prefieres la descarga manual, sigue [Instalar SQL Server Management Studio](https://learn.microsoft.com/es-es/ssms/install/install). La opción WinGet está documentada por Microsoft en [Parámetros de línea de comandos para instalar SSMS](https://learn.microsoft.com/es-es/ssms/install/command-line-parameters).

**Recordatorio:** SSMS no es el motor. Si solo instalas SSMS sin Database Engine Services, no habrá ninguna instancia local a la que conectarse.

## 8. Conectarse desde SSMS

Abre SQL Server Management Studio y selecciona **Connect → Database Engine**.

Para conectar explícitamente por TCP al puerto 1433:

| Campo | Valor |
|---|---|
| Server type | `Database Engine` |
| Server name | `tcp:localhost,1433` |
| Authentication | `SQL Server Authentication` |
| Login | `sa` |
| Password | La contraseña que definiste en el instalador |
| Trust server certificate | Activado para este entorno de desarrollo local |

Si se utiliza otro puerto, reemplaza `1433`. También puedes conectar mediante Windows Authentication usando `localhost\SQLEXPRESS` y la cuenta de Windows que agregaste con **Add Current User**. En la ventana de conexión abre **Options → Connection Properties** y activa **Trust server certificate** si SSMS muestra un error de confianza del certificado local.

Una vez conectado, ejecuta esta consulta en **New Query**:

```sql
SELECT
    @@VERSION AS VersionSQLServer,
    SERVERPROPERTY('InstanceName') AS Instancia,
    SERVERPROPERTY('IsIntegratedSecurityOnly') AS SoloAutenticacionWindows;
```

Valores esperados:

- `VersionSQLServer`: debe indicar SQL Server 2022 (16.x).
- `Instancia`: `SQLEXPRESS`.
- `SoloAutenticacionWindows`: `0`, porque está habilitado Mixed Mode.

Si la conexión SQL Server Authentication devuelve error 18456, verifica Mixed Mode, que `sa` esté habilitado y que la contraseña sea correcta. Si Windows Authentication falla, comprueba que tu usuario se haya agregado como administrador de SQL Server durante la instalación.

## 9. Instalar ODBC Driver 18 x64

El backend Python utiliza `pyodbc`; instala el controlador x64 oficial. Desde PowerShell como administrador:

```powershell
$odbcMsi = Join-Path $env:TEMP 'msodbcsql18-x64.msi'
Invoke-WebRequest -Uri 'https://go.microsoft.com/fwlink/?linkid=2378279' -OutFile $odbcMsi
$odbcInstall = Start-Process -FilePath 'msiexec.exe' `
    -ArgumentList "/i `"$odbcMsi`" /qn IACCEPTMSODBCSQLLICENSETERMS=YES" `
    -Wait -PassThru
if ($odbcInstall.ExitCode -notin @(0, 3010)) {
    throw "Falló la instalación de ODBC Driver 18. Código: $($odbcInstall.ExitCode)"
}
if ($odbcInstall.ExitCode -eq 3010) {
    Write-Host 'ODBC instalado; se requiere reiniciar Windows.' -ForegroundColor Yellow
}
Remove-Item $odbcMsi -Force -ErrorAction SilentlyContinue
```

Comprueba la instalación:

```powershell
Get-OdbcDriver -Name 'ODBC Driver 18 for SQL Server' | Format-Table Name, Platform, Attribute
```

Debe aparecer la versión **64-bit**. El enlace oficial puede entregar una versión posterior a la publicada al redactar la guía. Microsoft publica los instaladores actuales y notas de versión en [Descargar ODBC Driver for SQL Server](https://learn.microsoft.com/sql/connect/odbc/download-odbc-driver-for-sql-server). Para ODBC Driver 18.7 o posterior no se requiere preinstalar Visual C++ Redistributable; consulta [requisitos del controlador](https://learn.microsoft.com/sql/connect/odbc/windows/system-requirements-installation-and-driver-files).

## 10. Variables de conexión que utilizará TecnoStock

Tras descargar el proyecto y ejecutar `setup.ps1`, comprueba que los archivos `.env` y `backend/.env` tengan valores equivalentes:

```dotenv
DB_SERVER=localhost
DB_PORT=1433
DB_SERVICE_NAME=MSSQL$SQLEXPRESS
DB_NAME=TecnoStockDB
DB_DRIVER=ODBC Driver 18 for SQL Server
DB_TRUST_SERVER_CERTIFICATE=yes
```

`setup.ps1` solicita la contraseña de `sa` y guarda la configuración local. La contraseña del administrador, el usuario SQL de aplicación y el secreto JWT se generan localmente. No copies los `.env` de otra PC ni los subas a GitHub.

Si el puerto configurado no es 1433, cambia `DB_PORT` en ambos archivos `.env`. Si el servicio tiene otro nombre de instancia, actualiza `DB_SERVICE_NAME` en ambos archivos y en los pasos de verificación del servicio.

## 11. Ejecutar e inicializar TecnoStock

Desde la raíz del repositorio:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\setup.ps1
.\run.ps1
```

`setup.ps1` crea la configuración local y muestra la contraseña inicial de `admin`; guárdala. `run.ps1` crea el entorno virtual Python si falta, instala dependencias del backend, ejecuta `npm ci` cuando corresponde, compila y prueba Angular, verifica SQL Server, inicializa la base y ejecuta el seed y las pruebas backend antes de abrir los servicios.

Direcciones:

- Frontend: http://localhost:4200
- Swagger: http://localhost:8000/docs
- Salud API/BD: http://localhost:8000/health

## 12. Problemas frecuentes

**No existe `MSSQL$SQLEXPRESS`.** El motor no se instaló o tiene otro nombre de instancia. Comprueba Database Engine Services y la opción Named instance en el instalador.

**El servicio no inicia después de configurar TCP/IP.** Revisa el log de errores de SQL Server. Si el evento indica que TCP no puede escuchar en 1433 porque el puerto está ocupado, identifica el proceso con `Get-NetTCPConnection`; no finalices un proceso desconocido. Elige un puerto libre y sincroniza `DB_PORT`.

**SSMS indica que el certificado no es de confianza.** Activa **Trust server certificate** en las propiedades de conexión local. No es un problema de contraseña ni de instalación del motor.

**Error 18456.** Comprueba Mixed Mode, `sa` habilitado y la contraseña introducida. `MSSQL_SA_PASSWORD` en ambos `.env` debe coincidir con la contraseña real del login `sa`.

**ODBC no aparece en `Get-OdbcDriver`.** Verifica que instalaste el MSI x64 y que Python también sea de 64 bits. Cierra y vuelve a abrir PowerShell.

**`TcpTestSucceeded` es falso.** Comprueba TCP/IP Enabled, `IPAll → TCP Dynamic Ports` vacío, el puerto fijo, y reinicia el servicio.

## Referencias oficiales

- [SQL Server 2022 Express — Microsoft Download Center](https://www.microsoft.com/es-es/download/details.aspx?id=104781)
- [Instalación de SQL Server mediante el asistente](https://learn.microsoft.com/es-es/sql/database-engine/install-windows/install-sql-server-from-the-installation-wizard-setup)
- [SQL Server Configuration Manager](https://learn.microsoft.com/en-us/sql/relational-databases/sql-server-configuration-manager?view=sql-server-ver16)
- [Configurar puerto TCP fijo](https://learn.microsoft.com/es-es/sql/database-engine/configure-windows/configure-a-server-to-listen-on-a-specific-tcp-port?view=sql-server-ver17)
- [Instalar SSMS 22](https://learn.microsoft.com/es-es/ssms/install/install)
- [WinGet para SSMS](https://learn.microsoft.com/es-es/ssms/install/command-line-parameters)
- [ODBC Driver 18: descarga](https://learn.microsoft.com/sql/connect/odbc/download-odbc-driver-for-sql-server)
- [ODBC Driver 18: instalación](https://learn.microsoft.com/sql/connect/odbc/windows/system-requirements-installation-and-driver-files)
