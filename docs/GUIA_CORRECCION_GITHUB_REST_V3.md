# TecnoStock — Corrección de creación del repositorio GitHub (v3)

## Diagnóstico

El repositorio local de `C:\Dev\TecnoStock` está inicializado, pero todavía no tiene commits. La cuenta GitHub `JBranez` está autenticada. El script anterior se detuvo al crear el repositorio remoto con `gh api` y parámetros `-f` / `-F`, que en la sesión de PowerShell del usuario acabaron interpretándose incorrectamente (`accepts 1 arg(s), received 3`).

La versión v3 conserva el repositorio local y sustituye esos parámetros por un archivo JSON UTF-8 temporal enviado mediante `gh api --method POST /user/repos --input <archivo>`. Esta modalidad está admitida oficialmente por GitHub CLI.

## Ejecutar

1. Descarga `Inicializar-Publicar-TecnoStock-REST-v3.ps1` en Descargas.
2. Abre PowerShell y ejecuta:

```powershell
cd C:\Dev\TecnoStock
Set-ExecutionPolicy -Scope Process Bypass

& "$env:USERPROFILE\Downloads\Inicializar-Publicar-TecnoStock-REST-v3.ps1" `
  -ProjectPath "C:\Dev\TecnoStock" `
  -RepositoryFullName "JBranez/TecnoStock-Entrega" `
  -Visibility private
```

No elimines `.git`, no ejecutes `git init` otra vez y no borres archivos del proyecto.

## Qué debe hacer

- Confirmar la sesión de `gh` y la cuenta autenticada.
- Detectar que `.git` existe, pero no tiene commits, y continuar.
- Consultar el repositorio remoto por REST.
- Si no existe, crear `JBranez/TecnoStock-Entrega` usando `POST /user/repos` y un JSON temporal.
- Configurar `origin`, crear el commit inicial y publicar `main`.
- Crear las ramas y commits organizados por base de datos, backend, frontend y documentación.
- Publicar las ramas, abrir PRs y, si está permitido, intentar integrarlos.

Las fechas de los commits son las del momento real de ejecución; los bloques de commits organizan retrospectivamente el contenido actual, no representan trabajo realizado en días anteriores.

## Si vuelve a fallar en la creación remota

La v3 imprime tanto la respuesta de creación como la de verificación. Copia el texto completo del apartado `PUBLICACION DETENIDA`.

También puedes comprobar la cuenta y permisos con:

```powershell
gh auth status
gh api user --jq .login
gh api /user --jq .login
```

Y comprobar si el repo existe:

```powershell
gh api repos/JBranez/TecnoStock-Entrega --jq .full_name
```

Un 404 aquí significa que el repositorio no existe o no es visible para la cuenta autenticada. Un 403 durante la creación suele indicar restricciones/permisos o límites de GitHub; un 422 suele indicar que el nombre ya existe o que la solicitud no pasa la validación.

## Comprobación final

```powershell
git status
git branch -vv
git log --graph --oneline --decorate --all -40
gh api repos/JBranez/TecnoStock-Entrega --jq .full_name
gh pr list --repo JBranez/TecnoStock-Entrega --state all
```

## Nota de seguridad

No compartas el token que muestra `gh auth status`, contraseñas, `.env` ni archivos de backup de SQL Server. La publicación debe excluir `.env`, entornos virtuales, `node_modules`, `dist`, archivos `.bak`, `.mdf` y `.ldf`.
