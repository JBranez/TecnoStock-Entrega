# Decisiones y supuestos de TecnoStock

Este documento registra las decisiones que completan la especificación cuando esta no fija un detalle. La guía maestra sigue siendo la fuente de verdad.

## Supuestos iniciales (Fase 0)

1. **Se conserva la base visual recibida.** El navbar, los estilos y la identidad gráfica se mantienen; el dashboard de demostración fue sustituido por una vista alimentada desde la API.
2. **El frontend recibido era una base parcial.** La revisión inicial encontró un dashboard con datos de demostración y páginas provisionales. En la integración final se añadieron login, servicios HTTP, Signal Forms, guards, interceptores y pantallas conectadas; se retiraron las vistas demo y los placeholders.
3. **Contrato HTTP.** La API tendrá prefijo `/api/v1`, correrá localmente en el puerto `8000` y el frontend la consumirá desde `environment.apiUrl`.
4. **Valor referencial del inventario.** Se calculará usando `StockActual * PrecioCompra`, porque representa el costo de adquisición de las existencias y no un ingreso potencial de venta.
5. **Indicador de movimientos.** La tarjeta adicional que existe en el dashboard visual mostrará el total de entradas más salidas del rango seleccionado. El backend conservará también ambos totales por separado para no perder detalle.
6. **Orden del historial.** `StockAnterior` y `StockPosterior` reflejarán el orden de registro (Id); `FechaMovimiento` es la fecha operativa y no permite fechas futuras. Esto evita reescribir el stock histórico cuando se registra una operación con fecha anterior.
7. **Base de datos local.** SQL Server 2022 Express se instala directamente en Windows como instancia `SQLEXPRESS`. Se habilita Mixed Mode y TCP/IP en el puerto fijo `1433`; el inicializador usa `sa` solo para bootstrap y FastAPI utiliza `tecnostock_app`.
8. **Adaptación de modelos.** Los modelos de API seguirán los nombres y campos del dominio definidos en la guía; los componentes Angular podrán adaptar esos DTO a sus modelos de presentación, sin hardcodear datos de negocio.

## Decisiones de seguridad y arquitectura

- La API se conectará con `DB_APP_USER`, nunca con `sa`; `sa` se reserva para inicialización administrativa.
- La persistencia se realizará exclusivamente mediante procedimientos almacenados. El executor validará los nombres de SP antes de ejecutarlos.
- `pyodbc` es síncrono; por ello los routers usarán funciones `def`, una conexión por request y `autocommit=True`. Cada SP que modifique inventario administrará su propia transacción.
- El historial de movimientos será append-only: no se expondrán endpoints de edición ni eliminación.
- El token se guardará en `sessionStorage`; se elige por limitar su persistencia al ciclo de la pestaña/sesión. No evita XSS, por lo que se debe mantener una política estricta de no insertar HTML no confiable.

## Alternativas descartadas

- **ORM:** no se utilizará SQLAlchemy ni otro ORM; complicaría la explicación y contradiría el requisito de persistencia por SP.
- **Ejecución local de servicios.** SQL Server, FastAPI y Angular se ejecutan como procesos/servicios locales de Windows; no se añade infraestructura de contenedores ni ORMs.
- **Borrado físico como operación normal:** no se utiliza para productos con movimientos; se desactivan para preservar el historial.

## Decisiones de base de datos (Fases 1–2)

