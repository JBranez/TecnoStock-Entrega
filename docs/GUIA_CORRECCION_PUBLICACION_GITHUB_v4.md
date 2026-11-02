# TecnoStock — Corrección de publicación GitHub (v4)

## Qué se corrigió

Las versiones anteriores intentaban comprobar/crear el repositorio remoto con varias opciones de `gh api` en una sola llamada. La ejecución de PowerShell se detenía con `accepts 1 arg(s), received 3` antes del primer commit.

Esta versión está adaptada al estado que reportó el usuario:

- `C:\Dev\TecnoStock` ya contiene `.git`.
- La rama local `main` todavía no tiene commits.
- La cuenta de GitHub autenticada es `JBranez`.
- El remoto `JBranez/TecnoStock-Entrega` ya fue creado y se verificó previamente con `gh api repos/JBranez/TecnoStock-Entrega --jq .full_name`.

Por eso v4 NO intenta crear el repositorio. Solo valida el remoto con una llamada simple: `gh api repos/PROPIETARIO/REPOSITORIO`, sin `--jq`, `--input`, ni argumentos de creación.

## Antes de ejecutar

Desde PowerShell:

```powershell
cd C:\Dev\TecnoStock
gh auth status
gh api repos/JBranez/TecnoStock-Entrega --jq .full_name
git status
```

La segunda orden debe devolver `JBranez/TecnoStock-Entrega`. El repositorio remoto debe estar vacío (sin README, licencia ni `.gitignore` creados desde GitHub). El script se detiene si encuentra ramas remotas para evitar sobrescribir contenido.

## Ejecutar

Descarga `Inicializar-Publicar-TecnoStock-v4.ps1` en Descargas y ejecuta:

```powershell
Set-ExecutionPolicy -Scope Process Bypass

& "$env:USERPROFILE\Downloads\Inicializar-Publicar-TecnoStock-v4.ps1" `
  -ProjectPath "C:\Dev\TecnoStock" `
  -RepositoryFullName "JBranez/TecnoStock-Entrega" `
  -Visibility private
```

No borres `.git` y no vuelvas a ejecutar `git init`.

## Qué hace

1. Comprueba `gh auth status` y detecta la cuenta activa.
2. Verifica que el `.git` local está inicializado y aún no tiene commits.
3. Verifica que existe el repositorio remoto por REST.
4. Configura `origin` y se detiene si el remoto contiene ramas.
5. Crea commits reales para `.gitignore`, plantilla de PR y `README.md`.
6. Publica `main`.
7. Crea commits por módulos en ramas `feature/database`, `feature/backend`, `feature/frontend` y `docs/setup-guides`.
8. Publica las ramas y crea PR reales; intenta integrarlos mediante merge commit. Si GitHub no permite el merge, deja el PR abierto.
9. Muestra `git status`, `git branch -vv`, `gh pr list` y el historial.

Los commits utilizan la fecha real de ejecución; no se retrofechan.

## Si se detiene

No ejecutes `git reset --hard`, no elimines `.git` y no repitas `git init`. Copia el error completo y ejecuta:

```powershell
git status
git branch -vv
git log --graph --oneline --decorate --all -40
git remote -v
git ls-remote --heads origin
```

Comparte la salida (sin tokens ni contraseñas) para reanudar desde el punto correcto.
