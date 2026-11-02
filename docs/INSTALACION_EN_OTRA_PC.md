# TecnoStock — instalación desde GitHub en otra PC (Windows)

Esta guía permite instalar TecnoStock desde un repositorio GitHub público en una computadora Windows limpia. El motor SQL Server, FastAPI y Angular se ejecutan localmente en el mismo equipo. No se utiliza Docker.

> **Repositorio:** [https://github.com/JBranez/TecnoStock-Entrega](https://github.com/JBranez/TecnoStock-Entrega)  
> **Requisito para clonar sin iniciar sesión:** el repositorio debe ser público. La descarga anónima por HTTPS no requiere GitHub CLI ni `gh auth login`.

## 1. Requisitos que deben instalarse antes de `run.ps1`

`run.ps1` no instala estos programas externos: Git, Python, Node.js, ODBC Driver 18, SQL Server ni SSMS. Abre PowerShell **como administrador**. Comprueba que WinGet exista:

```powershell
winget --version
```

Si PowerShell no reconoce `winget`, instala **App Installer** desde Microsoft Store y vuelve a abrir la terminal.

### 1.1 Instalar Git, Python, Node.js, SSMS y ODBC Driver 18

Abre PowerShell **como administrador**. El script comprueba los componentes y omite los que ya están instalados. Si WinGet no está disponible, instala **App Installer** desde Microsoft Store y vuelve a abrir PowerShell.

```powershell
$ErrorActionPreference = 'Stop'

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    throw 'WinGet no está disponible. Instala App Installer desde Microsoft Store y vuelve a abrir PowerShell.'
}

# Git: solo se instala si el comando git no existe.
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    winget install --id Git.Git --exact --source winget --accept-source-agreements --accept-package-agreements
    if ($LASTEXITCODE -ne 0) { throw 'No se pudo instalar Git.' }
} else {
    Write-Host 'Git ya está instalado.' -ForegroundColor Green
}

# Python: exige el launcher py con la versión 3.12.
$python312Ok = $false
if (Get-Command py -ErrorAction SilentlyContinue) {
    py -3.12 --version *> $null
    $python312Ok = ($LASTEXITCODE -eq 0)
}
if (-not $python312Ok) {
    winget install --id Python.Python.3.12 --exact --source winget --accept-source-agreements --accept-package-agreements
    if ($LASTEXITCODE -ne 0) { throw 'No se pudo instalar Python 3.12.' }
} else {
    Write-Host 'Python 3.12 ya está instalado.' -ForegroundColor Green
}

# Node: instala la distribución LTS de WinGet si no existe.
if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    winget install --id OpenJS.NodeJS --exact --source winget --accept-source-agreements --accept-package-agreements
    if ($LASTEXITCODE -ne 0) { throw 'No se pudo instalar Node.js LTS.' }
} else {
    Write-Host ('Node.js detectado: ' + (node --version)) -ForegroundColor Green
}

# SSMS 22: detectar las rutas estándar antes de instalarlo.
$ssmsPaths = @(
    "${env:ProgramFiles(x86)}\Microsoft SQL Server Management Studio 22\Common7\IDE\Ssms.exe",
    "$env:ProgramFiles\Microsoft SQL Server Management Studio 22\Common7\IDE\Ssms.exe"
)
$ssmsInstalled = $false
foreach ($ssmsPath in $ssmsPaths) {
    if (Test-Path $ssmsPath) { $ssmsInstalled = $true; break }
}
if (-not $ssmsInstalled) {
    winget install --id Microsoft.SQLServerManagementStudio.22 --exact --source winget --accept-source-agreements --accept-package-agreements
    if ($LASTEXITCODE -ne 0) { throw 'No se pudo instalar SSMS 22.' }
} else {
    Write-Host 'SSMS 22 ya está instalado.' -ForegroundColor Green
}

# ODBC Driver 18 x64: descargar e instalar solo si no existe la versión x64.
$odbc64 = @()
if (Get-Command Get-OdbcDriver -ErrorAction SilentlyContinue) {
    $odbc64 = @(Get-OdbcDriver -Name 'ODBC Driver 18 for SQL Server' -ErrorAction SilentlyContinue |
        Where-Object { $_.Platform -match '64' })
}
if ($odbc64.Count -eq 0) {
    $odbcMsi = Join-Path $env:TEMP 'msodbcsql18-x64.msi'
    Invoke-WebRequest -Uri 'https://go.microsoft.com/fwlink/?linkid=2378279' -OutFile $odbcMsi
    $odbcInstall = Start-Process -FilePath 'msiexec.exe' `
        -ArgumentList "/i `"$odbcMsi`" /qn IACCEPTMSODBCSQLLICENSETERMS=YES" `
        -Wait -PassThru
    if ($odbcInstall.ExitCode -notin @(0, 3010)) {
        throw "Falló la instalación de ODBC Driver 18. Código: $($odbcInstall.ExitCode)"
    }
    if ($odbcInstall.ExitCode -eq 3010) {
        Write-Host 'ODBC se instaló; Windows solicita reiniciar el equipo.' -ForegroundColor Yellow
    }
    Remove-Item $odbcMsi -Force -ErrorAction SilentlyContinue
} else {
    Write-Host 'ODBC Driver 18 x64 ya está instalado.' -ForegroundColor Green
}

