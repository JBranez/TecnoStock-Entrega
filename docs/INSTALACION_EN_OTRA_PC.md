# TecnoStock — Instalación en otra PC (Windows)

Esta guía instala una copia funcional de TecnoStock en un segundo equipo Windows. La aplicación, FastAPI y SQL Server se ejecutan localmente en ese mismo equipo. No se utiliza Docker.

> **Hay dos escenarios diferentes:**
> - **Instalación limpia:** crea una base `TecnoStockDB` nueva y carga los datos de demostración.
> - **Migración de datos existentes:** copia también la base SQL Server de la PC anterior mediante un backup `.bak`. Descomprimir el código no transfiere por sí solo los productos, movimientos ni usuarios guardados en la base original.

## 1. Qué debe instalarse en la PC nueva

Instala los siguientes componentes. Usa instaladores oficiales:

| Componente | Requisito para este proyecto | Enlace oficial |
|---|---|---|
| Windows | Windows 10/11 de 64 bits | Windows Update |
| SQL Server | SQL Server 2022 Express, motor Database Engine, instancia `SQLEXPRESS` | [Descargar SQL Server](https://www.microsoft.com/es-es/download/details.aspx?id=104781) |
| Administrador SQL | SQL Server Management Studio 22 | [Instalar SSMS](https://learn.microsoft.com/es-es/ssms/install/install) |
| Controlador | Microsoft ODBC Driver 18 for SQL Server, x64 | [Descargar ODBC Driver 18](https://learn.microsoft.com/sql/connect/odbc/download-odbc-driver-for-sql-server) |
| Python | Python 3.12, 64 bits, con Python Launcher (`py`) | [Python 3.12 para Windows](https://www.python.org/downloads/release/python-312/) |
| Node.js | Node 22.22.3 o posterior dentro de 22.x, 24.15.0 o posterior dentro de 24.x, o 26.x | [Descargar Node.js](https://nodejs.org/en/download) |
| Git | Git for Windows, solo si clonarás desde GitHub | [Descargar Git](https://git-scm.com/download/win) |

La compatibilidad de Node se basa en Angular 22: [tabla oficial de compatibilidad](https://angular.dev/reference/versions). El script `run.ps1` también comprueba esas versiones antes de arrancar.

Después de instalar Python, Node y ODBC, cierra y vuelve a abrir PowerShell para que se actualice el `PATH`.

Comprueba las herramientas:

```powershell
py -3.12 --version
node --version
npm --version
Get-OdbcDriver -Name 'ODBC Driver 18 for SQL Server'
```

Los tres primeros deben mostrar las versiones instaladas. ODBC debe listar el controlador de 64 bits.

## 2. Instalar y configurar SQL Server 2022 Express

Si SQL Server ya está instalado en la PC nueva, confirma el nombre de instancia y adapta los valores de conexión de la sección 4. Si todavía no está instalado:

1. Ejecuta el instalador oficial de SQL Server 2022 Express.
2. Instala **Database Engine Services**.
3. En **Instance Configuration**, selecciona **Named instance** y escribe `SQLEXPRESS`.
4. En **Database Engine Configuration**, selecciona **Mixed Mode (SQL Server authentication and Windows authentication)**.
5. Define una contraseña segura para `sa` y guárdala en un gestor de contraseñas. No existe una contraseña universal predeterminada.
6. Pulsa **Add Current User** para que tu cuenta de Windows sea administradora de SQL Server.
7. Completa la instalación.

### Habilitar TCP/IP en el puerto fijo

1. Abre **SQL Server Configuration Manager**.
2. Entra en **SQL Server Network Configuration → Protocols for SQLEXPRESS**.
3. Habilita **TCP/IP**.
4. Abre las propiedades de TCP/IP → **IP Addresses** → sección **IPAll**.
5. Deja **TCP Dynamic Ports** vacío (no `0`) y coloca `1433` en **TCP Port**.
6. Guarda y reinicia el servicio **SQL Server (SQLEXPRESS)**.

Si el puerto 1433 ya está ocupado en esa PC, escoge un puerto libre, por ejemplo `14330`, y utiliza ese mismo puerto en los dos archivos `.env` de la sección 4. No detengas procesos desconocidos para liberar 1433.

Comprueba el servicio y el puerto desde PowerShell:

```powershell
Get-Service 'MSSQL$SQLEXPRESS'
Test-NetConnection -ComputerName localhost -Port 1433
```

El servicio debe estar `Running` y `TcpTestSucceeded` debe ser `True`.

### Comprobar la conexión en SSMS

Abre SSMS y usa:

- **Server type:** Database Engine
- **Server name:** `localhost,1433`
- **Authentication:** SQL Server Authentication
- **Login:** `sa`
- **Password:** la que acabas de definir
- **Trust server certificate:** activado para este entorno local de desarrollo

También puedes probar `localhost\SQLEXPRESS` con Windows Authentication usando la cuenta que añadiste como administrador. Si SSMS muestra un error de certificado, marca **Trust server certificate** en la ventana de conexión; no confundas ese aviso con un error de contraseña.

## 3. Copiar el proyecto a la PC nueva

Elige una sola forma:

### Opción A — Desde el ZIP

1. Copia `TecnoStock-SQLServer-Local.zip` a la PC nueva.
2. Extrae su contenido, por ejemplo en `C:\Dev\TecnoStock`.
3. Abre PowerShell en esa carpeta. Debes ver `setup.ps1`, `run.ps1`, `database.ps1`, `backend`, `frontend` y `database`.

### Opción B — Desde GitHub

Cuando el repositorio esté publicado:

```powershell
git clone https://github.com/USUARIO/TecnoStock.git C:\Dev\TecnoStock
Set-Location C:\Dev\TecnoStock
```

Si el repositorio es privado, autentícate con GitHub antes de clonar.

### No copies los artefactos locales del equipo anterior

No es necesario copiar `backend/.venv`, `frontend/node_modules`, `frontend/dist`, ni las carpetas de caché. Se regeneran en la PC nueva. Tampoco compartas los archivos `.env` por GitHub: contienen contraseñas y secretos. El `.gitignore` del proyecto los excluye.

## 4. Configurar las credenciales locales

Desde PowerShell, en la raíz del proyecto:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\setup.ps1
```

El asistente:

- solicita la contraseña real de `sa` de **esta PC**;
- crea `.env` y `backend/.env` si no existen;
- genera una contraseña distinta para `tecnostock_app`;
- genera el secreto JWT;
- genera la contraseña del usuario demo `admin` y la muestra al finalizar.

**Guarda la contraseña demo que muestra el asistente.** En una base nueva, el usuario de acceso inicial es `admin`. No pegues contraseñas en chats ni las subas al repositorio.

El programa usa dos archivos de entorno:

- `C:\Dev\TecnoStock\.env`
- `C:\Dev\TecnoStock\backend\.env`

En ambos deben coincidir las variables compartidas. Para la instalación habitual, los valores de conexión son:

```dotenv
DB_SERVER=localhost
DB_PORT=1433
DB_SERVICE_NAME=MSSQL$SQLEXPRESS
DB_NAME=TecnoStockDB
DB_DRIVER=ODBC Driver 18 for SQL Server
DB_TRUST_SERVER_CERTIFICATE=yes
```

`setup.ps1` crea y sincroniza estos valores. Si elegiste otro puerto, cambia `DB_PORT` en ambos `.env`. Si ya existen `.env` de una ejecución anterior, el script no reemplaza las contraseñas: revisa que `MSSQL_SA_PASSWORD` sea la contraseña actual de `sa` en la PC nueva.

## 5. Inicializar la base y arrancar TecnoStock

Desde la raíz del proyecto:

```powershell
.\database.ps1 -Action all
```

Este comando utiliza `backend/.venv/Scripts/python.exe`. Si no existe el entorno virtual, créalo e instala las dependencias:

```powershell
py -3.12 -m venv backend/.venv
.\backend\.venv\Scripts\python.exe -m pip install -r backend/requirements-dev.txt
.\database.ps1 -Action all
```

La inicialización crea `TecnoStockDB`, las tablas, índices, procedimientos almacenados y permisos. Después carga los datos de demostración de manera idempotente: cinco categorías, quince productos y movimientos coherentes.

Para iniciar los dos servicios de la aplicación:

```powershell
.\run.ps1
```

`run.ps1` verifica Python, Node, ODBC y SQL Server; prepara el entorno virtual, instala dependencias, ejecuta compilación y pruebas, inicializa la base y los datos demo, y abre FastAPI y Angular en ventanas de PowerShell separadas.

Direcciones locales:

| Servicio | URL |
|---|---|
| Angular | http://localhost:4200 |
| FastAPI Swagger | http://localhost:8000/docs |
| API | http://localhost:8000/api/v1 |
| Salud de API y base | http://localhost:8000/health |

Para cerrar la aplicación, cierra las ventanas de FastAPI y Angular. SQL Server permanece funcionando como servicio de Windows.

## 6. Verificar la instalación

1. Abre `http://localhost:8000/health`; debe indicar que la API y la base de datos están disponibles.
2. Abre `http://localhost:4200`.
3. Inicia sesión con `admin` y la contraseña demo guardada en el paso 4.
4. En SSMS, conecta a `localhost,1433`, selecciona `TecnoStockDB` y revisa `dbo.Categorias`, `dbo.Productos` y `dbo.MovimientosInventario`.
5. Crea una categoría desde la web, vuelve a consultar la lista y confirma que aparece sin reiniciar el backend.

Si el puerto elegido no es 1433, reemplázalo en las instrucciones de SSMS y en ambos `.env`.

## 7. ¿Necesitas trasladar también los productos y movimientos reales?

Una instalación limpia carga datos demo; **no** copia la base real del equipo anterior. Para conservar el inventario existente, realiza un backup de SQL Server:

### En la PC anterior

1. Abre SSMS y conéctate a la instancia que contiene los datos.
2. Clic derecho en `TecnoStockDB` → **Tasks → Back Up**.
3. Selecciona **Backup type: Full** y guarda `TecnoStockDB.bak` en una carpeta accesible.
4. Copia ese `.bak` a la PC nueva por un medio seguro.

### En la PC nueva

1. Instala SQL Server 2022 Express y configura la instancia local como en la sección 2.
2. En SSMS, clic derecho en **Databases → Restore Database**.
3. Selecciona **Device**, agrega `TecnoStockDB.bak` y restaura la base.
4. Ejecuta `setup.ps1` para crear los `.env` y credenciales locales de la nueva PC.
5. Ejecuta la inicialización de esquema y usuario:

   ```powershell
   .\database.ps1 -Action init
   ```

6. Si la base restaurada ya contiene el usuario de base de datos `tecnostock_app`, vuelve a asociarlo al login recién creado. En SSMS ejecuta:

   ```sql
   USE [TecnoStockDB];
   GO
   IF USER_ID(N'tecnostock_app') IS NOT NULL
       ALTER USER [tecnostock_app] WITH LOGIN = [tecnostock_app];
   GO
   GRANT EXECUTE ON SCHEMA::dbo TO [tecnostock_app];
   DENY SELECT, INSERT, UPDATE, DELETE ON SCHEMA::dbo TO [tecnostock_app];
   GO
   ```

7. Ejecuta `run.ps1` y verifica `/health` y el frontend.

**Credenciales tras restaurar:** el usuario `admin` restaurado conserva su hash de contraseña anterior. El nuevo valor `SEED_ADMIN_PASSWORD` del `.env` no cambia una contraseña de usuario que ya existía. Conserva de forma segura la contraseña previa o realiza un procedimiento autorizado de restablecimiento antes de entregar el sistema.

No ejecutes `database.ps1 -Action all` como sustituto de un backup si necesitas los datos reales. El backup es lo que conserva productos, stock, usuarios y movimientos registrados.

## 8. Problemas frecuentes

| Mensaje o síntoma | Qué revisar |
|---|---|
| `MSSQL$SQLEXPRESS` no existe | La instancia no se llama `SQLEXPRESS`; confirma el nombre instalado y ajusta `DB_SERVICE_NAME` en ambos `.env`. |
| `TcpTestSucceeded: False` | Servicio detenido, TCP/IP deshabilitado, puerto distinto o firewall local. |
| Error 18456 para `sa` | Contraseña errónea, login `sa` deshabilitado o modo mixto no activado. |
| Error de certificado en SSMS | Marca `Trust server certificate` en opciones de conexión para el entorno local. |
| No se encuentra ODBC Driver 18 | Instala el controlador x64 y vuelve a abrir PowerShell. |
| No existe `backend/.venv` | Ejecuta los comandos de creación del entorno virtual de la sección 5. |
| `npm ci` falla | Comprueba Node compatible, conexión a Internet y que no se haya eliminado `package-lock.json`. |
| La API no conecta después de restaurar un backup | Comprueba el login SQL, el usuario `tecnostock_app`, su asociación mediante `ALTER USER` y los dos `.env`. |

## 9. Fuentes oficiales

- [Descargas de SQL Server](https://www.microsoft.com/es-es/download/details.aspx?id=104781)
- [Instalar SQL Server desde el asistente](https://learn.microsoft.com/sql/database-engine/install-windows/install-sql-server-from-the-installation-wizard-setup)
- [Configurar un puerto TCP fijo](https://learn.microsoft.com/sql/database-engine/configure-windows/configure-a-server-to-listen-on-a-specific-tcp-port)
- [Instalar SQL Server Management Studio](https://learn.microsoft.com/es-es/ssms/install/install)
- [Descargar ODBC Driver 18](https://learn.microsoft.com/sql/connect/odbc/download-odbc-driver-for-sql-server)
- [Compatibilidad de versiones Angular/Node.js](https://angular.dev/reference/versions)
- [Python en Windows](https://docs.python.org/3.12/using/windows.html)
