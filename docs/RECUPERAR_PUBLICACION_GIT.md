# Recuperar e inicializar la publicación de TecnoStock

## Diagnóstico del error

El error `fatal: not a git repository` significa que `C:\Dev\TecnoStock` no contiene `.git`. El ZIP distribuye el código fuente, pero no incluye el historial Git. Por eso `git status`, `git branch` y el script de reparación que exige un repositorio existente no pueden funcionar todavía.

El error `Could not resolve to a Repository` indica que `JBranez/TecnoStock-Entrega` no existe en GitHub o la cuenta autenticada no tiene acceso. La sesión `gh auth status` sí puede estar correcta al mismo tiempo.

## Procedimiento corregido

1. Mantén intacta la carpeta `C:\Dev\TecnoStock`; no borres archivos.
2. Comprueba que Git y GitHub CLI funcionan:

```powershell
cd C:\Dev\TecnoStock
git --version
gh auth status
gh api user --jq .login
```

3. Descarga `Inicializar-Publicar-TecnoStock.ps1` y guárdalo, por ejemplo, en `C:\Users\TU_USUARIO\Downloads`.
4. Ejecuta:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
& "$env:USERPROFILE\Downloads\Inicializar-Publicar-TecnoStock.ps1" `
  -ProjectPath "C:\Dev\TecnoStock" `
  -RepositoryFullName "JBranez/TecnoStock-Entrega" `
  -Visibility private
```

El script crea el repositorio remoto si no existe, inicializa Git en la carpeta, configura `origin`, crea commits reales por módulos, publica ramas y crea PRs. Por defecto intenta fusionarlos con merge commit. Si quieres revisar los PR manualmente, agrega `-LeavePullRequestsOpen`.

## Condiciones de seguridad

- Si ya existe un `.git` con commits, el script se detiene para no sobrescribir un historial.
- Si el repositorio remoto ya tiene ramas/commits, se detiene para no sobrescribirlo.
- Comprueba que `.env`, `backend/.env`, entornos virtuales, `node_modules` y backups SQL estén ignorados.
- El script no inventa fechas: las marcas de tiempo son las reales de ejecución.
- No incluye credenciales ni contraseñas en comandos.

## Verificación posterior

```powershell
cd C:\Dev\TecnoStock
git status
git branch -vv
git log --graph --oneline --decorate --all -40
gh repo view JBranez/TecnoStock-Entrega
gh pr list --repo JBranez/TecnoStock-Entrega --state all
```

## Si el script se detiene

No borres `.git` ni ejecutes `git reset --hard`. Copia el mensaje completo de PowerShell y los resultados de `git status`, `git branch -vv` y `git log --oneline --decorate -15`.
