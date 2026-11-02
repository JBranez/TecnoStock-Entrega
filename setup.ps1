# Primera configuración local de TecnoStock. Los secretos solo se escriben en archivos .env ignorados por Git.
$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path

function New-RandomHex([int]$Bytes = 16) {
    $buffer = New-Object byte[] $Bytes
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    try { $rng.GetBytes($buffer) } finally { $rng.Dispose() }
    return [BitConverter]::ToString($buffer).Replace('-', '')
}

function New-JwtSecret {
    $buffer = New-Object byte[] 64
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    try { $rng.GetBytes($buffer) } finally { $rng.Dispose() }
    return [Convert]::ToBase64String($buffer).Replace('+', '').Replace('/', '').TrimEnd('=')
}

function Read-SecretInput([string]$Prompt) {
    $secure = Read-Host -Prompt $Prompt -AsSecureString
    $pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    try { return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer) }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer) }
}

function Set-EnvValue([string]$Path, [string]$Key, [string]$Value) {
    $lines = New-Object 'System.Collections.Generic.List[string]'
    foreach ($line in [System.IO.File]::ReadAllLines($Path)) { [void]$lines.Add($line) }
    $prefix = "$Key="
    $found = $false
    for ($index = 0; $index -lt $lines.Count; $index++) {
        if ($lines[$index].StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
            $lines[$index] = "$Key=$Value"
            $found = $true
        }
    }
    if (!$found) { [void]$lines.Add("$Key=$Value") }
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllLines($Path, $lines.ToArray(), $utf8NoBom)
}

function Ensure-LocalSqlSettings([string]$Path) {
    $content = [System.IO.File]::ReadAllText($Path)
    if ($content -notmatch '(?m)^DB_SERVICE_NAME=') {
        Set-EnvValue $Path 'DB_SERVICE_NAME' 'MSSQL$SQLEXPRESS'
    }
}

$rootEnv = Join-Path $Root '.env'
$backendEnv = Join-Path $Root 'backend/.env'
if ((Test-Path $rootEnv) -and !(Test-Path $backendEnv)) {
    Copy-Item -LiteralPath $rootEnv -Destination $backendEnv
    Ensure-LocalSqlSettings $rootEnv
    Ensure-LocalSqlSettings $backendEnv
    Write-Host 'Se creó backend/.env a partir de tu .env existente. Revisa que MSSQL_SA_PASSWORD sea la contraseña real del login sa local.' -ForegroundColor Yellow
    return
}
if ((Test-Path $backendEnv) -and !(Test-Path $rootEnv)) {
    Copy-Item -LiteralPath $backendEnv -Destination $rootEnv
    Ensure-LocalSqlSettings $rootEnv
    Ensure-LocalSqlSettings $backendEnv
    Write-Host 'Se creó .env a partir de backend/.env existente. Revisa que MSSQL_SA_PASSWORD sea la contraseña real del login sa local.' -ForegroundColor Yellow
    return
}
if ((Test-Path $rootEnv) -and (Test-Path $backendEnv)) {
    Ensure-LocalSqlSettings $rootEnv
    Ensure-LocalSqlSettings $backendEnv
    Write-Host 'Los dos archivos .env ya existen. No se sobrescribirán tus credenciales.' -ForegroundColor Yellow
    Write-Host 'Comprueba que MSSQL_SA_PASSWORD coincida con la contraseña que configuraste para sa en SQL Server local.' -ForegroundColor Yellow
    return
}

Write-Host 'TecnoStock se conectará a SQL Server 2022 instalado en este Windows.' -ForegroundColor Cyan
Write-Host 'Escribe la contraseña que asignaste al login sa durante la instalación de SQL Server.' -ForegroundColor Cyan
$saPassword = Read-SecretInput 'Contraseña local de SQL Server para sa'
if ([string]::IsNullOrWhiteSpace($saPassword)) {
    throw 'La contraseña de sa no puede estar vacía. Vuelve a ejecutar .\setup.ps1.'
}

Copy-Item (Join-Path $Root '.env.example') $rootEnv
Copy-Item (Join-Path $Root 'backend/.env.example') $backendEnv
$appPassword = 'TStock!A9' + (New-RandomHex 18)
$adminPassword = 'Admin!A9' + (New-RandomHex 18)
$jwtSecret = New-JwtSecret

foreach ($path in @($rootEnv, $backendEnv)) {
    Set-EnvValue $path 'MSSQL_SA_PASSWORD' $saPassword
    Set-EnvValue $path 'DB_SERVICE_NAME' 'MSSQL$SQLEXPRESS'
    Set-EnvValue $path 'DB_APP_USER' 'tecnostock_app'
    Set-EnvValue $path 'DB_APP_PASSWORD' $appPassword
    Set-EnvValue $path 'JWT_SECRET_KEY' $jwtSecret
    Set-EnvValue $path 'JWT_ALGORITHM' 'HS256'
    Set-EnvValue $path 'ACCESS_TOKEN_EXPIRE_MINUTES' '60'
    Set-EnvValue $path 'CORS_ORIGINS' 'http://localhost:4200'
    Set-EnvValue $path 'SEED_ADMIN_USERNAME' 'admin'
    Set-EnvValue $path 'SEED_ADMIN_PASSWORD' $adminPassword
}

Write-Host ''
Write-Host 'Configuración inicial creada.' -ForegroundColor Green
Write-Host 'Los archivos .env contienen secretos y están excluidos de Git.'
Write-Host 'Guarda estas credenciales de demostración en un lugar seguro:' -ForegroundColor Yellow
Write-Host 'Usuario administrador: admin'
Write-Host "Contraseña administrador: $adminPassword" -ForegroundColor Cyan
Write-Host 'La contraseña de sa no se muestra; queda guardada en los archivos .env locales.'
Write-Host 'No compartas ni publiques los archivos .env.'
