# Arranque integrado: SQL Server 2022 local + API FastAPI + frontend Angular.
# Compatible con Windows PowerShell 5.1 y PowerShell 7.
$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location -LiteralPath $Root

function Stop-WithMessage([string]$Message) {
    Write-Host "`nERROR: $Message" -ForegroundColor Red
    exit 1
}

function Read-EnvFile([string]$Path) {
    $values = @{}
    foreach ($rawLine in Get-Content -LiteralPath $Path) {
        $line = $rawLine.Trim()
        if (!$line -or $line.StartsWith('#')) { continue }
        $separator = $line.IndexOf('=')
        if ($separator -le 0) { continue }
        $key = $line.Substring(0, $separator).Trim()
        $value = $line.Substring($separator + 1).Trim().Trim('"').Trim("'")
        $values[$key] = $value
    }
    return $values
}

if (!(Test-Path '.env') -or !(Test-Path 'backend/.env')) {
    & (Join-Path $Root 'setup.ps1')
}
if (!(Test-Path '.env') -or !(Test-Path 'backend/.env')) {
    Stop-WithMessage 'No se encontraron .env y backend/.env. Ejecuta .\setup.ps1.'
}

foreach ($envFile in @('.env', 'backend/.env')) {
    $envContent = Get-Content -LiteralPath $envFile -Raw
    if ($envContent -match '(?m)^(MSSQL_SA_PASSWORD|DB_APP_PASSWORD|JWT_SECRET_KEY|SEED_ADMIN_PASSWORD)=(CAMBIAR_|GENERAR_|\s*$)') {
        Stop-WithMessage "El archivo $envFile todavía contiene placeholders. Revisa los valores; no se sobrescribirán credenciales automáticamente."
    }
}

# Se comprueba que ambos archivos .env describan la misma instancia local y las mismas credenciales.
$rootConfig = Read-EnvFile '.env'
$backendConfig = Read-EnvFile 'backend/.env'
$sharedKeys = @(
    'DB_SERVER', 'DB_PORT', 'DB_SERVICE_NAME', 'DB_NAME', 'DB_DRIVER', 'DB_TRUST_SERVER_CERTIFICATE',
    'MSSQL_SA_PASSWORD', 'DB_APP_USER', 'DB_APP_PASSWORD', 'JWT_SECRET_KEY',
    'JWT_ALGORITHM', 'ACCESS_TOKEN_EXPIRE_MINUTES', 'CORS_ORIGINS',
    'SEED_ADMIN_USERNAME', 'SEED_ADMIN_PASSWORD'
)
foreach ($key in $sharedKeys) {
    if (!$rootConfig.ContainsKey($key) -or !$backendConfig.ContainsKey($key)) {
        Stop-WithMessage "Falta la variable $key en .env o backend/.env. Compara ambos archivos con sus .env.example."
    }
    if ($rootConfig[$key] -cne $backendConfig[$key]) {
        Stop-WithMessage "La variable $key no coincide entre .env y backend/.env. Iguala ambos valores sin compartir las contraseñas."
    }
}

if (!(Get-Command py -ErrorAction SilentlyContinue)) { Stop-WithMessage 'Instala Python 3.12 de 64 bits (py -3.12) y vuelve a ejecutar.' }
if (!(Get-Command node -ErrorAction SilentlyContinue) -or !(Get-Command npm -ErrorAction SilentlyContinue)) { Stop-WithMessage 'Instala Node.js compatible con Angular 22.2.4.' }

$pythonOk = (& py -3.12 -c "import sys; print(sys.version_info[:2] == (3, 12))" 2>$null | Out-String).Trim()
if ($pythonOk -ne 'True') { Stop-WithMessage 'Se requiere Python 3.12. Comprueba con: py -3.12 --version.' }
$nodeText = (& node -p "process.versions.node" | Out-String).Trim()
try { $nodeVersion = [version]$nodeText } catch { Stop-WithMessage "No se pudo interpretar la versión de Node: $nodeText." }
$nodeOk = (($nodeVersion.Major -eq 22 -and $nodeVersion -ge [version]'22.22.3') -or ($nodeVersion.Major -eq 24 -and $nodeVersion -ge [version]'24.15.0') -or ($nodeVersion.Major -eq 26 -and $nodeVersion -ge [version]'26.0.0'))
if (!$nodeOk) { Stop-WithMessage "Tu Node es $nodeText. Angular 22 requiere Node 22.22.3+, 24.15.0+ o una versión 26.x." }