9. **Contadores de paginación.** Los SP de productos y movimientos devuelven un primer result set con el total filtrado y un segundo con las filas paginadas. El SELECT de filas incluye también `COUNT(*) OVER()` como metadato de la página; el primer result set conserva el total cuando una página solicitada queda fuera del conjunto de resultados.
10. **Permisos del usuario de API.** `tecnostock_app` recibe `GRANT EXECUTE` en el esquema `dbo` y `DENY SELECT, INSERT, UPDATE, DELETE` en ese esquema. Los SP y las tablas comparten el propietario `dbo`, por lo que SQL Server aplica ownership chaining al ejecutar los procedimientos.
11. **Inicialización segura.** `init_db.py` solo lee las credenciales desde los `.env` locales, separa lotes `GO` y sustituye marcadores para nombre de base, usuario y contraseña con escape de identificadores/literales. Los scripts son repetibles mediante `IF NOT EXISTS` y `CREATE OR ALTER`.
12. **Errores de unicidad en carreras concurrentes.** Los procedimientos verifican duplicados para entregar códigos legibles. Las restricciones UNIQUE siguen siendo la autoridad ante dos solicitudes simultáneas; la capa Repository también traduce los errores SQL Server 2601/2627 según el procedimiento invocado.
13. **Prueba de persistencia manual.** `database/PRUEBAS_MANUALES.md` conserva llamadas `EXEC` reproducibles para catálogos, productos, movimientos, historial e indicadores. Los Id de ejemplo se ajustan si se ejecuta sobre una base con datos anteriores.
14. **Indicadores agregados en base de datos.** `usp_Dashboard_ObtenerIndicadores` devuelve productos activos, stock bajo, valor referencial, entradas, salidas y movimientos totales. La API solo transporta esos valores; no recalcula métricas de negocio.
15. **Dashboard inicial.** Si no se envía un rango, los contadores de movimientos son históricos acumulados. Al recibir fechas, se filtran ambas puntas y la fecha final se convierte en límite exclusivo del día siguiente.
16. **Stock actual solo cambia mediante movimientos.** Los schemas y SP de creación/edición del producto no aceptan `StockActual`. Se evita así alterar existencias sin dejar registro histórico.
17. **Pruebas ejecutables sin SQL Server.** Tests de services usan repositorios falsos y tests HTTP reemplazan dependencias; las restricciones, SP y transacciones se verifican adicionalmente con tests estáticos y pruebas manuales documentadas. No sustituyen una prueba real de integración en SQL Server.
18. **Entorno de ejecución de esta entrega.** El contenedor de construcción tiene Python 3.13.5, no Python 3.12, y el acceso a PyPI está bloqueado; no fue posible instalar `pyodbc`/`pwdlib` ni generar un `pip freeze` reproducible. Se mantiene `pwdlib[argon2]` en requirements para el entorno objetivo y un adaptador Argon2id alternativo solo para poder ejecutar pruebas aisladas en este contenedor.
19. **Conexión protegida antes de abrir BD.** La dependencia `get_protected_db` valida presencia y firma del JWT antes de conectar. Una solicitud sin token recibe 401 incluso cuando SQL Server está fuera de línea; así no se confunde falta de autenticación con indisponibilidad de BD.
20. **Health check sin consulta inline.** `/health` llama al SP de indicadores para demostrar que la conexión y el esquema responden sin introducir una excepción a la regla de persistencia mediante procedimientos.

## Integración frontend-backend

- Se conserva la identidad visual original (grafito, verde lima e ivory) para no reemplazar el frontend recibido. Se incorpora Bootstrap 5.3.8 y Bootstrap Icons 1.13.2 como CSS, sin cargar JavaScript de Bootstrap; los formularios, confirmaciones y navegación se resuelven con Angular y Signals.
- En desarrollo `environment.ts` usa `/api/v1` y Angular CLI proxy (`proxy.conf.json`) redirige `/api` y `/health` a FastAPI en `localhost:8000`. Así el navegador mantiene un origen único durante el desarrollo. En producción el hosting debe enrutar `/api` hacia FastAPI; no se incorpora infraestructura de despliegue porque está fuera del alcance.
- Los contratos TypeScript conservan los nombres `snake_case` de Pydantic para evitar capas de traducción innecesarias.
- El token se guarda en `sessionStorage` como exige la guía. No se agregan refresh tokens ni autenticación compleja.
- Los listados se re-consultan tras alta, edición, activación/desactivación y movimientos para reflejar el estado real de SQL Server.
- La búsqueda de productos para movimientos usa consulta HTTP con debounce de 300 ms, no un catálogo hardcodeado.