Write-Host 'Requisitos comprobados. Cierra y vuelve a abrir PowerShell antes de verificar PATH.' -ForegroundColor Green
```


Paquetes utilizados:

- `Git.Git`: Git for Windows, necesario para clonar el repositorio.
- `Python.Python.3.12`: Python 3.12 y launcher `py`.
- `OpenJS.NodeJS`: distribución LTS de Node.js; incluye npm.
- `Microsoft.SQLServerManagementStudio.22`: SSMS 22, herramienta cliente para administrar el motor.
- MSI x64 oficial de Microsoft: ODBC Driver 18 para `pyodbc`.

**Compatibilidad Node/Angular:** Angular 22.2.4 admite `^22.22.3 || ^24.15.0 || ^26.0.0`. El bloque instala Node LTS cuando falta; si ya había una versión incompatible, actualízala con `winget upgrade --id OpenJS.NodeJS --exact` o desde [nodejs.org](https://nodejs.org/en/download). Comprueba la tabla oficial en [Angular — Version compatibility](https://angular.dev/reference/versions).

ODBC Driver 18.7.1.1 x64 es la versión GA vigente al preparar esta guía (2 de noviembre de 2026); Microsoft puede actualizar el instalador asociado al enlace permanente. Desde ODBC 18.7 no se requiere preinstalar Visual C++ Redistributable. Fuentes: [descarga oficial](https://learn.microsoft.com/sql/connect/odbc/download-odbc-driver-for-sql-server) y [requisitos](https://learn.microsoft.com/sql/connect/odbc/windows/system-requirements-installation-and-driver-files).

### 1.3 Cerrar y volver a abrir PowerShell; verificar herramientas

```powershell
git --version
py -3.12 --version
node --version
npm --version
Get-OdbcDriver -Name 'ODBC Driver 18 for SQL Server' | Format-Table Name, Platform, Attribute

