# Git y GitHub — estado real del repositorio

## 1. Qué contiene el ZIP

El ZIP distribuido con TecnoStock contiene el código fuente y los scripts, pero **no incluye la carpeta `.git` ni un archivo `.bundle`**. Por ello, el ZIP no contiene commits, ramas ni Pull Requests anteriores que se puedan restaurar.

El archivo `publish-github.ps1` anterior esperaba un bundle externo llamado `TecnoStock-Git-Integrado.bundle`, y ramas que no están presentes en el ZIP. Además, generaba PRs automáticamente a partir de nombres de ramas predefinidos. Ese comportamiento se retiró: un PR debe corresponder a cambios que realmente existan en su rama.

## 2. Crear el repositorio a partir del estado actual

Desde PowerShell, abre la carpeta raíz de TecnoStock. Antes del primer commit configura tu identidad real de Git (usa el nombre y correo asociados a tu cuenta):

```powershell
git config --global user.name "Tu nombre"
git config --global user.email "tu-correo-de-GitHub"
```

Comprueba que los archivos secretos no se van a versionar:

```powershell
git status --short --ignored
```

`.env` y `backend/.env` deben aparecer ignorados si ya existen. Nunca uses `git add -f` para incluirlos.

El ZIP no tiene historia anterior, así que inicializa un único commit de importación del estado actual:

```powershell
git init -b main
git add -A
git status --short
git commit -m "chore: importar estado actual de TecnoStock"
```

Ese commit representa honestamente una **instantánea del proyecto ya existente**. No demuestra ni pretende reconstruir en qué fecha se implementó cada funcionalidad.

## 3. Publicar en GitHub

Instala GitHub CLI si todavía no está disponible:

```powershell
winget install --id GitHub.cli -e
```

Cierra y vuelve a abrir PowerShell. Inicia sesión:

```powershell
gh auth login --web --git-protocol https
gh auth status
```

Crea un repositorio privado (recomendado para un trabajo académico que todavía no se entrega) y publica `main`:

```powershell
gh repo create TecnoStock --private --source . --remote origin
git push -u origin main
```

Para hacerlo público, cambia `--private` por `--public` únicamente después de revisar que no haya secretos, datos personales ni información que no quieras publicar.

También puedes usar el script incluido:

```powershell
.\publish-github.ps1
```

El script inicializa Git con un único commit de importación si la carpeta aún no es un repositorio, crea el remoto con GitHub CLI y publica `main`. **No inventa commits ni crea ramas o PRs ficticios.**

## 4. Flujo correcto para ramas y Pull Requests reales

A partir de `main`, trabaja una tarea concreta en una rama independiente. Ejemplo para una mejora futura real de la documentación:

```powershell
git switch main
git pull origin main
git switch -c docs/mejora-guia-instalacion
```

Edita los archivos relacionados con esa tarea (por ejemplo, abre y modifica `docs/INSTALACION_EN_OTRA_PC.md`). Después:

```powershell
git status
git diff
git add docs/INSTALACION_EN_OTRA_PC.md
git commit -m "docs: mejorar guia de instalacion en otro equipo"
git push -u origin docs/mejora-guia-instalacion
gh pr create --base main --head docs/mejora-guia-instalacion
```

Sustituye el archivo y el mensaje por los cambios que realmente hayas realizado. Revisa el PR en GitHub, ejecuta las pruebas pertinentes y fusiónalo cuando esté listo. Después:

```powershell
git switch main
git pull origin main
```

Convención de trabajo recomendada:

- `feat(area): ...` para una funcionalidad nueva.
- `fix(area): ...` para corregir un defecto comprobado.
- `test: ...` para pruebas nuevas o corregidas.
- `docs: ...` para documentación.
- `refactor(area): ...` para reorganización sin cambiar el comportamiento.
- `chore: ...` para mantenimiento del proyecto.

No crees commits vacíos, no cambies fechas para simular antigüedad y no abras PRs que no contienen cambios. Si el curso exige un número mínimo de commits o PRs, confirma con el docente cómo documentar el repositorio creado después del desarrollo; el historial nuevo no puede acreditar retroactivamente trabajo que no se registró en Git.

## 5. Revisar el historial

Comandos que muestran la actividad real:

```powershell
git log --oneline --decorate --graph --all
git branch --all
gh pr list --state all
```

Guarda capturas de las ramas, commits y PRs reales como evidencia del flujo de trabajo.

## Publicación organizada por módulos

Para generar un repositorio nuevo a partir del estado actual, utiliza `publicar-tecnostock-por-modulos.ps1` desde PowerShell. El script agrupa los archivos en `feature/database`, `feature/backend`, `feature/frontend` y `docs/setup-guides`, crea varios commits por bloque, abre Pull Requests reales y los integra en `main`. Después de cada integración actualiza la rama principal con `git pull --ff-only origin main`.

Los commits usan la fecha real de ejecución. Esta publicación organiza retrospectivamente los archivos existentes; no debe presentarse como una cronología diaria original. Si ya existe una carpeta `.git`, el script requiere `-ArchiveExistingGit` y mueve esa metadata a una carpeta hermana como respaldo, sin eliminarla. El repositorio remoto nuevo tiene por defecto el nombre `TecnoStock-Modular`.

Ejecución desde PowerShell:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\publicar-tecnostock-por-modulos.ps1 -ProjectPath 'C:\Dev\TecnoStock' -ArchiveExistingGit
```

Se requiere Git for Windows, GitHub CLI (`winget install --id GitHub.cli -e`) y una sesión autenticada con `gh auth login`. GitHub debe permitir merge commits para que los PR se integren conservando los commits del bloque.

