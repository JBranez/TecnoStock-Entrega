<#
.SYNOPSIS
  Inicializa Git y publica TecnoStock por módulos en GitHub (versión 4: reutiliza remoto existente y evita parsing complejo de gh api).
.DESCRIPTION
  Diseñado para una carpeta del proyecto con un repositorio .git sin commits y un remoto vacío ya creado en GitHub.
  Crea commits por áreas y PRs reales sobre un repositorio GitHub que ya debe existir y estar vacío.
  Todos los commits usan la hora actual. No inventa fechas ni historial anterior.
  Si ya existe un repositorio Git con commits, se detiene para no sobrescribirlo.
#>
[CmdletBinding()]
param(
    [string]$ProjectPath = 'C:\Dev\TecnoStock',
    [string]$RepositoryFullName = 'JBranez/TecnoStock-Entrega',
    [ValidateSet('private','public')]
    [string]$Visibility = 'private',
    [switch]$LeavePullRequestsOpen
)

$ErrorActionPreference = 'Stop'
$script:CommitCount = 0
$script:PullRequestCount = 0
$script:MergeCount = 0
$script:ProjectRoot = $null

function Stop-ProcessWithMessage {
    param([Parameter(Mandatory)][string]$Message)
    throw $Message
}

function Invoke-Git {
    param([Parameter(Mandatory)][string[]]$Arguments)
    & git @Arguments
    $exitCode = $LASTEXITCODE
    if ($exitCode -ne 0) {
        Stop-ProcessWithMessage "Falló git $($Arguments -join ' ') (código $exitCode)."
    }
}

function Invoke-Gh {
    param([Parameter(Mandatory)][string[]]$Arguments)
    & gh @Arguments
    $exitCode = $LASTEXITCODE
    if ($exitCode -ne 0) {
        Stop-ProcessWithMessage "Falló gh $($Arguments -join ' ') (código $exitCode)."
    }
}

function Get-GhResult {
    param([Parameter(Mandatory)][string[]]$Arguments)
    $output = & gh @Arguments 2>&1
    $exitCode = $LASTEXITCODE
    [pscustomobject]@{
        ExitCode = $exitCode
        Text = (($output | Out-String).Trim())
    }
}

function Get-ExistingProjectPaths {
    param([Parameter(Mandatory)][string[]]$Paths)
    $found = @()
    foreach ($relativePath in $Paths) {
        $fullPath = Join-Path $script:ProjectRoot $relativePath
        if (Test-Path -LiteralPath $fullPath) {
            $found += $relativePath
        }
    }
    return $found
}

function Add-ProjectCommit {
    param(
        [Parameter(Mandatory)][string]$Message,
        [Parameter(Mandatory)][string[]]$Paths
    )

    $pathsFound = @(Get-ExistingProjectPaths -Paths $Paths)
    if ($pathsFound.Count -eq 0) {
        Write-Host "  OMITIDO: no existen archivos para '$Message'." -ForegroundColor DarkYellow
        return
    }

    Invoke-Git -Arguments (@('add','-A','--') + $pathsFound)
    $staged = @(& git diff --cached --name-only)
    if ($LASTEXITCODE -ne 0) {
        Stop-ProcessWithMessage 'No se pudo revisar el contenido preparado para commit.'
    }
    if ($staged.Count -eq 0) {
        Write-Host "  SIN CAMBIOS: $Message" -ForegroundColor DarkYellow
        return
    }

    Write-Host "  COMMIT: $Message" -ForegroundColor Cyan
    Invoke-Git -Arguments @('commit','-m',$Message)
    $script:CommitCount++
}

