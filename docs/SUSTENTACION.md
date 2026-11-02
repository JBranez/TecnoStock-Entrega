# Guía de sustentación — TecnoStock

Esta guía explica la implementación integrada de TecnoStock: base de datos, backend FastAPI y frontend Angular con Signal Forms conectado a la API. Distingue el comportamiento implementado de las verificaciones de entorno que todavía deben ejecutarse en una instalación real.

## 1. Explicación del backend en palabras simples

El backend tiene cuatro capas:

- **APIs:** reciben HTTP, validan autenticación y devuelven códigos como 201, 401, 404, 409 y 422. No contienen reglas de inventario ni SQL.
- **Schemas:** definen qué datos acepta y devuelve la API. Por ejemplo, una cantidad de movimiento debe ser un entero mayor que cero.
- **Services:** coordinan el caso de uso y aplican reglas de negocio. No conocen HTTP ni ejecutan consultas.
- **Repositories:** solicitan procedimientos almacenados y transforman filas de SQL Server a diccionarios. Traducen los errores `CODIGO|mensaje` a excepciones de dominio.

El `db/executor.py` es el único punto Python que ejecuta procedimientos. Las consultas de persistencia están dentro de los SP de SQL Server.

## 2. Recorrido real: registrar una salida

1. El usuario completa el formulario de salida y pulsa Registrar.
2. El formulario Angular envía `POST /api/v1/movimientos/salidas` con `producto_id`, `cantidad`, `fecha_movimiento`, `motivo` y el JWT en `Authorization: Bearer ...`.
3. FastAPI valida el JWT, comprueba que el usuario siga activo y valida el cuerpo con `MovimientoCreate`.
4. `MovimientoService` valida que la cantidad sea un entero positivo y que fecha/motivo sean válidos.
5. `MovimientoRepository` llama al executor con `dbo.usp_Movimiento_RegistrarSalida` y parámetros enlazados.
6. El SP abre una transacción, bloquea la fila de producto, comprueba que exista, que esté activo y que alcance el stock.
7. Si todo es válido, actualiza el stock, inserta el movimiento con stock anterior/posterior y confirma la transacción.
8. El SP devuelve el movimiento. FastAPI responde 201. El frontend reconsulta los productos y el historial para mostrar el estado real.

## 3. Base de datos, procedimientos y transacciones

- Se usan SP porque la consigna exige centralizar allí toda la persistencia y permite limitar el usuario de la API a `EXECUTE`.
- `SET NOCOUNT ON` evita que los conteos de filas interfieran con la lectura de result sets desde pyodbc.
- `SET XACT_ABORT ON` indica a SQL Server que un error de ejecución aborte la transacción.
- `TRY/CATCH` revierte con `ROLLBACK` si ocurre una excepción antes de confirmar. Si el error sucede después de actualizar stock pero antes de insertar historial, ambos cambios se revierten.
- `UPDLOCK` toma un bloqueo de actualización al leer la fila del producto dentro de la transacción. Dos salidas concurrentes no pueden leer el mismo stock disponible y gastarlo dos veces.
- `ROWLOCK` solicita que el bloqueo se aplique al nivel de fila cuando sea posible.
- El cambio de stock y el insert del historial están en la misma transacción: cumplen RN6.

## 4. Cómo se evita el stock negativo

La validación existe en varios niveles:

1. `MovimientoCreate` exige `cantidad` estrictamente entera y mayor que cero.
2. `MovimientoService` vuelve a verificar la cantidad y la fecha/motivo.
3. `usp_Movimiento_RegistrarSalida` compara la cantidad con el stock real bajo `UPDLOCK` y lanza `STOCK_INSUFICIENTE` si no alcanza.
4. `Productos.StockActual` tiene `CHECK (StockActual >= 0)` y `MovimientosInventario.StockPosterior` también tiene `CHECK (StockPosterior >= 0)`.
5. Una restricción adicional verifica que el stock posterior sea igual al anterior más/minus cantidad, según el tipo.

La validación visual del frontend es una ayuda; el servidor y la base de datos son la autoridad final.

## 5. Historial y eliminación

- Cada entrada/salida válida inserta un registro nuevo.
- No existen endpoints ni SP de actualización/eliminación de movimientos.
- Las FK no tienen `ON DELETE CASCADE`.
- `usp_Producto_Eliminar` solo permite borrar físicamente un producto si no tiene movimientos. Si hay historial, devuelve `PRODUCTO_CON_MOVIMIENTOS` y la API responde 409.
- Para conservar la historia se utiliza `PATCH /productos/{id}/estado` para desactivar.
- Una categoría con productos tampoco puede eliminarse.

## 6. Seguridad

- La contraseña se transforma a hash Argon2 con `pwdlib[argon2]`; el valor original no se almacena.
- El login entrega un JWT firmado con HS256 y expiración configurada.
- El resto de rutas versionadas exige Bearer token. Se consulta el usuario en SQL Server para comprobar que aún existe y está activo.
- Los secretos están en `backend/.env` y `.env`, ambos ignorados por Git. Los `.env.example` contienen placeholders.
- La API usa `tecnostock_app`, nunca `sa`. El inicializador usa `sa` solo para crear el esquema y el login. El usuario de runtime recibe `EXECUTE` y no permisos directos de tabla.
- CORS se limita a `CORS_ORIGINS`. Las respuestas GET llevan `Cache-Control: no-store`.
- Los errores inesperados se escriben en el log y el cliente solo recibe un mensaje genérico.

