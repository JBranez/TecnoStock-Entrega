# Instalación local de SQL Server 2022 para TecnoStock

Esta guía configura el motor directamente en Windows. Se usará **SQL Server 2022 Express**, la instancia `SQLEXPRESS`, autenticación mixta, TCP/IP en el puerto `1433` y ODBC Driver 18. El proyecto no requiere una plataforma de contenedores.

## 1. Descargar los instaladores oficiales

- [SQL Server 2022 Express — Microsoft Download Center](https://www.microsoft.com/es-es/download/details.aspx?id=104781)
- [SQL Server Management Studio (SSMS) 22 — Microsoft Learn](https://learn.microsoft.com/es-es/ssms/install/install)
- [Microsoft ODBC Driver 18 for SQL Server — Microsoft Learn](https://learn.microsoft.com/es-es/sql/connect/odbc/download-odbc-driver-for-sql-server)

Instala el motor SQL Server 2022 Express primero. Express es gratuito y tiene un límite de tamaño relacional de 10 GB por base de datos; para el alcance académico de TecnoStock es suficiente. SSMS y el controlador ODBC son herramientas/componentes separados: SSMS permite administrar la instancia y ODBC permite que Python (`pyodbc`) se conecte desde FastAPI.

## 2. Instalar SQL Server 2022 Express

1. Ejecuta `SQL2022-SSEI-Expr.exe`.
2. Selecciona **Custom** para abrir el centro de instalación y poder revisar las características.
3. Elige **New SQL Server standalone installation or add features to an existing installation**.
4. Acepta los términos de licencia y deja seleccionada la característica **Database Engine Services**. No necesitas Analysis Services ni Reporting Services para este proyecto.
5. En **Instance Configuration**, selecciona **Named instance** y escribe exactamente `SQLEXPRESS`. El nombre completo de instancia quedará como `EQUIPO\SQLEXPRESS`.
6. En **Database Engine Configuration → Server Configuration**, selecciona **Mixed Mode (SQL Server authentication and Windows authentication)**.
7. Define una contraseña fuerte para el login `sa`. TecnoStock la solicitará después en `setup.ps1`; no la pierdas.
8. Pulsa **Add Current User** para incluir tu cuenta de Windows en los administradores de SQL Server.
9. Completa la instalación y comprueba que el servicio **SQL Server (SQLEXPRESS)** se encuentre instalado.

**Importante:** el login `sa` se usa únicamente durante la inicialización para crear la base y el usuario `tecnostock_app`. FastAPI no se conecta con `sa`.

## 3. Habilitar TCP/IP y fijar el puerto

SQL Server Express normalmente deja TCP/IP deshabilitado en una instalación nueva. TecnoStock necesita una dirección TCP estable para que `pyodbc` se conecte sin depender de la resolución dinámica del nombre de instancia.

1. Abre **SQL Server Configuration Manager** desde el menú Inicio. Para SQL Server 2022 suele aparecer como `SQL Server 2022 Configuration Manager`.
2. En el panel izquierdo, abre **SQL Server Network Configuration → Protocols for SQLEXPRESS**.
3. En el panel derecho, haz clic derecho en **TCP/IP** y selecciona **Enable**.
4. Abre las propiedades de **TCP/IP** y entra en la pestaña **IP Addresses**.
5. Baja hasta la sección **IPAll**. Borra el valor de **TCP Dynamic Ports** (si aparece `0`, elimínalo y deja el campo vacío) y escribe `1433` en **TCP Port**.
6. Pulsa **OK**.
7. En **SQL Server Services**, haz clic derecho en **SQL Server (SQLEXPRESS)** y selecciona **Restart**.

Si el puerto `1433` ya está ocupado por otra instancia SQL Server, usa un puerto local libre, por ejemplo `14330`, y reemplaza `DB_PORT=1433` por `DB_PORT=14330` tanto en `.env` como en `backend/.env`. En el resto de esta guía se supone `1433`.

No es necesario usar SQL Server Browser cuando el cliente indica el host y el puerto directamente (`localhost,1433`).

## 4. Instalar SSMS y ODBC Driver 18

1. Instala SSMS desde el enlace oficial. Abre SSMS y conecta al servidor `localhost,1433`.
2. Selecciona **SQL Server Authentication**, usuario `sa` y la contraseña que definiste en el instalador. Si no conecta, revisa que SQL Server esté en Mixed Mode y que el login `sa` esté habilitado.
3. Instala **Microsoft ODBC Driver 18 for SQL Server (x64)**. El backend usa Python de 64 bits, por lo que debe estar disponible el controlador de 64 bits.
4. Cierra y vuelve a abrir PowerShell después de instalar el controlador.

En una ventana de PowerShell puedes validar el servicio y el puerto:

```powershell
Get-Service 'MSSQL$SQLEXPRESS'
Test-NetConnection -ComputerName localhost -Port 1433
Get-OdbcDriver -Name 'ODBC Driver 18 for SQL Server'
```

El servicio debe estar `Running`, `TcpTestSucceeded` debe ser `True` y debe aparecer el controlador de 64 bits.

En SSMS también puedes ejecutar esta consulta de verificación:

```sql
SELECT
    @@VERSION AS VersionSQLServer,
    SERVERPROPERTY('InstanceName') AS Instancia,
    SERVERPROPERTY('IsIntegratedSecurityOnly') AS SoloAutenticacionWindows;
```

`Instancia` debe mostrar `SQLEXPRESS`. `SoloAutenticacionWindows` debe ser `0`, porque se habilitó Mixed Mode.

## 5. Configurar TecnoStock

1. Descomprime el proyecto y abre PowerShell en la carpeta `TecnoStock`.
2. Ejecuta:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\setup.ps1
```

3. Cuando lo solicite, introduce la contraseña que configuraste para `sa`. PowerShell no mostrará los caracteres. El script crea `.env` y `backend/.env`, genera la contraseña de `tecnostock_app`, JWT y el usuario administrador demo.
4. Guarda la contraseña del usuario demo `admin` que se imprime al finalizar.
5. Abre ambos `.env` y comprueba estos valores (deben coincidir en los dos archivos):

```dotenv
DB_SERVER=localhost
DB_PORT=1433
DB_SERVICE_NAME=MSSQL$SQLEXPRESS
DB_NAME=TecnoStockDB
DB_DRIVER=ODBC Driver 18 for SQL Server
DB_TRUST_SERVER_CERTIFICATE=yes
```

`MSSQL_SA_PASSWORD` debe ser exactamente la contraseña real de `sa`; `DB_APP_PASSWORD` y `JWT_SECRET_KEY` son secretos generados por `setup.ps1`. No publiques los archivos `.env`.

Si ya tenías `.env` de una versión anterior, `setup.ps1` los conserva para no sobrescribir contraseñas. En ese caso, corrige manualmente `DB_SERVER`, `DB_PORT`, `DB_SERVICE_NAME` y, especialmente, `MSSQL_SA_PASSWORD` en ambos archivos. Para `MSSQL_SA_PASSWORD`, usa la contraseña establecida para el login `sa` de tu instancia local, no un valor aleatorio anterior.

## 6. Inicializar la base de datos y ejecutar la aplicación

Requisitos adicionales: Python 3.12 de 64 bits y Node.js que cumpla los engines de Angular 22.2.4 descritos en el README.

Para inicializar solo la BD y los datos demo:

```powershell
.\database.ps1 -Action all
```

El inicializador ejecuta los scripts `database/01_...sql` a `database/10_...sql` en orden. Crea `TecnoStockDB`, tablas, índices, procedimientos, usuario de aplicación y datos de demostración. Es repetible y utiliza la conexión administrativa `sa` únicamente en esta etapa.

Para preparar e iniciar todo el proyecto:

```powershell
.\run.ps1
```

El asistente verifica el servicio local, el puerto TCP, el controlador ODBC, compila el frontend, inicializa SQL, siembra los datos, ejecuta las pruebas y abre API y frontend. Direcciones:

- Aplicación: http://localhost:4200
- Swagger: http://localhost:8000/docs
- Health: http://localhost:8000/health

Usuario demo: `admin`. La contraseña se muestra una sola vez al ejecutar la configuración inicial.

## 7. Verificar la conexión desde la aplicación

1. Abre `http://localhost:8000/health`. Debe devolver un estado correcto de API y base de datos.
2. Abre `http://localhost:4200` e inicia sesión con las credenciales demo.
3. En SSMS, conecta a `localhost,1433`, abre `TecnoStockDB` y revisa las tablas `dbo.Productos`, `dbo.Categorias` y `dbo.MovimientosInventario`.
4. Para verificar el usuario de la API, en SSMS ejecuta:

```sql
USE TecnoStockDB;
SELECT name FROM sys.database_principals WHERE name = 'tecnostock_app';
```

La API debe operar usando `tecnostock_app`, no `sa`. Los procedimientos almacenados son el único mecanismo de persistencia de la aplicación.

## 8. Problemas frecuentes

**El servicio `MSSQL$SQLEXPRESS` no existe.** Comprueba en SQL Server Configuration Manager que instalaste Database Engine Services y que el nombre de instancia sea `SQLEXPRESS`. Si usaste otro nombre, ajusta `DB_SERVICE_NAME` en los dos `.env`.

**El servicio está detenido.** Inícialo desde SQL Server Configuration Manager → SQL Server Services o desde `services.msc`.

**`TcpTestSucceeded` es `False`.** Habilita TCP/IP en `Protocols for SQLEXPRESS`, comprueba el puerto fijo de `IPAll`, reinicia la instancia y verifica que el puerto no esté ocupado por otra aplicación.

**Error de inicio de sesión de `sa` (18456).** Confirma que la autenticación esté en Mixed Mode, que el login `sa` esté habilitado y que `MSSQL_SA_PASSWORD` de ambos `.env` coincida con la contraseña real. Puedes cambiar la contraseña de `sa` desde SSMS con una cuenta administradora.

**No se encuentra ODBC Driver 18.** Instala la versión x64 y comprueba con `Get-OdbcDriver -Name 'ODBC Driver 18 for SQL Server'`. Verifica también que el Python del proyecto sea de 64 bits.

**Error de certificado.** En desarrollo local, `DB_TRUST_SERVER_CERTIFICATE=yes` hace que el controlador confíe en el certificado presentado por la instancia. No uses esta configuración como recomendación de despliegue público.

**El puerto 1433 ya está en uso.** Configura un puerto libre en `IPAll` (por ejemplo, `14330`), reinicia SQL Server y cambia `DB_PORT` en los dos `.env`.

**`setup.ps1` informa que los `.env` ya existen.** Es un mensaje informativo: el script conserva las contraseñas existentes. Revisa de forma manual las variables de conexión y la contraseña administrativa `sa`.

## 9. Documentación oficial consultada

- [Instalar SQL Server desde el asistente gráfico](https://learn.microsoft.com/sql/database-engine/install-windows/install-sql-server-from-the-installation-wizard-setup)
- [Configurar SQL Server para escuchar en un puerto TCP específico](https://learn.microsoft.com/es-es/sql/database-engine/configure-windows/configure-a-server-to-listen-on-a-specific-tcp-port?view=sql-server-ver17)
- [Habilitar o deshabilitar un protocolo de red](https://learn.microsoft.com/en-us/sql/database-engine/configure-windows/enable-or-disable-a-server-network-protocol?view=sql-server-ver16)
- [Descargar ODBC Driver 18](https://learn.microsoft.com/es-es/sql/connect/odbc/download-odbc-driver-for-sql-server)
- [Instalar SQL Server Management Studio](https://learn.microsoft.com/es-es/ssms/install/install)
- [Ediciones y límites de SQL Server 2022](https://learn.microsoft.com/en-us/sql/sql-server/editions-and-components-of-sql-server-2022?view=sql-server-ver17)