function Ensure-GitIgnore {
    $ignorePath = Join-Path $script:ProjectRoot '.gitignore'
    if (!(Test-Path -LiteralPath $ignorePath)) {
        Stop-ProcessWithMessage 'No existe .gitignore. Se cancela para evitar publicar secretos o dependencias.'
    }

    $content = [System.IO.File]::ReadAllText($ignorePath)
    $requiredRules = @(
        '',
        '# Proteccion adicional para publicacion desde Windows',
        '.env',
        '.env.*',
        '!.env.example',
        '**/.env',
        '**/.env.*',
        '!**/.env.example',
        '**/.venv/',
        '**/venv/',
        '**/node_modules/',
        '**/dist/',
        '**/.angular/',
        '*.bak',
        '*.trn',
        '*.mdf',
        '*.ldf',
        '*.log',
        '*.tmp'
    )
    $updated = $content
    foreach ($rule in $requiredRules) {
        if ($rule -eq '') { continue }
        $escaped = [regex]::Escape($rule)
        if ($updated -notmatch "(?m)^$escaped\s*$") {
            $updated = $updated.TrimEnd() + "`r`n" + $rule + "`r`n"
        }
    }
    if ($updated -ne $content) {
        $utf8 = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::WriteAllText($ignorePath,$updated,$utf8)
        Write-Host '.gitignore actualizado para excluir secretos, entornos y backups.' -ForegroundColor Green
    }

    foreach ($secretPath in @('.env','backend/.env')) {
        & git check-ignore --no-index --quiet -- $secretPath
        if ($LASTEXITCODE -ne 0) {
            Stop-ProcessWithMessage ".gitignore no está ignorando $secretPath. No se publicará hasta corregirlo."
        }
    }
}

function Ensure-ReadmeCloneInstructions {
    $readmePath = Join-Path $script:ProjectRoot 'README.md'
    if (!(Test-Path -LiteralPath $readmePath)) {
        Stop-ProcessWithMessage 'No existe README.md en la raíz del proyecto.'
    }

    $content = [System.IO.File]::ReadAllText($readmePath)
    $cloneUrl = "https://github.com/$($script:RepositoryFullName).git"
    $repoFolder = ($script:RepositoryFullName -split '/')[-1]
    $updated = $content.Replace('https://github.com/USUARIO/REPOSITORIO.git',$cloneUrl)
    $updated = $updated.Replace('Set-Location REPOSITORIO',"Set-Location $repoFolder")

    if ($updated -ne $content) {
        $utf8 = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::WriteAllText($readmePath,$updated,$utf8)
        Write-Host 'README.md actualizado con el enlace real de clonación.' -ForegroundColor Green
    }
}

function Publish-Workstream {
    param(
        [Parameter(Mandatory)][string]$Branch,
        [Parameter(Mandatory)][string]$Title,
        [Parameter(Mandatory)][string]$Body
    )

    $aheadText = (& git rev-list --count "main..$Branch" | Out-String).Trim()
    if ($LASTEXITCODE -ne 0) {
        Stop-ProcessWithMessage "No se pudo comparar main con $Branch."
    }
    if ([int]$aheadText -le 0) {
        Write-Host "No hay commits exclusivos en $Branch; no se crea un PR vacío." -ForegroundColor DarkYellow
        return
    }

    Invoke-Git -Arguments @('push','--set-upstream','origin',$Branch)

    $existingPr = Get-GhResult -Arguments @('pr','list','--repo',$script:RepositoryFullName,'--head',$Branch,'--state','open','--json','number,url')
    if ($existingPr.ExitCode -ne 0) {
        Stop-ProcessWithMessage "No se pudo consultar PRs de $Branch`: $($existingPr.Text)"
    }

    if ([string]::IsNullOrWhiteSpace($existingPr.Text) -or $existingPr.Text -eq '[]') {
        $prBody = @"
## Resumen
Integra el bloque **$Branch** en `main`.

## Alcance
Los commits agrupan archivos del estado actual del proyecto por responsabilidad técnica. Se trata de una reconstrucción organizada al momento de publicación; las fechas son reales y no representan una bitácora histórica anterior.

## Verificación
- [ ] Revisar los archivos y commits incluidos.
- [ ] Ejecutar las pruebas aplicables.
- [ ] Confirmar que no se incorporaron archivos `.env`, contraseñas, tokens ni backups.

## Integración
El PR se integra mediante merge commit para preservar la estructura de commits.
"@
        Write-Host "Creando PR: $Branch -> main" -ForegroundColor Cyan
        Invoke-Gh -Arguments @('pr','create','--repo',$script:RepositoryFullName,'--base','main','--head',$Branch,'--title',$Title,'--body',$prBody)
        $script:PullRequestCount++
    }
    else {
        Write-Host "Ya existe un PR abierto para $Branch; no se duplicará." -ForegroundColor Yellow
        Write-Host $existingPr.Text
    }

    if (!$LeavePullRequestsOpen) {
        Write-Host "Intentando integrar $Branch mediante merge commit..." -ForegroundColor Cyan
        & gh pr merge $Branch --repo $script:RepositoryFullName --merge
        $mergeExit = $LASTEXITCODE
        if ($mergeExit -eq 0) {
            $script:MergeCount++
            Invoke-Git -Arguments @('fetch','origin')
            Invoke-Git -Arguments @('switch','main')
            Invoke-Git -Arguments @('pull','--ff-only','origin','main')
        }
        else {
            Write-Host "No se pudo fusionar automáticamente $Branch. El PR permanece abierto; puedes revisarlo en GitHub." -ForegroundColor Yellow
            Invoke-Git -Arguments @('switch','main')
            Invoke-Git -Arguments @('fetch','origin')
            # main solo avanza si el merge ya fue realizado en remoto.
            & git pull --ff-only origin main
            if ($LASTEXITCODE -ne 0) {
                Write-Host 'No se pudo actualizar main; revisa el PR y ejecuta git pull --ff-only origin main después de integrarlo.' -ForegroundColor Yellow
            }
        }
    }
    else {
        Write-Host "PR publicado y dejado abierto por petición. Rama local: $Branch" -ForegroundColor Green
        Invoke-Git -Arguments @('switch','main')
    }
}