## 7. pyodbc y conexiones

`pyodbc` es síncrono; por eso las rutas usan `def`, no `async def`. FastAPI ejecuta esas operaciones síncronas en su threadpool. `get_protected_db` abre una conexión por request autenticado, compartida por las dependencias mediante el caché de dependencias de FastAPI, y siempre la cierra. La conexión usa `autocommit=True` porque los SP que modifican datos administran sus propias transacciones.

## 8. Manejo de errores de extremo a extremo

Ejemplo de salida con stock insuficiente:

1. El SP lanza `THROW 50003, N'STOCK_INSUFICIENTE|Stock disponible: 7.'`.
2. `pyodbc` propaga el error al repository.
3. `db_errors.py` identifica el código y crea `ConflictError`.
4. El handler global lo transforma en HTTP 409 y JSON `{code, detail, errors}`.
5. El interceptor de errores Angular convierte ese JSON en `ApiError`; la pantalla muestra el detalle y los errores de campo en la alerta del formulario.

Los errores estructurales de Pydantic devuelven 422 con el campo y un mensaje en español. Un producto inexistente devuelve 404 y una duplicidad devuelve 409.

## 9. Signal Forms e integración frontend

Signal Forms vincula un modelo creado con `signal()` mediante `form(model, configuracion)`. Cada input utiliza `[formField]` para sincronizar el valor y el estado del campo. Los validadores `required`, `min`, `maxLength`, `pattern` y `validate` generan errores que `app-field-error` presenta en español. El botón permite intentar el envío; `submit()` marca los campos interactivos como touched y solo ejecuta el callback si la validación pasa. Mientras se guarda, el botón se deshabilita para evitar envíos duplicados.

La implementación utiliza Signal Forms en login, categorías, alta/edición y filtros de productos, movimientos, historial y dashboard. No se usa Reactive Forms ni Template-driven Forms. Los errores 409/422 que devuelve FastAPI se muestran como alertas dentro de la pantalla o el formulario; los errores de campo de Pydantic se resumen con su nombre y mensaje. La navegación es un sidebar fijo en escritorio y un panel off-canvas controlado por un signal en móvil.

### Recorrido de autenticación

1. `LoginPage` valida usuario y contraseña con Signal Forms.
2. `AuthService.login()` envía `POST /api/v1/auth/login` mediante `HttpClient`.
3. La API verifica el hash Argon2 y entrega el JWT.
4. `AuthService` guarda el token en `sessionStorage` y actualiza el signal del usuario.
5. `authGuard` protege las rutas privadas; `guestGuard` evita que un usuario autenticado vuelva al login.
6. `authInterceptor` agrega el Bearer token. `errorInterceptor` limpia la sesión y redirige al login ante 401.

### Recorrido de registrar una salida

1. El usuario abre Movimientos, elige Salida y selecciona un producto activo obtenido desde `GET /api/v1/productos`.
2. Signal Forms valida producto, cantidad entera positiva, fecha no futura y motivo; ofrece el stock disponible como validación de experiencia.
3. `MovimientoService.registerExit()` envía `POST /api/v1/movimientos/salidas` con HttpClient.
4. `authInterceptor` añade el JWT. FastAPI valida el schema y obtiene el usuario autenticado.
5. Router → `MovimientoService` → `MovimientoRepository` → executor → `EXEC dbo.usp_Movimiento_RegistrarSalida`.
6. El SP bloquea la fila, valida stock, actualiza producto e inserta historial dentro de una transacción. Devuelve stock anterior y posterior.
7. Angular muestra el resultado, presenta una notificación y vuelve a consultar los productos. El historial obtiene el movimiento al entrar a su pantalla.

### Refresco de datos

Después de guardar una categoría o producto, cambiar el estado, registrar una entrada/salida o modificar filtros, la pantalla llama a la API. Los listados no se actualizan mutando arrays locales. Por eso los cambios hechos directamente en SQL Server también aparecen al recargar la vista.

## 10. Decisiones que conviene explicar

- Valor referencial = `StockActual * PrecioCompra`: representa coste de adquisición del inventario, no ingreso potencial de venta.
- Stock inicial de producto = 0. El stock cambia mediante entradas/salidas para que no existan ajustes invisibles al historial.
- Stock anterior/posterior sigue el orden de registro (Id), aunque una fecha operativa sea anterior. Se rechazan fechas futuras.
- Los rangos de fechas incluyen todo el día final mediante `FechaMovimiento < DATEADD(DAY, 1, @FechaHasta)`.
- El dashboard calcula métricas en SQL Server para que el frontend no duplique reglas ni acumule datos obsoletos.

## 11. 25 preguntas de práctica

