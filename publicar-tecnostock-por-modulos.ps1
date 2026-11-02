<#
.SYNOPSIS
  Publica TecnoStock en GitHub con commits agrupados por área y Pull Requests reales.

.DESCRIPTION
  Crea un historial organizado a partir del estado ACTUAL de los archivos. Todos los
  commits usan la fecha/hora real de ejecución. No modifica fechas para simular días
  anteriores ni afirma que los cambios se realizaron en fechas distintas.

  Workstreams: feature/database, feature/backend, feature/frontend y docs/setup-guides.
  Cada workstream se publica, abre un Pull Request y se integra en main mediante un
  merge commit. Después de cada PR se ejecuta: git fetch origin, git switch main y
  git pull --ff-only origin main.

  Por seguridad, si ya existe .git, el script se detiene. Para crear un repositorio
  nuevo y conservar el historial Git previo como copia, usa -ArchiveExistingGit.
#>

[CmdletBinding()]
param(
    [string]$ProjectPath = 'C:\Dev\TecnoStock',
    [string]$RepositoryName = 'TecnoStock-Modular',
    [ValidateSet('private', 'public')]
    [string]$Visibility = 'private',
    [switch]$ArchiveExistingGit
)

$ErrorActionPreference = 'Stop'
$script:CommitCount = 0
$script:PullRequestCount = 0

function Stop-WithMessage {
    param([Parameter(Mandatory)][string]$Message)
    Write-Host "`nERROR: $Message" -ForegroundColor Red
    throw $Message
}

function Invoke-Git {
    param([Parameter(Mandatory)][string[]]$Arguments)
    & git @Arguments
    $exitCode = $LASTEXITCODE
    if ($exitCode -ne 0) {
        Stop-WithMessage "Falló: git $($Arguments -join ' ') (código $exitCode)."
    }
}

function Invoke-Gh {
    param([Parameter(Mandatory)][string[]]$Arguments)
    & gh @Arguments
    $exitCode = $LASTEXITCODE
    if ($exitCode -ne 0) {
        Stop-WithMessage "Falló: gh $($Arguments -join ' ') (código $exitCode)."
    }
}

function Get-ExistingPaths {
    param([Parameter(Mandatory)][string[]]$Paths)
    $existing = @()
    foreach ($path in $Paths) {
        $fullPath = Join-Path $script:ProjectPath $path
        if (Test-Path -LiteralPath $fullPath) {
            $existing += $path
        }
    }
    return $existing
}

function New-ProjectCommit {
    param(
        [Parameter(Mandatory)][string]$Message,
        [Parameter(Mandatory)][string[]]$Paths
    )

    $existingPaths = @(Get-ExistingPaths -Paths $Paths)
    if ($existingPaths.Count -eq 0) {
        Write-Host "  OMITIDO (no hay archivos en este grupo): $Message" -ForegroundColor DarkYellow
        return
    }

    Invoke-Git -Arguments (@('add', '-A', '--') + $existingPaths)
    $staged = @(& git diff --cached --name-only)
    if ($LASTEXITCODE -ne 0) {
        Stop-WithMessage 'No se pudo consultar el contenido preparado para commit.'
    }

    if ($staged.Count -eq 0) {
        Write-Host "  SIN CAMBIOS: $Message" -ForegroundColor DarkYellow
        return
    }

    Write-Host "  Commit: $Message" -ForegroundColor Cyan
    Invoke-Git -Arguments @('commit', '-m', $Message)
    $script:CommitCount++
}

function New-Workstream {
    param(
        [Parameter(Mandatory)][string]$Branch,
        [Parameter(Mandatory)][string]$Title,
        [Parameter(Mandatory)][string]$Body
    )
    Write-Host "`n=== Rama $Branch ===" -ForegroundColor Magenta
    Invoke-Git -Arguments @('switch', '--create', $Branch)
}