$odbc = $false
if (Get-Command Get-OdbcDriver -ErrorAction SilentlyContinue) {
    $odbc = [bool](Get-OdbcDriver -Name 'ODBC Driver 18 for SQL Server' -ErrorAction SilentlyContinue | Where-Object Platform -eq '64-bit')
}
if (!$odbc) { Stop-WithMessage 'Instala Microsoft ODBC Driver 18 for SQL Server (64 bits) antes de ejecutar.' }

$venvPython = Join-Path $Root 'backend/.venv/Scripts/python.exe'
if (!(Test-Path $venvPython)) {
    Write-Host '[1/10] Creando entorno virtual Python…' -ForegroundColor Cyan
    & py -3.12 -m venv (Join-Path $Root 'backend/.venv')
    if ($LASTEXITCODE -ne 0) { Stop-WithMessage 'No se pudo crear backend/.venv.' }
} else {
    Write-Host '[1/10] Entorno virtual Python encontrado.' -ForegroundColor Cyan
}

Write-Host '[2/10] Instalando/verificando dependencias backend…' -ForegroundColor Cyan
& $venvPython -m pip install --disable-pip-version-check -r (Join-Path $Root 'backend/requirements-dev.txt')
if ($LASTEXITCODE -ne 0) { Stop-WithMessage 'No se pudieron instalar las dependencias Python.' }
$odbcCheck = (& $venvPython -c "import pyodbc; print('OK' if 'ODBC Driver 18 for SQL Server' in pyodbc.drivers() else 'MISSING')" 2>$null | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or $odbcCheck -ne 'OK') { Stop-WithMessage 'pyodbc o el ODBC Driver 18 no están disponibles dentro del entorno Python de 64 bits.' }

Write-Host '[3/10] Instalando/verificando Angular…' -ForegroundColor Cyan
Push-Location (Join-Path $Root 'frontend')
try {
    # El marcador compara package.json y package-lock.json. Así reinstala una vez
    # cuando cambian las dependencias o las aprobaciones allowScripts, sin ejecutar
    # npm ci en cada arranque normal.
    $packageJsonHash = (Get-FileHash -LiteralPath 'package.json' -Algorithm SHA256).Hash
    $packageLockHash = (Get-FileHash -LiteralPath 'package-lock.json' -Algorithm SHA256).Hash
    $expectedDependencyState = "$packageJsonHash`n$packageLockHash"
    $dependencyMarker = 'node_modules/.tecnostock-dependencies.sha256'
    $needsNpmInstall = !(Test-Path 'node_modules/.bin/ng.cmd') -or !(Test-Path $dependencyMarker)
    if (!$needsNpmInstall) {
        $installedDependencyState = Get-Content -LiteralPath $dependencyMarker -Raw
        $needsNpmInstall = $installedDependencyState -cne $expectedDependencyState
    }
    if ($needsNpmInstall) {
        Write-Host 'Instalando dependencias según package-lock.json…' -ForegroundColor Yellow
        & npm ci
        if ($LASTEXITCODE -ne 0) { Stop-WithMessage 'npm ci falló. Revisa Node/npm y la conexión a Internet.' }
        if (!(Test-Path 'node_modules/.bin/ng.cmd')) { Stop-WithMessage 'npm ci terminó, pero no se encontró Angular CLI en node_modules/.bin/ng.cmd.' }
        Set-Content -LiteralPath $dependencyMarker -Value $expectedDependencyState -NoNewline -Encoding Ascii
    } else {
        Write-Host 'Dependencias Angular actualizadas; npm ci no es necesario.' -ForegroundColor Green
    }
    Write-Host '[4/10] Compilando Angular…' -ForegroundColor Cyan
    & npm run build
    if ($LASTEXITCODE -ne 0) { Stop-WithMessage 'La compilación Angular falló. No se iniciarán los servicios.' }
    Write-Host '[5/10] Ejecutando pruebas del frontend Angular…' -ForegroundColor Cyan
    & npm test -- --watch=false
    if ($LASTEXITCODE -ne 0) { Stop-WithMessage 'Las pruebas Angular no pasaron; revisa los errores mostrados arriba.' }
} finally { Pop-Location }