try {
    if (!(Test-Path -LiteralPath $ProjectPath -PathType Container)) {
        Stop-ProcessWithMessage "No existe la carpeta: $ProjectPath"
    }
    $script:ProjectRoot = (Resolve-Path -LiteralPath $ProjectPath).Path
    Set-Location -LiteralPath $script:ProjectRoot

    foreach ($tool in @('git','gh')) {
        if (!(Get-Command $tool -ErrorAction SilentlyContinue)) {
            Stop-ProcessWithMessage "$tool no está instalado o no está disponible en PATH."
        }
    }
    if ($RepositoryFullName -notmatch '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$') {
        Stop-ProcessWithMessage 'RepositoryFullName debe tener el formato PROPIETARIO/REPOSITORIO.'
    }
    $script:RepositoryFullName = $RepositoryFullName

    Write-Host '=== 1. Comprobando GitHub CLI ===' -ForegroundColor Cyan
    & gh auth status
    if ($LASTEXITCODE -ne 0) {
        Stop-ProcessWithMessage 'GitHub CLI no está autenticado. Ejecuta gh auth login --web --git-protocol https.'
    }
    $loginResult = Get-GhResult -Arguments @('api','user','--jq','.login')
    if ($loginResult.ExitCode -ne 0 -or [string]::IsNullOrWhiteSpace($loginResult.Text)) {
        Stop-ProcessWithMessage 'No se pudo detectar la cuenta de GitHub autenticada.'
    }
    $owner = ($RepositoryFullName -split '/')[0]
    if ($loginResult.Text -ine $owner) {
        Write-Host "La cuenta autenticada es $($loginResult.Text), pero el repositorio solicitado pertenece a $owner. Se requiere permiso de creación en ese propietario." -ForegroundColor Yellow
    }

    Write-Host "Cuenta: $($loginResult.Text) | Repositorio: $RepositoryFullName | Visibilidad: $Visibility" -ForegroundColor Green

    Write-Host "`n=== 2. Comprobando la carpeta local ===" -ForegroundColor Cyan
    $gitDir = Join-Path $script:ProjectRoot '.git'
    if (Test-Path -LiteralPath $gitDir) {
        if (!(Test-Path -LiteralPath $gitDir -PathType Container)) {
            Stop-ProcessWithMessage '.git es un archivo (worktree/submódulo). Este script requiere una carpeta Git normal.'
        }
        $inside = & git rev-parse --is-inside-work-tree 2>$null
        if ($LASTEXITCODE -ne 0) {
            Stop-ProcessWithMessage 'La carpeta .git existe, pero Git no puede leerla. No se modificará.'
        }
        # HEAD no existe en un repositorio recién inicializado. --quiet evita que
        # Git emita 'Needed a single revision' y que PowerShell lo trate como error.
        $null = & git rev-parse --verify --quiet HEAD
        $headCheckExitCode = $LASTEXITCODE
        if ($headCheckExitCode -eq 0) {
            Stop-ProcessWithMessage 'Ya existe un historial Git en esta carpeta. Para evitar duplicar o sobrescribir trabajo, este script solo se ejecuta desde una carpeta sin commits. Tus archivos no se han modificado.'
        }
        elseif ($headCheckExitCode -ne 1) {
            Stop-ProcessWithMessage "No se pudo verificar HEAD (código $headCheckExitCode). No se modificará el repositorio."
        }
        Write-Host 'Existe un .git inicializado sin commits; se continuará con él.' -ForegroundColor Yellow
    }
    else {
        Invoke-Git -Arguments @('init')
        Invoke-Git -Arguments @('branch','-M','main')
        Write-Host 'Repositorio Git local inicializado en main.' -ForegroundColor Green
    }

    # Añade el propio script al proyecto para que quede documentado en Git.
    if ($PSCommandPath) {
        $targetScript = Join-Path $script:ProjectRoot 'publicar-tecnostock-desde-cero.ps1'
        $sourceFull = [System.IO.Path]::GetFullPath($PSCommandPath)
        $targetFull = [System.IO.Path]::GetFullPath($targetScript)
        if ($sourceFull -ne $targetFull) {
            Copy-Item -LiteralPath $PSCommandPath -Destination $targetScript -Force
        }
    }

    Ensure-GitIgnore
    Ensure-ReadmeCloneInstructions

    # Identidad local del repositorio. Si no hay configuración global, solicitarla.
    $gitName = (& git config user.name 2>$null | Out-String).Trim()
    if ([string]::IsNullOrWhiteSpace($gitName)) {
        $gitName = Read-Host 'Nombre que aparecerá como autor de los commits'
        if ([string]::IsNullOrWhiteSpace($gitName)) { Stop-ProcessWithMessage 'El nombre Git no puede estar vacío.' }
        Invoke-Git -Arguments @('config','user.name',$gitName)
    }
    $gitEmail = (& git config user.email 2>$null | Out-String).Trim()
    if ([string]::IsNullOrWhiteSpace($gitEmail)) {
        $gitEmail = Read-Host 'Correo asociado a tu cuenta GitHub (o correo noreply de GitHub)'
        if ([string]::IsNullOrWhiteSpace($gitEmail)) { Stop-ProcessWithMessage 'El correo Git no puede estar vacío.' }
        Invoke-Git -Arguments @('config','user.email',$gitEmail)
    }

    Write-Host "`n=== 3. Comprobando repositorio remoto existente ===" -ForegroundColor Cyan
    # El repositorio ya fue creado por el usuario en GitHub. Se verifica con
    # gh api usando solo el endpoint como argumento, sin --jq ni --input.
    # Esto evita el error de parsing "accepts 1 arg(s), received 3" en algunas
    # combinaciones de GitHub CLI/PowerShell.
    $repoJsonOutput = & gh api "repos/$RepositoryFullName" 2>&1
    $repoExitCode = $LASTEXITCODE
    $repoJsonText = ($repoJsonOutput | Out-String).Trim()
    if ($repoExitCode -ne 0) {
        Stop-ProcessWithMessage "No se puede consultar el repositorio remoto $RepositoryFullName mediante REST. Respuesta: $repoJsonText. Comprueba que exista, que sea accesible para $($loginResult.Text) y que el token tenga permiso repo."
    }
    try {
        $repoInfo = $repoJsonText | ConvertFrom-Json
    }
    catch {
        Stop-ProcessWithMessage "GitHub devolvió una respuesta que no se pudo interpretar como JSON: $repoJsonText"
    }
    if ([string]::IsNullOrWhiteSpace([string]$repoInfo.full_name) -or $repoInfo.full_name -ine $RepositoryFullName) {
        Stop-ProcessWithMessage "La respuesta REST no corresponde al repositorio solicitado ($RepositoryFullName). Respuesta: $repoJsonText"
    }
    Write-Host "Repositorio remoto accesible: $($repoInfo.full_name) | $($repoInfo.html_url)" -ForegroundColor Green

    $remoteUrl = "https://github.com/$RepositoryFullName.git"
    $remoteNames = @(& git remote)
    if ($LASTEXITCODE -ne 0) { Stop-ProcessWithMessage 'No se pudieron consultar los remotos Git.' }
    if ($remoteNames -contains 'origin') {
        $currentOrigin = (& git remote get-url origin | Out-String).Trim()
        if ($LASTEXITCODE -ne 0) { Stop-ProcessWithMessage 'No se pudo leer origin.' }
        if ($currentOrigin -ne $remoteUrl) {
            Invoke-Git -Arguments @('remote','set-url','origin',$remoteUrl)
        }
    }
    else {
        Invoke-Git -Arguments @('remote','add','origin',$remoteUrl)
    }

    $remoteHeads = @(& git ls-remote --heads origin)
    if ($LASTEXITCODE -ne 0) { Stop-ProcessWithMessage 'No se pudo consultar el remoto origin.' }
    if ($remoteHeads.Count -gt 0) {
        Stop-ProcessWithMessage 'El repositorio remoto ya contiene ramas/commits. Para no sobrescribirlos, usa un repositorio GitHub vacío o clona el remoto y combina los cambios de forma manual.'
    }

    Invoke-Git -Arguments @('config','pull.ff','only')

    Write-Host "`n=== 4. Commit inicial y README ===" -ForegroundColor Cyan
    Add-ProjectCommit -Message 'chore: inicializar reglas y estructura del repositorio' -Paths @('.gitignore','.github/pull_request_template.md')
    Add-ProjectCommit -Message 'docs: agregar descripcion y guia de instalacion PowerShell' -Paths @('README.md')
    $head = & git rev-parse --verify HEAD 2>$null
    if ($LASTEXITCODE -ne 0) { Stop-ProcessWithMessage 'No se pudo crear el commit inicial. Comprueba README.md y .gitignore.' }
    Invoke-Git -Arguments @('push','-u','origin','main')

    # DATABASE
    Write-Host "`n=== 5. Base de datos ===" -ForegroundColor Magenta
    Invoke-Git -Arguments @('switch','-c','feature/database')
    Add-ProjectCommit -Message 'feat(database): crear base, tablas e integridad referencial' -Paths @('database/01_create_database.sql','database/02_tables.sql','database/03_indexes.sql')
    Add-ProjectCommit -Message 'feat(database): agregar procedimientos de usuarios y categorias' -Paths @('database/04_sp_usuarios.sql','database/05_sp_categorias.sql')
    Add-ProjectCommit -Message 'feat(database): implementar procedimientos de productos y movimientos' -Paths @('database/06_sp_productos.sql','database/07_sp_movimientos.sql','database/PRUEBAS_MANUALES.md')
    Add-ProjectCommit -Message 'feat(database): agregar dashboard, permisos y datos demo' -Paths @('database/08_sp_dashboard.sql','database/09_permissions.sql','database/10_seed_data.sql','database/.gitkeep')
    Publish-Workstream -Branch 'feature/database' -Title 'Base de datos: esquema y procedimientos almacenados' -Body 'Integra el modelo relacional, restricciones, índices y procedimientos almacenados de TecnoStock.'

    # BACKEND
    Write-Host "`n=== 6. Backend ===" -ForegroundColor Magenta
    Invoke-Git -Arguments @('switch','-c','feature/backend','main')
    Add-ProjectCommit -Message 'chore(backend): configurar dependencias y contratos de entorno' -Paths @('pyproject.toml','backend/requirements.txt','backend/requirements-dev.txt','backend/.env.example','backend/.gitkeep')
    Add-ProjectCommit -Message 'feat(backend): implementar configuracion, seguridad y conexion SQL' -Paths @('backend/app/core','backend/app/db','backend/app/__init__.py')
    Add-ProjectCommit -Message 'feat(backend): definir schemas y repositories' -Paths @('backend/app/schemas','backend/app/repositories')
    Add-ProjectCommit -Message 'feat(backend): implementar reglas de negocio en services' -Paths @('backend/app/services')
    Add-ProjectCommit -Message 'feat(backend): exponer endpoints y configurar FastAPI' -Paths @('backend/app/apis','backend/app/main.py')
    Add-ProjectCommit -Message 'test(backend): agregar inicializacion, seed y pruebas automatizadas' -Paths @('backend/scripts','backend/tests')
    Publish-Workstream -Branch 'feature/backend' -Title 'Backend: API FastAPI y arquitectura por capas' -Body 'Integra el backend FastAPI con APIs, Services, Repositories, Schemas y pruebas.'

    # FRONTEND
    Write-Host "`n=== 7. Frontend ===" -ForegroundColor Magenta
    Invoke-Git -Arguments @('switch','-c','feature/frontend','main')
    Add-ProjectCommit -Message 'chore(frontend): configurar proyecto Angular y dependencias' -Paths @('frontend/.gitignore','frontend/.editorconfig','frontend/.prettierrc','frontend/angular.json','frontend/package.json','frontend/package-lock.json','frontend/tsconfig.json','frontend/tsconfig.app.json','frontend/tsconfig.spec.json','frontend/proxy.conf.json','frontend/README.md','frontend/public')
    Add-ProjectCommit -Message 'feat(frontend): crear aplicacion base y enrutamiento' -Paths @('frontend/src/main.ts','frontend/src/index.html','frontend/src/styles.css','frontend/src/environments','frontend/src/app/app.ts','frontend/src/app/app.html','frontend/src/app/app.css','frontend/src/app/app.config.ts','frontend/src/app/app.routes.ts','frontend/src/app/app.spec.ts')
    Add-ProjectCommit -Message 'feat(frontend): agregar modelos, servicios, guards e interceptors' -Paths @('frontend/src/app/core')
    Add-ProjectCommit -Message 'feat(frontend): construir componentes compartidos y navegacion' -Paths @('frontend/src/app/shared','frontend/src/app/componentes')
    Add-ProjectCommit -Message 'feat(frontend): implementar login, categorias y productos' -Paths @('frontend/src/app/features/auth','frontend/src/app/features/categorias','frontend/src/app/features/productos')
    Add-ProjectCommit -Message 'feat(frontend): implementar movimientos, historial y dashboard' -Paths @('frontend/src/app/features/movimientos','frontend/src/app/features/historial','frontend/src/app/features/dashboard','frontend/src/app/features/stock-bajo')
    Publish-Workstream -Branch 'feature/frontend' -Title 'Frontend: aplicación Angular y módulos de inventario' -Body 'Integra Angular, Signal Forms, servicios HTTP, autenticación y pantallas de inventario.'

    # DOCUMENTATION / ROOT SCRIPTS
    Write-Host "`n=== 8. Documentacion y scripts ===" -ForegroundColor Magenta
    Invoke-Git -Arguments @('switch','-c','docs/setup-guides','main')
    Add-ProjectCommit -Message 'docs: documentar arquitectura, modelo de datos y API' -Paths @('docs/ARQUITECTURA.md','docs/MODELO_DATOS.md','docs/API.md','docs/DECISIONES.md')
    Add-ProjectCommit -Message 'docs: agregar guias de instalacion local y diagnostico Windows' -Paths @('docs/INSTALACION_SQL_SERVER_LOCAL.md','docs/INSTALACION_EN_OTRA_PC.md','docs/ERRORES_WINDOWS.md')
    Add-ProjectCommit -Message 'docs: preparar sustentacion y documentacion de GitHub' -Paths @('docs/SUSTENTACION.md','docs/GIT_Y_GITHUB.md','docs/PUBLICAR_GITHUB_POR_MODULOS.md')
    Add-ProjectCommit -Message 'chore(windows): agregar scripts de configuracion y ejecucion' -Paths @('.env.example','setup.ps1','run.ps1','database.ps1','publish-github.ps1','publicar-tecnostock-por-modulos.ps1','publicar-tecnostock-desde-cero.ps1')

    # Asegura que ningún archivo de proyecto restante quede sin versionar.
    Invoke-Git -Arguments @('add','-A')
    $remaining = @(& git diff --cached --name-only)
    if ($LASTEXITCODE -ne 0) { Stop-ProcessWithMessage 'No se pudo revisar el cierre de archivos.' }
    if ($remaining.Count -gt 0) {
        Write-Host 'Se encontraron archivos restantes; se incluirán en un commit de cierre de documentación/configuración:' -ForegroundColor Yellow
        $remaining | ForEach-Object { Write-Host "  $_" }
        Invoke-Git -Arguments @('commit','-m','chore: completar archivos restantes del proyecto')
        $script:CommitCount++
    }
    Publish-Workstream -Branch 'docs/setup-guides' -Title 'Documentación: instalación local y guías del proyecto' -Body 'Integra la documentación técnica, las guías de instalación y los scripts PowerShell.'

    Write-Host "`n=== 9. Sincronizacion final ===" -ForegroundColor Cyan
    Invoke-Git -Arguments @('switch','main')
    Invoke-Git -Arguments @('fetch','origin','--prune')
    & git pull --ff-only origin main
    if ($LASTEXITCODE -ne 0) {
        Write-Host 'Aviso: no se pudo actualizar main automáticamente. Si hay PR abiertos, intégralos en GitHub y ejecuta git pull --ff-only origin main.' -ForegroundColor Yellow
    }

    # Bloquea la publicación si algún .env quedó rastreado.
    $tracked = @(& git ls-files)
    if ($LASTEXITCODE -ne 0) { Stop-ProcessWithMessage 'No se pudo revisar la lista de archivos versionados.' }
    $trackedEnv = @($tracked | Where-Object { ($_ -match '(^|/)\.env$') -or (($_ -match '(^|/)\.env\.[^/]+$') -and ($_ -notmatch '\.env\.example$')) })
    if ($trackedEnv.Count -gt 0) {
        Stop-ProcessWithMessage ('Se detectaron archivos .env versionados: ' + ($trackedEnv -join ', ') + '. Detén la publicación y rota las credenciales si ya fueron publicadas.')
    }

    Write-Host "`n=== PUBLICACION FINALIZADA ===" -ForegroundColor Green
    Write-Host "Repositorio: https://github.com/$RepositoryFullName" -ForegroundColor Green
    Write-Host "Commits creados: $script:CommitCount"
    Write-Host "PR creados durante esta ejecución: $script:PullRequestCount"
    Write-Host "PR integrados automáticamente: $script:MergeCount"
    if ($LeavePullRequestsOpen) { Write-Host 'Los PR se dejaron abiertos por el parámetro -LeavePullRequestsOpen.' -ForegroundColor Yellow }
    Write-Host "`n--- git status ---" -ForegroundColor Yellow
    & git status --short --branch
    Write-Host "`n--- git branch -vv ---" -ForegroundColor Yellow
    & git branch -vv
    Write-Host "`n--- gh pr list ---" -ForegroundColor Yellow
    Invoke-Gh -Arguments @('pr','list','--repo',$RepositoryFullName,'--state','all')
    Write-Host "`nHistorial resumido:" -ForegroundColor Cyan
    & git --no-pager log --graph --oneline --decorate --all -40
    Write-Host "`nREADME.md contiene los comandos PowerShell de instalacion y GitHub lo mostrara debajo de los archivos." -ForegroundColor Green
    Write-Host 'Todas las fechas de commits corresponden al momento real de esta ejecucion.' -ForegroundColor Green
}
catch {
    Write-Host "`nPUBLICACION DETENIDA: $($_.Exception.Message)" -ForegroundColor Red
    if (Test-Path -LiteralPath (Join-Path $ProjectPath '.git')) {
        Write-Host 'Hay un repositorio .git local. No lo borres. Diagnostico:' -ForegroundColor Yellow
        Push-Location -LiteralPath $ProjectPath
        try {
            & git status --short --branch
            & git branch -vv
            $null = & git rev-parse --verify --quiet HEAD
            if ($LASTEXITCODE -eq 0) {
                & git log --oneline --decorate -15
            }
            else {
                Write-Host 'El repositorio todavía no tiene commits; no hay historial que mostrar.' -ForegroundColor Yellow
            }
        }
        finally { Pop-Location }
    }
    else {
        Write-Host 'No se pudo crear .git; los archivos fuente siguen en la carpeta del proyecto.' -ForegroundColor Yellow
    }
    Write-Host 'Corrige el error y revisa los resultados antes de volver a ejecutar.' -ForegroundColor Yellow
    exit 1
}