function Complete-Workstream {
    param([Parameter(Mandatory)][string]$Branch)

    # Captura cualquier archivo del proyecto que no haya entrado en los grupos anteriores.
    Invoke-Git -Arguments @('add', '-A')
    $remaining = @(& git diff --cached --name-only)
    if ($LASTEXITCODE -ne 0) {
        Stop-WithMessage 'No se pudo revisar si quedaron archivos pendientes.'
    }
    if ($remaining.Count -gt 0) {
        Write-Host '  Se encontraron archivos adicionales; se incluirán en un commit de cierre.' -ForegroundColor Yellow
        Invoke-Git -Arguments @('commit', '-m', 'chore: completar archivos de configuración del proyecto')
        $script:CommitCount++
    }

    $ahead = (& git rev-list --count "main..$Branch").Trim()
    if ($LASTEXITCODE -ne 0) {
        Stop-WithMessage "No se pudo comparar la rama $Branch con main."
    }
    if ([int]$ahead -eq 0) {
        Write-Host "No hay cambios nuevos en $Branch; no se abrirá un PR vacío." -ForegroundColor Yellow
        Invoke-Git -Arguments @('switch', 'main')
        return
    }

    Invoke-Git -Arguments @('push', '-u', 'origin', $Branch)

    $prTitle = switch ($Branch) {
        'feature/database' { 'Base de datos: esquema y procedimientos almacenados' }
        'feature/backend' { 'Backend: API FastAPI y arquitectura por capas' }
        'feature/frontend' { 'Frontend: aplicación Angular y módulos de inventario' }
        'docs/setup-guides' { 'Documentación: instalación local y guías de operación' }
        default { "Integrar $Branch" }
    }

    $prBody = @"
## Resumen
Integra el bloque de trabajo **$Branch** en `main`.

## Alcance
Los commits agrupan archivos existentes del estado actual del proyecto por responsabilidad técnica. Las fechas de estos commits corresponden a la ejecución real del script; no son una reconstrucción de fechas históricas.

## Verificación
- [ ] Revisar los archivos incluidos en los commits.
- [ ] Ejecutar las pruebas aplicables.
- [ ] Confirmar que no se incorporaron archivos `.env`, contraseñas ni secretos.

## Integración
Este PR se integra con un merge commit para conservar los commits del bloque.
"@

    Write-Host "Creando Pull Request para $Branch..." -ForegroundColor Cyan
    Invoke-Gh -Arguments @('pr', 'create', '--base', 'main', '--head', $Branch, '--title', $prTitle, '--body', $prBody)
    $script:PullRequestCount++

    Write-Host "Integrando el PR de $Branch mediante merge commit..." -ForegroundColor Cyan
    Invoke-Gh -Arguments @('pr', 'merge', $Branch, '--merge')

    # Actualiza main local después de la integración remota del PR.
    Invoke-Git -Arguments @('fetch', 'origin')
    Invoke-Git -Arguments @('switch', 'main')
    Invoke-Git -Arguments @('pull', '--ff-only', 'origin', 'main')
    # Vuelve a publicar la rama por si el repositorio elimina automáticamente las ramas fusionadas.
    Invoke-Git -Arguments @('push', '-u', 'origin', $Branch)
}

