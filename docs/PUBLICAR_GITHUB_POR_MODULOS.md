# Publicar TecnoStock en GitHub por módulos

Esta guía utiliza `publicar-tecnostock-por-modulos.ps1` para crear un repositorio nuevo a partir de `C:\Dev\TecnoStock`, organizar los archivos en ramas funcionales y abrir Pull Requests reales.

> **Transparencia del historial:** el script agrupa retrospectivamente los archivos que ya existen. Las fechas de los commits serán las fechas reales de ejecución. No cambia fechas para hacer creer que el código se desarrolló en días anteriores.

## 1. Requisitos

- Git for Windows.
- GitHub CLI.
- Una cuenta de GitHub con permiso para crear repositorios y Pull Requests.
- Acceso a internet.

Instala GitHub CLI si todavía no está instalado:

```powershell
winget install --id GitHub.cli -e
```

Cierra y vuelve a abrir PowerShell. Comprueba las herramientas:

```powershell
git --version
gh --version
gh auth login
```

Cuando `gh auth login` pregunte el método, puedes utilizar el navegador.

## 2. Copiar y ejecutar el script

Descarga `publicar-tecnostock-por-modulos.ps1`. No es obligatorio copiarlo manualmente a la carpeta del proyecto: el propio script se copia a la raíz para quedar versionado.

Si el proyecto está en `C:\Dev\TecnoStock` y ya tiene un `.git` creado por una publicación anterior, ejecuta desde PowerShell:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
& "$env:USERPROFILE\Downloads\publicar-tecnostock-por-modulos.ps1" `
  -ProjectPath "C:\Dev\TecnoStock" `
  -ArchiveExistingGit
```

Si guardaste el script en otra ruta, cambia la ruta del primer argumento.

`-ArchiveExistingGit` mueve la carpeta `.git` actual a una carpeta hermana con nombre similar a `TecnoStock.git-backup-20261102-150000`. No borra el historial anterior. El código fuente y los archivos `.env` locales permanecen en `C:\Dev\TecnoStock`.

Si el proyecto **no** contiene `.git`, omite el parámetro:

```powershell
& "$env:USERPROFILE\Downloads\publicar-tecnostock-por-modulos.ps1" `
  -ProjectPath "C:\Dev\TecnoStock"
```

## 3. Nombre y visibilidad del repositorio

El script propone el repositorio `TecnoStock-Modular` y visibilidad `private`. Durante la ejecución puedes aceptar los valores o escribir otros.

También puedes especificarlos al llamar al script:

```powershell
& "$env:USERPROFILE\Downloads\publicar-tecnostock-por-modulos.ps1" `
  -ProjectPath "C:\Dev\TecnoStock" `
  -RepositoryName "TecnoStock-Entrega" `
  -Visibility public `
  -ArchiveExistingGit
```

Elige `public` solo después de comprobar que no hay información personal ni secretos en el repositorio. Los archivos `.env` y `backend/.env` deben permanecer ignorados por Git.

Si GitHub indica que el nombre del repositorio ya existe, vuelve a ejecutar el script con otro nombre.

## 4. Qué crea el script

El historial comienza en `main` con los archivos de presentación del proyecto y luego crea los siguientes bloques:

| Rama | Contenido | PR |
|---|---|---|
| `feature/database` | Base de datos, tablas, índices, procedimientos almacenados, permisos y datos demo | Base de datos: esquema y procedimientos almacenados |
| `feature/backend` | Configuración Python, capas, endpoints, inicialización y pruebas | Backend: API FastAPI y arquitectura por capas |
| `feature/frontend` | Configuración Angular, servicios, guards, interceptors, componentes y funcionalidades | Frontend: aplicación Angular y módulos de inventario |
| `docs/setup-guides` | Documentación, scripts PowerShell y guías de instalación | Documentación: instalación local y guías de operación |

Cada bloque contiene varios commits convencionales si hay archivos en los grupos definidos. El script publica la rama, crea un Pull Request real y lo integra en `main` con un merge commit. Después ejecuta `git fetch origin`, cambia a `main` y ejecuta `git pull --ff-only origin main`.

El script vuelve a publicar la rama después de integrarla para conservarla en la lista de ramas incluso si el repositorio tiene activada la eliminación automática de ramas fusionadas.

## 5. README visible en la página de GitHub

El script añade al final del `README.md` una sección titulada **Clonar e instalar desde GitHub (Windows / PowerShell)**. GitHub muestra el README de la raíz debajo de la lista de archivos, por lo que allí aparecerán los requisitos y comandos de instalación:

```powershell
git clone https://github.com/USUARIO/REPOSITORIO.git
Set-Location REPOSITORIO
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\setup.ps1
.\run.ps1
```

El README explica que `setup.ps1` prepara los `.env` locales y que `run.ps1` prepara las dependencias, inicializa la base y levanta los servicios. Para trasladar datos existentes, se debe restaurar un backup `.bak`; el seed solo crea datos de demostración.

## 6. Verificar publicación

Desde la carpeta del proyecto:

```powershell
git status
git branch -a
git log --graph --oneline --decorate --all -40
gh repo view
gh pr list --state all
```

El árbol de commits debe mostrar la rama `main`, commits de cada bloque y los merge commits de los Pull Requests. En la pestaña **Pull requests** de GitHub deben aparecer cuatro PR integrados.

## 7. Si un Pull Request no se puede integrar

El script utiliza `gh pr merge --merge` para preservar los commits y crear un merge commit. Si GitHub informa que el método de merge no está permitido, entra en **Settings → General → Pull Requests** del repositorio y habilita **Allow merge commits**, o cambia la estrategia de integración de forma consciente.

Si existen reglas de protección que exigen revisiones o checks, el script se detendrá y dejará la rama publicada y el PR abierto. Completa los requisitos desde GitHub y después actualiza `main`:

```powershell
git fetch origin
git switch main
git pull --ff-only origin main
```

## 8. Importante

Este procedimiento no recupera el historial anterior ni representa un registro diario original. Es una importación estructurada del estado actual. Para conseguir un historial de desarrollo auténtico y más PRs, continúa trabajando en las ramas y crea PRs por funcionalidades nuevas que realmente implementes, pruebes y revises.
