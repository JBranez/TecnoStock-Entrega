# Inicializa la BD y/o crea los datos demo usando SIEMPRE backend/.venv.
param(
    [ValidateSet('all', 'init', 'seed')]
    [string]$Action = 'all'
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location -LiteralPath $Root
$Python = Join-Path $Root 'backend/.venv/Scripts/python.exe'

if (!(Test-Path $Python)) {
    Write-Host 'No existe backend/.venv. Ejecuta primero:' -ForegroundColor Red
    Write-Host '  py -3.12 -m venv backend/.venv'
    Write-Host '  .\backend\.venv\Scripts\python.exe -m pip install -r backend/requirements-dev.txt'
    exit 1
}

try {
    & $Python -c "import pyodbc; print('Python:', __import__('sys').executable); print('ODBC:', ', '.join(pyodbc.drivers()))"
    if ($LASTEXITCODE -ne 0) { throw 'pyodbc no está instalado dentro de backend/.venv.' }
} catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

if ($Action -in @('all', 'init')) {
    Write-Host '[1/2] Inicializando esquema y procedimientos SQL…' -ForegroundColor Cyan
    & $Python (Join-Path $Root 'backend/scripts/init_db.py')
    if ($LASTEXITCODE -ne 0) { Write-Host 'Falló init_db.py.' -ForegroundColor Red; exit 1 }
}

if ($Action -in @('all', 'seed')) {
    Write-Host '[2/2] Creando administrador y datos de demostración…' -ForegroundColor Cyan
    & $Python (Join-Path $Root 'backend/scripts/seed.py')
    if ($LASTEXITCODE -ne 0) { Write-Host 'Falló seed.py.' -ForegroundColor Red; exit 1 }
}

Write-Host 'Operación de base de datos completada.' -ForegroundColor Green