function Ensure-ReadmeInstallationSection {
    param(
        [Parameter(Mandatory)][string]$CloneUrl,
        [Parameter(Mandatory)][string]$RepoFolder
    )
    $readmePath = Join-Path $script:ProjectPath 'README.md'
    if (!(Test-Path -LiteralPath $readmePath)) {
        Stop-WithMessage 'No existe README.md en la raíz. Crea un README antes de publicar.'
    }

    $content = [System.IO.File]::ReadAllText($readmePath)
    $marker = '## Clonar e instalar desde GitHub (Windows / PowerShell)'
    if ($content.Contains($marker)) {
        $updatedContent = $content.Replace('https://github.com/USUARIO/REPOSITORIO.git', $CloneUrl)
        $updatedContent = $updatedContent.Replace('Set-Location REPOSITORIO', "Set-Location $RepoFolder")
        if ($updatedContent -ne $content) {
            $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
            [System.IO.File]::WriteAllText($readmePath, $updatedContent, $utf8NoBom)
            Write-Host 'README.md actualizado con la URL real del repositorio GitHub.' -ForegroundColor Green
        } else {
            Write-Host 'README.md ya contiene la guía de clonación e instalación.' -ForegroundColor Green
        }
        return
    }

    $section = @"

## Clonar e instalar desde GitHub (Windows / PowerShell)

Esta guía aparece aquí porque GitHub muestra el `README.md` debajo de la lista de archivos del repositorio.

### Requisitos previos

- Windows 10/11.
- SQL Server 2022 Express instalado localmente, instancia `SQLEXPRESS`, TCP/IP habilitado.
- SQL Server Management Studio (SSMS).
- Microsoft ODBC Driver 18 for SQL Server (64 bits).
- Python 3.12 de 64 bits.
- Una versión de Node.js compatible con Angular 22 (consulta la sección **Requisitos y versiones** de este README).

### Comandos de instalación

Abre PowerShell y ejecuta los siguientes comandos. La URL se configura automáticamente al crear el repositorio:

```powershell
# 1. Descargar el repositorio
git clone $CloneUrl
Set-Location $RepoFolder

# 2. Permitir scripts en esta ventana de PowerShell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass

# 3. Crear los archivos .env locales y configurar las credenciales
.\setup.ps1

# 4. Preparar e iniciar SQL Server, backend y frontend (run.ps1 inicializa la BD y los datos demo)
.\run.ps1
```

`setup.ps1` solicitará la contraseña real del login `sa` de esa computadora y generará las credenciales locales de la aplicación. No compartas ni publiques `.env` o `backend/.env`. `run.ps1` prepara el entorno Python, instala dependencias, inicializa la base y los datos de demostración, ejecuta las comprobaciones y arranca backend y frontend.

### Direcciones locales

- Frontend: <http://localhost:4200>
- API: <http://localhost:8000/api/v1>
- Swagger: <http://localhost:8000/docs>
- Salud: <http://localhost:8000/health>

### Importante sobre los datos

`database.ps1 -Action all` crea una base nueva con datos de demostración. Para trasladar los productos, usuarios, existencias e historial reales de otra computadora, realiza un backup `.bak` de SQL Server y restáuralo en el equipo nuevo siguiendo `docs/INSTALACION_EN_OTRA_PC.md`.

### Nota sobre el historial de Git

Cuando este proyecto se publica mediante `publicar-tecnostock-por-modulos.ps1`, los commits y Pull Requests organizan el estado actual por áreas técnicas. Sus marcas de tiempo son reales y no representan una bitácora diaria anterior al momento de la publicación.
"@

    $newContent = $content.TrimEnd() + "`r`n" + $section + "`r`n"
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($readmePath, $newContent, $utf8NoBom)
    Write-Host 'Se agregó al README una guía PowerShell visible en la página principal de GitHub.' -ForegroundColor Green
}

