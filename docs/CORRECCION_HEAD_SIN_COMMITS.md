# Corrección del error `fatal: Needed a single revision` al publicar TecnoStock

## Diagnóstico

El repositorio local `C:\Dev\TecnoStock\.git` ya existe, pero todavía no tiene commits. La versión anterior del script comprobaba `HEAD` con `git rev-parse --verify HEAD`. En una rama recién inicializada, `HEAD` todavía no apunta a un commit y Git responde `fatal: Needed a single revision`.

No borres `.git`, no ejecutes `git init` de nuevo y no vuelvas a extraer el ZIP encima de la carpeta de trabajo. Los archivos del proyecto permanecen como archivos sin seguimiento, y se deben conservar.

## Solución

1. Descarga `Inicializar-Publicar-TecnoStock-REST-Corregido.ps1`.
2. Abre PowerShell y ejecuta:

```powershell
cd C:\Dev\TecnoStock
Set-ExecutionPolicy -Scope Process Bypass

& "$env:USERPROFILE\Downloads\Inicializar-Publicar-TecnoStock-REST-Corregido.ps1" `
  -ProjectPath "C:\Dev\TecnoStock" `
  -RepositoryFullName "JBranez/TecnoStock-Entrega" `
  -Visibility private
```

La corrección comprueba la existencia de `HEAD` usando `git rev-parse --verify --quiet HEAD`. Si el repositorio todavía no tiene commits, continúa sin tratar ese estado normal como un error.

La operación remota seguirá utilizando la API REST de GitHub para crear/verificar el repositorio. Si la creación devuelve un error HTTP, la salida incluirá la respuesta del API; conserva ese mensaje para diagnosticar permisos, nombre ocupado o políticas de la cuenta.

## Estado previo observado

La salida anterior confirma:

- GitHub CLI está autenticado como `JBranez`.
- `C:\Dev\TecnoStock\.git` existe.
- La rama actual es `main`, sin commits.
- Los archivos del proyecto aparecen como `untracked`.
- El remoto `JBranez/TecnoStock-Entrega` aún no se ha creado o no es visible.

## Verificación posterior

Cuando termine correctamente, ejecuta:

```powershell
git status
git branch -vv
git log --graph --oneline --decorate --all -40
gh api repos/JBranez/TecnoStock-Entrega --jq .full_name
gh pr list --repo JBranez/TecnoStock-Entrega --state all
```

Todos los commits que genere el script tendrán las fechas reales de la ejecución. El historial representa una reconstrucción organizada del estado actual del código, no una bitácora de trabajo de días anteriores.