$nodeVersion = [version]((node --version).TrimStart('v'))
$nodeSupported = (
    ($nodeVersion.Major -eq 22 -and $nodeVersion -ge [version]'22.22.3') -or
    ($nodeVersion.Major -eq 24 -and $nodeVersion -ge [version]'24.15.0') -or
    ($nodeVersion.Major -eq 26 -and $nodeVersion -ge [version]'26.0.0')
)
if (-not $nodeSupported) {
    throw "Node.js $nodeVersion no es compatible con Angular 22. Actualiza Node.js LTS."
}
Write-Host "Node.js $nodeVersion es compatible con Angular 22." -ForegroundColor Green
```

Resultados esperados:

- Git muestra su versión.
- `py -3.12` muestra Python 3.12.x.
- Node cumple uno de los rangos de compatibilidad de Angular 22.
- npm responde con una versión.
- ODBC muestra `ODBC Driver 18 for SQL Server` con plataforma `64-bit`.

`run.ps1` crea `backend/.venv`, instala `requirements-dev.txt`, ejecuta `npm ci` cuando hace falta y utiliza el Angular CLI local del proyecto. No necesitas instalar Angular CLI globalmente ni ejecutar `pip install` o `npm install` manualmente.

## 2. Hacer público el repositorio para permitir la clonación anónima

El propietario debe realizar una sola vez este cambio desde GitHub:

1. Abre [JBranez/TecnoStock-Entrega](https://github.com/JBranez/TecnoStock-Entrega).
2. Entra en **Settings → General**.
3. Desplázate hasta **Danger Zone**.
4. Pulsa **Change repository visibility**.
5. Selecciona **Public**, confirma que es el repositorio correcto y acepta la advertencia.

Guía oficial: [Configurar la visibilidad de un repositorio](https://docs.github.com/es/repositories/managing-your-repositorys-settings-and-features/managing-repository-settings/setting-repository-visibility).

**Antes de hacerlo público:** el código, el historial de commits y los registros de GitHub Actions serán visibles para cualquiera. Verifica que nunca se hayan subido `.env`, `backend/.env`, contraseñas, hashes de claves, tokens o backups. Ejecuta desde una copia local del repositorio:

```powershell
git ls-files .env backend/.env
git log --all --full-history --oneline -- .env backend/.env
git check-ignore -v .env backend/.env
```

Los dos primeros comandos no deben devolver archivos ni commits; el tercero debe confirmar que los `.env` están ignorados. Revisa también manualmente el README, los documentos y el historial para comprobar que no haya secretos escritos en otros archivos. Si algún secreto se versionó anteriormente, no basta con borrarlo del último commit: rota la credencial y elimina el secreto del historial antes de hacer público el repositorio.

## 3. Clonar el repositorio por HTTPS sin iniciar sesión

Cuando GitHub indique que el repositorio es público, abre una ventana nueva de PowerShell y ejecuta:

```powershell
New-Item -ItemType Directory -Path 'C:\Dev' -Force | Out-Null
git clone https://github.com/JBranez/TecnoStock-Entrega.git C:\Dev\TecnoStock
Set-Location C:\Dev\TecnoStock
```

No se requiere `gh auth login`, GitHub CLI, token ni contraseña para clonar o descargar por HTTPS un repositorio público. Si Git solicita credenciales, revisa que la visibilidad ya sea **Public** y que la URL esté escrita exactamente.

Para descargar cambios posteriormente:

```powershell
git pull --ff-only origin main
```

La lectura anónima no permite publicar cambios. Para hacer `git push`, crear PR o administrar el repositorio necesitas autenticarte como colaborador autorizado.

## 4. Instalar SQL Server 2022 Express y configurar SSMS

Instala el motor y configura la instancia **antes** de ejecutar `run.ps1`. Sigue la guía paso a paso: [`INSTALACION_SQL_SERVER_LOCAL.md`](INSTALACION_SQL_SERVER_LOCAL.md).

Resumen de la configuración que espera el proyecto:

- Producto: SQL Server 2022 Express (Database Engine Services).
- Instancia con nombre: `SQLEXPRESS`.
- Autenticación: modo mixto (Windows y SQL Server).
- Cuenta `sa`: contraseña fuerte elegida durante la instalación.
- Tu cuenta de Windows: agregada como administradora de SQL Server.
- TCP/IP habilitado.
- Puerto fijo de `IPAll`: `1433` (si está ocupado, elige otro puerto libre y actualiza `DB_PORT` en los dos `.env`).
- SSMS 22 instalado por separado para administrar y comprobar la conexión.

Comprueba servicio y puerto desde PowerShell (el nombre del servicio lleva `$`, por eso se escribe entre comillas simples):

```powershell
Get-Service -Name 'MSSQL$SQLEXPRESS'
Test-NetConnection -ComputerName localhost -Port 1433
```

El servicio debe estar `Running` y `TcpTestSucceeded` debe ser `True`.

## 5. Crear los archivos `.env` locales

Desde `C:\Dev\TecnoStock`:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\setup.ps1
```

`setup.ps1` solicita la contraseña real de `sa` de esa PC y crea los archivos `.env` y `backend/.env`. También genera la contraseña de `tecnostock_app`, el secreto JWT y las credenciales iniciales de `admin`. Guarda la contraseña de demostración que se muestra al finalizar.

Comprueba que los valores de los dos `.env` coincidan. En la configuración estándar:

```dotenv
DB_SERVER=localhost
DB_PORT=1433
DB_SERVICE_NAME=MSSQL$SQLEXPRESS
DB_NAME=TecnoStockDB
DB_DRIVER=ODBC Driver 18 for SQL Server
DB_TRUST_SERVER_CERTIFICATE=yes
```

`MSSQL_SA_PASSWORD` debe ser la contraseña actual de `sa` en esta PC. No compartas ni versionas ninguno de los archivos `.env`. Si `setup.ps1` informa que ya existen, no los sobrescribe; comprueba manualmente sus variables.

## 6. Ejecutar TecnoStock

Con SQL Server iniciado, los dos `.env` configurados y los requisitos instalados, ejecuta:

```powershell
.\run.ps1
```

El script realiza las siguientes tareas:

1. Comprueba `.env`, Python 3.12, Node.js, npm y ODBC Driver 18.
2. Crea `backend/.venv` si no existe.
3. Instala o verifica las dependencias Python desde `backend/requirements-dev.txt`.
4. Ejecuta `npm ci` si `package.json` o `package-lock.json` cambiaron o faltan `node_modules`.
5. Compila Angular y ejecuta las pruebas frontend.
6. Comprueba el servicio `MSSQL$SQLEXPRESS` y el puerto TCP configurado.
7. Ejecuta `backend/scripts/init_db.py` para crear base, tablas, índices, procedimientos y permisos.
8. Ejecuta `backend/scripts/seed.py` para crear el administrador y los datos demo que falten.
9. Ejecuta `pytest` para el backend.
10. Inicia FastAPI y Angular en ventanas separadas y abre el navegador.

Direcciones:

- Aplicación: <http://localhost:4200>
- Swagger: <http://localhost:8000/docs>
- API: <http://localhost:8000/api/v1>
- Salud: <http://localhost:8000/health>