1. **¿Por qué se separó el backend en capas?** Para que HTTP, validación, reglas de negocio y persistencia no estén mezclados; cada capa se puede probar por separado.
2. **¿Qué hace APIs?** Recibe la solicitud, aplica dependencias, delega al service y define la respuesta HTTP.
3. **¿Qué hace Schemas?** Valida tipos, campos obligatorios, longitudes, rangos y contratos de entrada/salida.
4. **¿Qué hace Services?** Coordina el caso de uso y aplica reglas de negocio sin conocer HTTP ni SQL.
5. **¿Qué hace Repositories?** Ejecuta SP por el executor, transforma las filas y traduce errores de SQL Server.
6. **¿Por qué no se escribe SQL en Python?** Porque toda persistencia debe centralizarse en SP; además el usuario de API solo necesita permiso EXECUTE.
7. **¿Qué hace `SET NOCOUNT ON`?** Evita mensajes de cantidad de filas que pueden interferir con la lectura de resultados desde pyodbc.
8. **¿Para qué sirve `SET XACT_ABORT ON`?** Para abortar la transacción ante errores de ejecución y no dejar cambios parciales.
9. **¿Qué hace `TRY/CATCH` en un SP de movimiento?** Revierte la transacción con ROLLBACK si falla y vuelve a lanzar el error original.
10. **¿Qué problema evita `UPDLOCK`?** Que dos salidas simultáneas lean el mismo stock y ambas consuman unidades que ya no están disponibles.
11. **¿Cómo se evita stock negativo?** Validación Pydantic, validación del service, comparación con bloqueo en el SP y CHECK en la tabla.
12. **¿Qué significa RN5?** Cada entrada o salida válida agrega un movimiento histórico.
13. **¿Por qué no se puede borrar un movimiento?** Porque el historial es append-only y debe conservar evidencia del inventario.
14. **¿Cómo se cumple RN7?** FK sin cascada, borrado condicionado por SP y desactivación de productos con historial.
15. **¿Qué hace el executor?** Valida el nombre del SP, enlaza los valores con parámetros `?` y devuelve todos los result sets.
16. **¿Por qué `pyodbc` y routers `def`?** pyodbc es síncrono; FastAPI ejecuta funciones `def` en el threadpool.
17. **¿Por qué `autocommit=True`?** Cada SP administra explícitamente sus transacciones; la conexión no debe envolverlas en otra transacción implícita.
18. **¿Cómo se guarda una contraseña?** Como hash Argon2; nunca en texto plano.
19. **¿Qué contiene el JWT?** El subject del usuario, su id y datos de emisión/expiración; va firmado con una clave secreta.
20. **¿Qué rutas no exigen JWT?** `POST /api/v1/auth/login` y `GET /health`; las demás rutas de negocio requieren Bearer token.
21. **¿Qué diferencia hay entre 401, 404, 409 y 422?** 401 no autenticado; 404 no existe; 409 conflicto de negocio; 422 datos inválidos.
22. **¿Qué pasa con un código de producto duplicado?** El SP/índice único lo impide y el repository lo transforma en `CODIGO_DUPLICADO`, HTTP 409.
23. **¿Por qué el dashboard llama un SP?** Para que los indicadores se calculen en el servidor de BD y no queden duplicados en el frontend.
24. **¿Cómo se incluyen los movimientos del día final?** Se usa límite inferior `>= FechaDesde` y límite superior exclusivo `< DATEADD(DAY, 1, FechaHasta)`.
25. **¿Qué queda por verificar antes de sustentar?** Ejecutar el arranque integrado en un equipo con SQL Server 2022 Express local, Python 3.12, Node compatible y ODBC Driver 18; después recorrer los casos de la Definition of Done. La integración Angular con la API ya está implementada en esta entrega.

## 12. Verificación y límites de esta entrega

Verificado en el entorno de construcción:

- `python -m pytest backend/tests -q`: 76 pruebas aprobadas.
- `python -m compileall -q backend/app backend/scripts`: correcto.
- La búsqueda de `SELECT/INSERT/UPDATE/DELETE` inline dentro de `backend/app` no encontró coincidencias.
- JSON de `package.json`, `package-lock.json`, `angular.json` y proxy: válidos; los scripts PowerShell de arranque fueron adaptados a la instancia SQL local.
- Los 37 archivos TypeScript de la aplicación pasaron una transpilación de sintaxis con el compilador TypeScript instalado globalmente.

Limitaciones reales: no estaba instalado SQL Server local ni ODBC Driver 18, el entorno usa Python 3.13.5 en lugar de Python 3.12 y Node 22.16.0 es inferior al mínimo que declaran los paquetes de Angular 22.2.4. Tampoco hubo acceso a npm/PyPI. Por ello no se ejecutó SQL Server ni fue posible completar `npm ci` y `ng build` en este entorno. La transpilación TypeScript comprueba sintaxis, pero no reemplaza el compilador Angular ni la validación de plantillas.

Para la validación integral, ejecutar `Set-ExecutionPolicy -Scope Process Bypass` y `.\run.ps1` en Windows 11 con los prerrequisitos del README. El script compila Angular antes de iniciar la API y la base de datos; si detecta una incompatibilidad, se detiene y muestra el requisito faltante.