Write-Host '[6/10] Comprobando el servicio local de SQL Server…' -ForegroundColor Cyan
$dbServiceName = $backendConfig['DB_SERVICE_NAME']
if ([string]::IsNullOrWhiteSpace($dbServiceName)) { $dbServiceName = 'MSSQL$SQLEXPRESS' }
$dbService = Get-Service -Name $dbServiceName -ErrorAction SilentlyContinue
if (!$dbService) {
    Stop-WithMessage "No se encontró el servicio '$dbServiceName'. Instala SQL Server 2022 Express con instancia SQLEXPRESS o corrige DB_SERVICE_NAME en ambos .env."
}
if ($dbService.Status -ne 'Running') {
    Stop-WithMessage "El servicio '$dbServiceName' está detenido. Inícialo desde SQL Server Configuration Manager o services.msc y vuelve a ejecutar."
}

Write-Host '[7/10] Comprobando el puerto TCP local de SQL Server…' -ForegroundColor Cyan
$dbHost = $backendConfig['DB_SERVER']
if ([string]::IsNullOrWhiteSpace($dbHost)) { $dbHost = 'localhost' }
$dbHost = ($dbHost -split '[,\\]')[0]
$dbPort = 1433
if ($backendConfig['DB_PORT']) { $dbPort = [int]$backendConfig['DB_PORT'] }
$tcpAvailable = Test-NetConnection -ComputerName $dbHost -Port $dbPort -WarningAction SilentlyContinue -InformationLevel Quiet
if (!$tcpAvailable) {
    Stop-WithMessage "No responde SQL Server en $dbHost`:$dbPort. Habilita TCP/IP y configura el puerto fijo $dbPort en SQL Server Configuration Manager; luego reinicia la instancia."
}

Write-Host '[8/10] Inicializando la base de datos y los procedimientos almacenados…' -ForegroundColor Cyan
& $venvPython (Join-Path $Root 'backend/scripts/init_db.py')
if ($LASTEXITCODE -ne 0) { Stop-WithMessage 'Falló la inicialización SQL. Comprueba la contraseña de sa en backend/.env, ODBC Driver 18 y el servicio local.' }

Write-Host '[9/10] Cargando datos demo y ejecutando pruebas backend…' -ForegroundColor Cyan
& $venvPython (Join-Path $Root 'backend/scripts/seed.py')
if ($LASTEXITCODE -ne 0) { Stop-WithMessage 'Falló la carga de datos demo. Comprueba backend/.env y los procedimientos almacenados.' }
& $venvPython -m pytest (Join-Path $Root 'backend/tests') -q
if ($LASTEXITCODE -ne 0) { Stop-WithMessage 'Las pruebas backend no pasaron; no se iniciarán las interfaces.' }

Write-Host '[10/10] Abriendo API y frontend…' -ForegroundColor Cyan
$backendDir = Join-Path $Root 'backend'
$frontendDir = Join-Path $Root 'frontend'
$backendCommand = "Set-Location -LiteralPath '$backendDir'; & '$venvPython' -m uvicorn app.main:app --reload --port 8000"
$frontendCommand = "Set-Location -LiteralPath '$frontendDir'; npm.cmd start"
Start-Process -FilePath 'powershell.exe' -ArgumentList @('-NoExit', '-ExecutionPolicy', 'Bypass', '-Command', $backendCommand)
Start-Sleep -Seconds 3
Start-Process -FilePath 'powershell.exe' -ArgumentList @('-NoExit', '-ExecutionPolicy', 'Bypass', '-Command', $frontendCommand)
Start-Sleep -Seconds 5
Start-Process 'http://localhost:4200'
Write-Host ''
Write-Host 'TecnoStock está iniciando.' -ForegroundColor Green
Write-Host 'Frontend: http://localhost:4200'
Write-Host 'Swagger:  http://localhost:8000/docs'
Write-Host 'Health:   http://localhost:8000/health'
Write-Host 'Cierra las dos ventanas de PowerShell para detener API y Angular. SQL Server permanece como servicio de Windows; puedes detenerlo desde SQL Server Configuration Manager o services.msc.'
