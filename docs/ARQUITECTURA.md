# Arquitectura de TecnoStock

## Capas del backend

```mermaid
flowchart TB
    C[Angular 22 / HttpClient] -->|HTTP + JWT| API[APIs · routers FastAPI]
    API --> SC[Schemas · Pydantic v2]
    API --> SV[Services · reglas y orquestación]
    SV --> RP[Repositories · mapeo de resultados]
    RP --> EX[DB Executor · pyodbc]
    EX -->|EXEC dbo.usp_*| SQL[(SQL Server 2022)]
```

- **APIs:** rutas, dependencias, autorización y códigos HTTP. No conoce SQL ni reglas del inventario.
- **Schemas:** contratos de entrada/salida y validación estructural.
- **Services:** reglas de negocio y coordinación de operaciones.
- **Repositories:** invoca SP mediante el executor y convierte resultados/errores de BD en datos o excepciones de dominio.
- **DB Executor:** único punto Python que ejecuta procedimientos almacenados.

## Secuencia implementada: registrar una salida

```mermaid
sequenceDiagram
    actor U as Usuario
    participant F as Angular
    participant A as API Router
    participant S as Service
    participant R as Repository
    participant E as Executor
    participant D as SQL Server / SP
    U->>F: Envía producto, cantidad, fecha y motivo
    F->>A: POST /api/v1/movimientos/salidas + JWT
    A->>S: Valida identidad y delega
    S->>R: Solicita registrar salida con usuario_id
    R->>E: Ejecuta dbo.usp_Movimiento_RegistrarSalida
    E->>D: EXEC con parámetros enlazados
    D->>D: Bloquea stock, valida, actualiza e inserta en una transacción
    D-->>E: Devuelve movimiento o error de negocio
    E-->>R: Resultado del procedimiento
    R-->>S: Dict o excepción de dominio
    S-->>A: Movimiento registrado
    A-->>F: HTTP 201 / error normalizado
    F->>A: Reconsulta productos e historial
```

La transacción, `UPDLOCK`, `XACT_ABORT` y las restricciones de la BD protegen la consistencia entre stock e historial ante operaciones concurrentes o fallidas. La pantalla de Movimientos ya utiliza esta secuencia mediante `MovimientoService`.

## Implementación actual

- `GET /health` prueba disponibilidad de SQL Server a través de `dbo.usp_Dashboard_ObtenerIndicadores`; no ejecuta una consulta SQL directa desde el router.
- `POST /api/v1/auth/login` es la única ruta de la API versionada sin JWT. Las demás rutas validan el token y consultan que el usuario siga activo.
- Cada request autenticado comparte una conexión síncrona `pyodbc` a través de dependencias FastAPI. Se cierra al terminar el request. El cursor se cierra dentro del executor.
- La conexión usa `autocommit=True`; los procedimientos de movimientos son responsables de abrir, confirmar y revertir sus transacciones.
- Los result sets de paginación son leídos en orden: total filtrado y después filas de la página. El executor no conoce las entidades; solo traduce columnas a diccionarios.

## Cliente Angular conectado

```mermaid
flowchart TB
    R[Angular Router] --> G[authGuard / guestGuard]
    G --> P[Standalone feature pages]
    P --> SF[Signal Forms]
    P --> AS[Angular services]
    AS --> HI[HttpClient]
    HI --> AI[auth.interceptor]
    HI --> EI[error.interceptor]
    AI --> API[FastAPI /api/v1]
```

Cada feature page usa modelos de `core/models` y servicios tipados de `core/services`. Después de las operaciones de escritura vuelve a consultar su endpoint de listado; el frontend no conserva un catálogo local de productos o categorías. La búsqueda por código/nombre y el typeahead de movimientos aplican debounce de 300 ms; los avisos se centralizan en `ToastService`.