21. **Proxy local de API.** Angular usa `environment.apiUrl = '/api/v1'` y `proxy.conf.json` reenvía `/api` y `/health` a `http://localhost:8000`. Esto evita duplicar URLs de infraestructura y simplifica CORS en desarrollo sin añadir un servidor proxy adicional.
22. **Formularios Signal Forms en todas las pantallas con entrada.** Login, alta/edición, filtros, historial y movimientos usan `form()`, `FormField` y validadores. Los datos iniciales permanecen en signals; no se usan Reactive Forms ni Template-driven Forms.
23. **Refresco desde el backend.** Después de crear/editar/eliminar, cambiar estado o registrar movimientos, los componentes vuelven a consultar las rutas de lectura. No mantienen arrays de negocio como fuente de verdad; SQL Server sigue siendo la autoridad.
24. **Avisos desacoplados.** `ToastService` concentra notificaciones temporales de éxito, error e información para evitar duplicar la presentación en cada feature. Los errores de formulario se mantienen además junto al formulario o en su alerta correspondiente.
25. **Arranque de un comando en Windows.** `setup.ps1` genera secretos locales solo cuando no existen y solicita la contraseña real de `sa` configurada en la instancia local. `run.ps1` valida el servicio SQL Server, el puerto TCP, Python, Node y ODBC; instala dependencias, compila Angular, inicializa BD/seed, corre tests y abre ambos servidores. La instalación del motor, Python, Node y ODBC se realiza manualmente para que el usuario acepte licencias y permisos.
26. **Publicación honesta en GitHub.** El ZIP no incluye `.git` ni un bundle de historial. `publish-github.ps1` puede crear un commit único de importación del estado actual y publicar el repositorio mediante GitHub CLI. No recrea una cronología ni genera PRs automáticamente; las ramas y PRs siguientes deben corresponder a cambios reales.

27. **Navegación responsive.** El sidebar se mantiene fijo en escritorio y se transforma en un drawer off-canvas con fondo atenuado y signal de apertura en móvil; se conserva la navegación horizontal del contenido sin sobrecargar las páginas.
28. **Gestor de paquetes oficial.** Se normalizaron los `resolved` del lockfile al registro `registry.npmjs.org` para evitar depender de un mirror de terceros.
29. **Pruebas del cliente.** Los tests Angular se prepararon para el runner Vitest incluido por Angular CLI y se ejecutan en el flujo `run.ps1` antes de inicializar la base de datos.
30. **Errores de validación del backend en formularios.** `ApiError` conserva el arreglo `errors` de Pydantic y agrega sus nombres/mensajes al detalle para que los errores 422 sigan siendo visibles en el formulario incluso cuando no se asignan dinámicamente a un campo Signal Forms.
31. **Envío con formulario inválido.** Los botones de submit se mantienen habilitados mientras no exista una solicitud en curso; Signal Forms `submit()` marca los campos como touched y bloquea el callback si hay errores, evitando que el usuario se quede sin poder revelar mensajes.


32. **Instalación local de SQL Server.** Se sustituye el método de base de datos anterior por SQL Server 2022 Express instalado en Windows. Se conserva el motor, el esquema, los SP, las credenciales mínimas de la API y las transacciones; solo cambia el aprovisionamiento y la forma de iniciar/verificar el motor. `DB_SERVICE_NAME` identifica el servicio de Windows y `DB_PORT` determina el puerto TCP local.
33. **Contraseña administrativa local.** `MSSQL_SA_PASSWORD` debe coincidir con la contraseña que el usuario asignó al login `sa` durante la instalación. `setup.ps1` la solicita de forma oculta y no la genera, ya que la instancia local ya existe.
