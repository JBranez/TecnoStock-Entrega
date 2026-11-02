# Inicializa (si hace falta) y publica el estado actual real de TecnoStock en GitHub.
# No fabrica commits, fechas, ramas ni Pull Requests.
$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location -LiteralPath $Root

function Stop-WithMessage([string]$Message) {
    Write-Host "`nERROR: $Message" -ForegroundColor Red
    exit 1
}

if (!(Get-Command git -ErrorAction SilentlyContinue)) {
    Stop-WithMessage 'Instala Git for Windows desde https://git-scm.com/download/win.'
}

$gitRoot = & git rev-parse --show-toplevel 2>$null
if ($LASTEXITCODE -ne 0 -or !$gitRoot) {
    Write-Host 'Esta carpeta ZIP no contiene historial Git.' -ForegroundColor Yellow
    Write-Host 'Se creará un único commit que representa el estado actual del código; no recrea la cronología previa.' -ForegroundColor Yellow

    $gitName = (& git config --get user.name 2>$null | Out-String).Trim()
    $gitEmail = (& git config --get user.email 2>$null | Out-String).Trim()
    if ([string]::IsNullOrWhiteSpace($gitName)) {
        $gitName = Read-Host 'Nombre real para los commits Git'
        if ([string]::IsNullOrWhiteSpace($gitName)) { Stop-WithMessage 'El nombre de autor no puede estar vacío.' }
        & git config --local user.name $gitName
        if ($LASTEXITCODE -ne 0) { Stop-WithMessage 'No se pudo configurar user.name.' }
    }
    if ([string]::IsNullOrWhiteSpace($gitEmail)) {
        $gitEmail = Read-Host 'Correo asociado a tu cuenta GitHub'
        if ([string]::IsNullOrWhiteSpace($gitEmail)) { Stop-WithMessage 'El correo de autor no puede estar vacío.' }
        & git config --local user.email $gitEmail
        if ($LASTEXITCODE -ne 0) { Stop-WithMessage 'No se pudo configurar user.email.' }
    }

    & git init -b main
    if ($LASTEXITCODE -ne 0) { Stop-WithMessage 'No se pudo inicializar Git.' }
    & git add -A
    if ($LASTEXITCODE -ne 0) { Stop-WithMessage 'No se pudieron agregar los archivos.' }

    $staged = @(& git diff --cached --name-only)
    $secretFiles = @($staged | Where-Object { $_ -match '(^|/)\.env$' -or $_ -match '(^|/)\.env\.[^/]+$' -and $_ -notmatch '\.env\.example$' })
    if ($secretFiles.Count -gt 0) {
        & git reset
        Stop-WithMessage ('Se detectaron archivos de entorno que no deben publicarse: ' + ($secretFiles -join ', ') + '. Revisa .gitignore antes de continuar.')
    }

    if (@($staged).Count -eq 0) { Stop-WithMessage 'No hay archivos para incluir en el commit inicial.' }
    & git commit -m 'chore: importar estado actual de TecnoStock'
    if ($LASTEXITCODE -ne 0) { Stop-WithMessage 'No se pudo crear el commit de importación.' }
} else {
    Write-Host "Repositorio Git detectado: $gitRoot" -ForegroundColor Green
}

$currentBranch = (& git branch --show-current).Trim()
if ($currentBranch -ne 'main') {
    $mainExists = (& git branch --list main | Out-String).Trim()
    if ([string]::IsNullOrWhiteSpace($mainExists)) {
        & git branch -M main
    } else {
        & git switch main
    }
    if ($LASTEXITCODE -ne 0) { Stop-WithMessage 'No se pudo seleccionar la rama main.' }
}

$trackedFiles = @(& git ls-files)
$trackedSecrets = @($trackedFiles | Where-Object { $_ -match '(^|/)\.env$' -or (($_ -match '(^|/)\.env\.[^/]+$') -and ($_ -notmatch '\.env\.example$')) })
if ($trackedSecrets.Count -gt 0) {
    Stop-WithMessage ('Hay archivos de entorno rastreados por Git. Sácalos del índice y rota sus secretos antes de publicar: ' + ($trackedSecrets -join ', '))
}

$pending = & git status --porcelain
if ($pending) {
    Stop-WithMessage 'Hay cambios pendientes. Revísalos y crea un commit real antes de publicar: git status, git add y git commit.'
}

if (!(Get-Command gh -ErrorAction SilentlyContinue)) {
    Write-Host 'GitHub CLI no está instalado. Instalando con winget…' -ForegroundColor Cyan
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        & winget install --id GitHub.cli -e --source winget
        if ($LASTEXITCODE -ne 0) { Stop-WithMessage 'No se pudo instalar GitHub CLI. Instálalo desde https://cli.github.com/.' }
        Stop-WithMessage 'GitHub CLI instalado. Cierra esta terminal, abre otra y vuelve a ejecutar .\publish-github.ps1.'
    }
    Stop-WithMessage 'Instala GitHub CLI desde https://cli.github.com/ y vuelve a ejecutar.'
}

& gh auth status 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host 'Se abrirá el navegador para autenticar GitHub CLI.' -ForegroundColor Yellow
    & gh auth login --web --git-protocol https
    if ($LASTEXITCODE -ne 0) { Stop-WithMessage 'No se pudo autenticar GitHub CLI.' }
}

$remoteUrl = (& git remote get-url origin 2>$null | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($remoteUrl)) {
    $repoName = Read-Host 'Nombre del repositorio (por defecto: TecnoStock)'
    if ([string]::IsNullOrWhiteSpace($repoName)) { $repoName = 'TecnoStock' }
    $visibility = Read-Host 'Visibilidad (private/public; por defecto: private)'
    if ([string]::IsNullOrWhiteSpace($visibility)) { $visibility = 'private' }
    if ($visibility -notin @('private', 'public')) { Stop-WithMessage 'Visibilidad no válida.' }

    & gh repo create $repoName "--$visibility" --source . --remote origin --description 'Sistema de inventario TecnoStock: Angular 22, FastAPI y SQL Server 2022 Express.'
    if ($LASTEXITCODE -ne 0) { Stop-WithMessage 'No se pudo crear el repositorio remoto. Verifica el nombre y los permisos de GitHub.' }
} else {
    Write-Host "Se usará el remoto origin existente: $remoteUrl" -ForegroundColor Yellow
}

& git push -u origin main
if ($LASTEXITCODE -ne 0) { Stop-WithMessage 'No se pudo publicar main.' }

# Publica únicamente las ramas locales existentes; no crea ramas nuevas ni PRs.
$otherBranches = @(& git for-each-ref --format='%(refname:short)' refs/heads | Where-Object { $_ -ne 'main' })
foreach ($branch in $otherBranches) {
    & git push -u origin $branch
    if ($LASTEXITCODE -ne 0) { Stop-WithMessage "No se pudo publicar la rama existente '$branch'." }
}

$repoFullName = (& gh repo view --json nameWithOwner --jq '.nameWithOwner' 2>$null | Out-String).Trim()
Write-Host ''
Write-Host 'Publicación completada.' -ForegroundColor Green
if ($repoFullName) { Write-Host "Repositorio: https://github.com/$repoFullName" }
Write-Host 'No se crearon commits, ramas ni Pull Requests ficticios.' -ForegroundColor Cyan
Write-Host 'Para crear un PR, implementa un cambio real en una rama, haz commit, publica la rama y ejecuta gh pr create.'