try {
    if (!(Test-Path -LiteralPath $ProjectPath -PathType Container)) {
        Stop-WithMessage "No existe la carpeta del proyecto: $ProjectPath"
    }
    $script:ProjectPath = (Resolve-Path -LiteralPath $ProjectPath).Path
    Set-Location -LiteralPath $script:ProjectPath

    if (!(Get-Command git -ErrorAction SilentlyContinue)) {
        Stop-WithMessage 'Git no está instalado. Instala Git for Windows y vuelve a ejecutar.'
    }
    if (!(Get-Command gh -ErrorAction SilentlyContinue)) {
        Stop-WithMessage 'GitHub CLI no está instalado. Ejecuta: winget install --id GitHub.cli -e'
    }

    # Evita que el script se ejecute desde otra carpeta y quede fuera del repositorio.
    $runningScript = $PSCommandPath
    if ($runningScript) {
        $destinationScript = Join-Path $script:ProjectPath 'publicar-tecnostock-por-modulos.ps1'
        $runningFull = [System.IO.Path]::GetFullPath($runningScript)
        $destinationFull = [System.IO.Path]::GetFullPath($destinationScript)
        if ($runningFull -ne $destinationFull) {
            Copy-Item -LiteralPath $runningScript -Destination $destinationScript -Force
        }
    }

    # Una nueva cronología no debe sobrescribir silenciosamente un repositorio existente.
    $gitPath = Join-Path $script:ProjectPath '.git'
    if (Test-Path -LiteralPath $gitPath) {
        if (!$ArchiveExistingGit) {
            Stop-WithMessage 'Ya existe .git. Para conservarlo y crear un repositorio nuevo organizado, vuelve a ejecutar con -ArchiveExistingGit. El historial existente se moverá fuera de la carpeta del proyecto, no se borrará.'
        }
        if (!(Test-Path -LiteralPath $gitPath -PathType Container)) {
            Stop-WithMessage '.git es un archivo (posible worktree/submódulo). Archívalo manualmente o ejecuta el script en una copia normal del proyecto.'
        }
        $answer = Read-Host 'Se archivará la carpeta .git existente fuera del proyecto y se creará un repositorio nuevo. ¿Continuar? (S/N)'
        if ($answer -notmatch '^(S|SI|Y|YES)$') {
            Stop-WithMessage 'Operación cancelada por el usuario.'
        }
        $parentPath = Split-Path -Parent $script:ProjectPath
        $folderName = Split-Path -Leaf $script:ProjectPath
        $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
        $backupGit = Join-Path $parentPath "$folderName.git-backup-$stamp"
        Move-Item -LiteralPath $gitPath -Destination $backupGit
        Write-Host "Historial Git anterior archivado en: $backupGit" -ForegroundColor Yellow
    }

    if (!(Test-Path -LiteralPath (Join-Path $script:ProjectPath '.gitignore'))) {
        Stop-WithMessage 'Falta .gitignore. No se publicará el proyecto sin reglas para excluir secretos y dependencias.'
    }

    # Verifica identidad de Git antes de crear commits.
    $gitName = (& git config --global --get user.name 2>$null | Out-String).Trim()
    if ([string]::IsNullOrWhiteSpace($gitName)) {
        $gitName = Read-Host 'Nombre real para los commits Git'
        if ([string]::IsNullOrWhiteSpace($gitName)) { Stop-WithMessage 'El nombre Git no puede estar vacío.' }
        Invoke-Git -Arguments @('config', '--global', 'user.name', $gitName)
    }
    $gitEmail = (& git config --global --get user.email 2>$null | Out-String).Trim()
    if ([string]::IsNullOrWhiteSpace($gitEmail)) {
        $gitEmail = Read-Host 'Correo asociado a tu cuenta GitHub'
        if ([string]::IsNullOrWhiteSpace($gitEmail)) { Stop-WithMessage 'El correo Git no puede estar vacío.' }
        Invoke-Git -Arguments @('config', '--global', 'user.email', $gitEmail)
    }

    # Autenticación de GitHub antes de realizar commits.
    & gh auth status *> $null
    if ($LASTEXITCODE -ne 0) {
        Write-Host 'Se abrirá el navegador para iniciar sesión en GitHub CLI.' -ForegroundColor Yellow
        Invoke-Gh -Arguments @('auth', 'login', '--web', '--git-protocol', 'https')
    }

    # El repositorio remoto se crea antes de los PR para publicar main y luego cada rama.
    $repoInput = Read-Host "Nombre del repositorio GitHub (por defecto: $RepositoryName)"
    if (![string]::IsNullOrWhiteSpace($repoInput)) { $RepositoryName = $repoInput.Trim() }

    $visibilityInput = Read-Host "Visibilidad: private/public (por defecto: $Visibility)"
    if (![string]::IsNullOrWhiteSpace($visibilityInput)) {
        $visibilityInput = $visibilityInput.Trim().ToLowerInvariant()
        if ($visibilityInput -notin @('private', 'public')) {
            Stop-WithMessage 'La visibilidad debe ser private o public.'
        }
        $Visibility = $visibilityInput
    }

    # Resuelve el usuario/propietario autenticado para que el README tenga el enlace de clonación correcto.
    if ($RepositoryName -match '^([^/]+)/([^/]+)$') {
        $repositoryOwner = $Matches[1]
        $repoFolder = $Matches[2]
    } else {
        $repositoryOwner = (& gh api user --jq .login 2>$null | Out-String).Trim()
        if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($repositoryOwner)) {
            Stop-WithMessage 'No se pudo obtener el usuario de GitHub. Ejecuta gh auth status y vuelve a intentarlo.'
        }
        $repoFolder = $RepositoryName
    }
    $repositoryFullName = "$repositoryOwner/$repoFolder"
    & gh repo view $repositoryFullName *> $null
    if ($LASTEXITCODE -eq 0) {
        Stop-WithMessage "El repositorio '$repositoryFullName' ya existe. Ejecuta el script con otro -RepositoryName para crear un repositorio nuevo."
    }

    $cloneUrl = "https://github.com/$repositoryOwner/$repoFolder.git"
    Ensure-ReadmeInstallationSection -CloneUrl $cloneUrl -RepoFolder $repoFolder

    Write-Host "`n=== Preparando repositorio local ===" -ForegroundColor Magenta
    Invoke-Git -Arguments @('init', '-b', 'main')
    Invoke-Git -Arguments @('config', 'pull.ff', 'only')

    # Verifica antes del primer push que los archivos .env locales estén ignorados.
    foreach ($secretPath in @('.env', 'backend/.env')) {
        & git check-ignore --quiet -- $secretPath
        if ($LASTEXITCODE -ne 0) {
            Stop-WithMessage "El .gitignore no está ignorando $secretPath. Corrige las reglas antes de publicar secretos."
        }
    }

    # Commit base: reglas del repositorio y plantilla de PR.
    New-ProjectCommit -Message 'chore: inicializar estructura y reglas del repositorio' -Paths @('.gitignore', '.github/pull_request_template.md')
    # README se registra aparte para que la guía de instalación aparezca en la página de GitHub.
    New-ProjectCommit -Message 'docs: publicar descripción y guía de instalación PowerShell' -Paths @('README.md')

    if ((& git rev-parse --verify HEAD 2>$null) -eq $null) {
        Stop-WithMessage 'No se pudo crear el commit base. Verifica que README.md y .gitignore existan.'
    }

    $visibilityFlag = if ($Visibility -eq 'public') { '--public' } else { '--private' }
    Write-Host "`nCreando repositorio remoto $RepositoryName ($Visibility)..." -ForegroundColor Cyan
    Invoke-Gh -Arguments @('repo', 'create', $RepositoryName, $visibilityFlag, '--source', '.', '--remote', 'origin', '--description', 'TecnoStock: sistema web de inventario con Angular, FastAPI y SQL Server 2022 Express local.')
    Invoke-Git -Arguments @('push', '-u', 'origin', 'main')

    # -------------------------------------------------------------------------
    # 1) Base de datos: esquema, SP, permisos y datos demostrativos.
    # -------------------------------------------------------------------------
    New-Workstream -Branch 'feature/database' -Title 'Base de datos' -Body 'Esquema SQL Server, índices y procedimientos almacenados.'
    New-ProjectCommit -Message 'feat(database): crear base, tablas y restricciones' -Paths @('database/01_create_database.sql', 'database/02_tables.sql', 'database/03_indexes.sql')
    New-ProjectCommit -Message 'feat(database): agregar procedimientos de usuarios y categorias' -Paths @('database/04_sp_usuarios.sql', 'database/05_sp_categorias.sql')
    New-ProjectCommit -Message 'feat(database): implementar procedimientos de productos y movimientos' -Paths @('database/06_sp_productos.sql', 'database/07_sp_movimientos.sql', 'database/PRUEBAS_MANUALES.md')
    New-ProjectCommit -Message 'feat(database): agregar dashboard, permisos y datos demo' -Paths @('database/08_sp_dashboard.sql', 'database/09_permissions.sql', 'database/10_seed_data.sql', 'database/.gitkeep')
    Complete-Workstream -Branch 'feature/database'

    # -------------------------------------------------------------------------
    # 2) Backend: configuración, capas, endpoints, scripts y pruebas.
    # -------------------------------------------------------------------------
    New-Workstream -Branch 'feature/backend' -Title 'Backend FastAPI' -Body 'API FastAPI organizada en APIs, Services, Repositories y Schemas.'
    New-ProjectCommit -Message 'chore(backend): configurar dependencias y entorno Python' -Paths @('pyproject.toml', 'backend/requirements.txt', 'backend/requirements-dev.txt', 'backend/.env.example', 'backend/.gitkeep')
    New-ProjectCommit -Message 'feat(backend): implementar configuracion, seguridad y conexion SQL' -Paths @('backend/app/core', 'backend/app/db', 'backend/app/__init__.py')
    New-ProjectCommit -Message 'feat(backend): definir schemas y repositories' -Paths @('backend/app/schemas', 'backend/app/repositories')
    New-ProjectCommit -Message 'feat(backend): implementar reglas de negocio en services' -Paths @('backend/app/services')
    New-ProjectCommit -Message 'feat(backend): exponer endpoints y configurar FastAPI' -Paths @('backend/app/apis', 'backend/app/main.py')
    New-ProjectCommit -Message 'test(backend): agregar inicializacion, seed y pruebas automatizadas' -Paths @('backend/scripts', 'backend/tests')
    Complete-Workstream -Branch 'feature/backend'

    # -------------------------------------------------------------------------
    # 3) Frontend: configuración Angular, core, componentes y funcionalidades.
    # -------------------------------------------------------------------------
    New-Workstream -Branch 'feature/frontend' -Title 'Frontend Angular' -Body 'Aplicación Angular 22, servicios HTTP, Signal Forms y pantallas del inventario.'
    New-ProjectCommit -Message 'chore(frontend): configurar proyecto Angular y dependencias' -Paths @('frontend/.gitignore', 'frontend/.editorconfig', 'frontend/.prettierrc', 'frontend/angular.json', 'frontend/package.json', 'frontend/package-lock.json', 'frontend/tsconfig.json', 'frontend/tsconfig.app.json', 'frontend/tsconfig.spec.json', 'frontend/proxy.conf.json', 'frontend/README.md', 'frontend/public')
    New-ProjectCommit -Message 'feat(frontend): crear aplicacion base y enrutamiento' -Paths @('frontend/src/main.ts', 'frontend/src/index.html', 'frontend/src/styles.css', 'frontend/src/environments', 'frontend/src/app/app.ts', 'frontend/src/app/app.html', 'frontend/src/app/app.css', 'frontend/src/app/app.config.ts', 'frontend/src/app/app.routes.ts', 'frontend/src/app/app.spec.ts')
    New-ProjectCommit -Message 'feat(frontend): agregar modelos, servicios, guards e interceptors' -Paths @('frontend/src/app/core')
    New-ProjectCommit -Message 'feat(frontend): construir componentes compartidos y navegacion' -Paths @('frontend/src/app/shared', 'frontend/src/app/componentes')
    New-ProjectCommit -Message 'feat(frontend): implementar login, categorias y productos' -Paths @('frontend/src/app/features/auth', 'frontend/src/app/features/categorias', 'frontend/src/app/features/productos')
    New-ProjectCommit -Message 'feat(frontend): implementar movimientos, historial y dashboard' -Paths @('frontend/src/app/features/movimientos', 'frontend/src/app/features/historial', 'frontend/src/app/features/dashboard', 'frontend/src/app/features/stock-bajo')
    Complete-Workstream -Branch 'feature/frontend'

    # -------------------------------------------------------------------------
    # 4) Documentación y automatización local de Windows/PowerShell.
    # -------------------------------------------------------------------------
    New-Workstream -Branch 'docs/setup-guides' -Title 'Documentación y montaje local' -Body 'Guías de instalación, sustentación, arquitectura y scripts PowerShell.'
    New-ProjectCommit -Message 'docs: documentar arquitectura, modelo de datos y API' -Paths @('docs/ARQUITECTURA.md', 'docs/MODELO_DATOS.md', 'docs/API.md', 'docs/DECISIONES.md')
    New-ProjectCommit -Message 'docs: agregar guias de instalacion y diagnostico Windows' -Paths @('docs/INSTALACION_SQL_SERVER_LOCAL.md', 'docs/INSTALACION_EN_OTRA_PC.md', 'docs/ERRORES_WINDOWS.md')
    New-ProjectCommit -Message 'docs: preparar sustentacion y flujo GitHub' -Paths @('docs/SUSTENTACION.md', 'docs/GIT_Y_GITHUB.md')
    New-ProjectCommit -Message 'chore(windows): agregar scripts de configuracion y ejecucion' -Paths @('.env.example', 'setup.ps1', 'run.ps1', 'database.ps1', 'publish-github.ps1', 'publicar-tecnostock-por-modulos.ps1')
    Complete-Workstream -Branch 'docs/setup-guides'

    # Verificación final de secretos y estado del repositorio.
    $trackedFiles = @(& git ls-files)
    $trackedSecrets = @($trackedFiles | Where-Object {
        ($_ -match '(^|/)\.env$') -or
        (($_ -match '(^|/)\.env\.[^/]+$') -and ($_ -notmatch '\.env\.example$'))
    })
    if ($trackedSecrets.Count -gt 0) {
        Stop-WithMessage ('Se detectaron secretos rastreados por Git: ' + ($trackedSecrets -join ', ') + '. No publiques hasta retirarlos y rotar las credenciales.')
    }

    $status = @(& git status --porcelain)
    if ($status.Count -gt 0) {
        Write-Host 'Quedaron archivos sin commit:' -ForegroundColor Yellow
        $status | ForEach-Object { Write-Host "  $_" }
        Stop-WithMessage 'El repositorio no quedó limpio. Revisa los archivos indicados antes de publicar más cambios.'
    }

    Write-Host "`n=== PUBLICACIÓN COMPLETADA ===" -ForegroundColor Green
    Write-Host "Repositorio: $(gh repo view --json url --jq .url)" -ForegroundColor Green
    Write-Host "Commits creados durante esta ejecución: $script:CommitCount" -ForegroundColor Green
    Write-Host "Pull Requests creados e integrados: $script:PullRequestCount" -ForegroundColor Green
    Write-Host "Ramas locales y remotas creadas: feature/database, feature/backend, feature/frontend, docs/setup-guides" -ForegroundColor Green
    Write-Host "`nHistorial resumido:" -ForegroundColor Cyan
    & git --no-pager log --graph --oneline --decorate --all -40
    Write-Host "`nEl README.md contiene una guía PowerShell que GitHub muestra debajo de la lista de archivos." -ForegroundColor Cyan
    Write-Host 'Los commits tienen sus marcas de tiempo reales; esta publicación no simula días anteriores.' -ForegroundColor Cyan
}
catch {
    Write-Host "`nPublicación detenida: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host 'Los commits y ramas creados hasta el momento permanecen en el repositorio local. Corrige el problema y revisa: git status, git branch y gh pr list.' -ForegroundColor Yellow
    exit 1
}