Cierra las dos ventanas de PowerShell de la API y del frontend para detener la aplicación. SQL Server permanece activo como servicio de Windows.

## 7. Verificar la instalación

1. Abre `http://localhost:8000/health`; confirma que la API y la conexión a base de datos están disponibles.
2. Abre `http://localhost:4200` e inicia sesión con `admin` y la contraseña generada por `setup.ps1`.
3. Entra en Categorías y verifica que se muestren las categorías demo.
4. Registra un producto y una entrada de inventario.
5. Consulta el historial y el dashboard.
6. En SSMS, conecta a `tcp:localhost,1433` y revisa las tablas de `TecnoStockDB`.

## 8. Instalación limpia frente a migración de datos

Una clonación desde GitHub solo descarga el código. `run.ps1` crea una base local nueva y carga datos de demostración. No copia el inventario real de otro equipo.

Para conservar productos, usuarios, existencias y movimientos:

1. En la PC origen, crea un backup **Full** de `TecnoStockDB` desde SSMS (**Databases → TecnoStockDB → Tasks → Back Up**).
2. Copia el archivo `.bak` por un medio seguro a la PC destino.
3. En la PC destino, restaura la base desde SSMS (**Databases → Restore Database → Device**).
4. Ejecuta `setup.ps1` para generar las credenciales locales de la nueva computadora.
5. Ejecuta `database.ps1 -Action init` para instalar o actualizar el esquema y los procedimientos, sin volver a cargar los datos demo.
6. Si la base restaurada ya tiene el usuario de base de datos `tecnostock_app`, vuelve a asociarlo con el login local recién creado y concede los permisos del esquema según `database/09_permissions.sql`.
7. Inicia `run.ps1` y verifica `/health` y el login. El hash de contraseña del administrador que venía en el backup se conserva; `SEED_ADMIN_PASSWORD` no reemplaza la contraseña de un usuario que ya existe.

No ejecutes `database.ps1 -Action all` sobre una base restaurada con datos que quieras conservar: `all` también ejecuta el seed. Consulta [`database/PRUEBAS_MANUALES.md`](../database/PRUEBAS_MANUALES.md) para revisar las operaciones de inventario.

## 9. Problemas frecuentes

| Síntoma | Revisión |
|---|---|
| `py -3.12` no existe | Python 3.12 no está instalado o PowerShell no se ha vuelto a abrir. |
| Node incompatible | Comprueba la versión y actualiza a un rango admitido por Angular 22. |
| No aparece ODBC Driver 18 | Instala el MSI x64 y vuelve a abrir PowerShell. |
| No existe `MSSQL$SQLEXPRESS` | El motor no está instalado como instancia `SQLEXPRESS`; revisa SQL Server Configuration Manager. |
| `TcpTestSucceeded: False` | Servicio detenido, TCP/IP deshabilitado, puerto diferente u ocupado. |
| Error 18456 de `sa` | Comprueba modo mixto, estado habilitado del login y contraseña en ambos `.env`. |
| Error de certificado al conectar con SSMS | En el diálogo de conexión local, activa **Trust server certificate**. |
| `npm ci` falla | Comprueba Node compatible, conexión a Internet y que `frontend/package-lock.json` esté presente. |
| Login admin devuelve 401 | La contraseña del usuario que ya existe en SQL no cambia cuando modificas `SEED_ADMIN_PASSWORD`; sigue la guía `docs/RECUPERAR_ADMIN.md` si está incluida en esa versión. |

## Fuentes oficiales

- [SQL Server 2022 Express — Microsoft Download Center](https://www.microsoft.com/es-es/download/details.aspx?id=104781)
- [Instalar SQL Server desde el asistente](https://learn.microsoft.com/es-es/sql/database-engine/install-windows/install-sql-server-from-the-installation-wizard-setup)
- [SQL Server Configuration Manager](https://learn.microsoft.com/en-us/sql/relational-databases/sql-server-configuration-manager?view=sql-server-ver16)
- [Configurar un puerto TCP fijo](https://learn.microsoft.com/es-es/sql/database-engine/configure-windows/configure-a-server-to-listen-on-a-specific-tcp-port?view=sql-server-ver17)
- [Instalar SSMS 22 con WinGet](https://learn.microsoft.com/es-es/ssms/install/command-line-parameters)
- [ODBC Driver 18: descarga](https://learn.microsoft.com/sql/connect/odbc/download-odbc-driver-for-sql-server)
- [ODBC Driver 18: instalación de MSI](https://learn.microsoft.com/sql/connect/odbc/windows/system-requirements-installation-and-driver-files)
- [Compatibilidad Angular/Node.js](https://angular.dev/reference/versions)
- [Cambiar la visibilidad de un repositorio](https://docs.github.com/es/repositories/managing-your-repositorys-settings-and-features/managing-repository-settings/setting-repository-visibility)
