# Corrección de publicación de TecnoStock en GitHub

## Diagnóstico confirmado

La salida de PowerShell muestra:

- `gh auth status` está autenticado como `JBranez`.
- `gh api user --jq .login` devuelve `JBranez`.
- `C:\Dev\TecnoStock\.git` ya existe y Git reconoce la rama `main`.
- Aún no se ha creado ningún commit: `No commits yet on main`.
- Los archivos del proyecto siguen como `untracked`; no se han perdido.
- `JBranez/TecnoStock-Entrega` no existe o no es visible para esa sesión.

El primer script se detuvo en la etapa de creación del repositorio remoto mediante `gh repo create`. Esta versión cambia esa operación por la API REST de GitHub con `gh api`.

## Procedimiento recomendado

1. Descarga `Inicializar-Publicar-TecnoStock-REST.ps1` y guárdalo en Descargas.
2. No borres `C:\Dev\TecnoStock\.git` ni vuelvas a extraer el ZIP sobre la carpeta existente.
3. Abre PowerShell y ejecuta:

```powershell
cd C:\Dev\TecnoStock
Set-ExecutionPolicy -Scope Process Bypass

& "$env:USERPROFILE\Downloads\Inicializar-Publicar-TecnoStock-REST.ps1" `
  -ProjectPath "C:\Dev\TecnoStock" `
  -RepositoryFullName "JBranez/TecnoStock-Entrega" `
  -Visibility private
```

El script comprobará el remoto mediante REST. Si no existe, intentará crearlo mediante `POST /user/repos`, y luego verificará el resultado antes de añadir `origin` y publicar ramas.

## Alternativa manual: crear solo el repositorio remoto

Si prefieres crear el repo manualmente antes de ejecutar el script:

```powershell
gh api --method POST user/repos `
  -f name=TecnoStock-Entrega `
  -F private=true `
  -f description="TecnoStock: sistema web de inventario con Angular, FastAPI y SQL Server 2022 local." `
  --jq .html_url
```

Verifica que ahora existe:

```powershell
gh api repos/JBranez/TecnoStock-Entrega --jq .full_name
```

Debe devolver:

```text
JBranez/TecnoStock-Entrega
```

Después ejecuta el script corregido. Como el repositorio Git local está vacío y sin commits, continuará desde `main`.

## Si la API REST responde con error

- `HTTP 403`: falta permiso de creación de repositorios para el token o la cuenta.
- `HTTP 422`: el nombre ya existe, no está disponible o GitHub rechazó la solicitud por validación.
- `HTTP 401`: revisar `gh auth status` y volver a autenticar con `gh auth login --hostname github.com --git-protocol https`.
- `HTTP 404` al consultar el repo después de crearlo: comprobar propietario y nombre exactos.

Para un repositorio privado, los tokens clásicos necesitan el alcance `repo` para crearlo. La salida del usuario ya mostraba dicho alcance.

## Verificación al finalizar

```powershell
git status
git branch -vv
git log --graph --oneline --decorate --all -40
gh repo view JBranez/TecnoStock-Entrega
gh pr list --repo JBranez/TecnoStock-Entrega --state all
```

Los commits se crearán con las fechas reales de la ejecución. El historial se presenta como una organización modular del estado actual, no como una bitácora pasada.
