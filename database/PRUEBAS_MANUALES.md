# Pruebas manuales de procedimientos almacenados

Ejecuta estas pruebas en SSMS, Azure Data Studio o la extensión MSSQL de VS Code después de correr `python backend/scripts/init_db.py` y `python backend/scripts/seed.py`. Los ejemplos suponen una base recién creada, donde el usuario demo y los primeros productos tienen Id 1; en una base con datos previos, consulta primero los Id con los procedimientos de listado y reemplázalos.

## 1. Catálogos y productos

```sql
EXEC dbo.usp_Categoria_Listar;
EXEC dbo.usp_Producto_Listar
    @Busqueda = NULL,
    @CategoriaId = NULL,
    @Estado = N'activos',
    @Pagina = 1,
    @TamanoPagina = 10;
EXEC dbo.usp_Producto_ListarStockBajo;
```

El listado de productos devuelve dos result sets: el primer resultado contiene el total filtrado y el segundo las filas de la página. El segundo incluye también `COUNT(*) OVER()`.

## 2. Entrada, salida válida y salida rechazada

```sql
EXEC dbo.usp_Movimiento_RegistrarEntrada
    @ProductoId = 1, @Cantidad = 10,
    @FechaMovimiento = '2026-11-02',
    @Motivo = N'Prueba manual de entrada', @UsuarioId = 1;

EXEC dbo.usp_Movimiento_RegistrarSalida
    @ProductoId = 1, @Cantidad = 3,
    @FechaMovimiento = '2026-11-02',
    @Motivo = N'Prueba manual de salida', @UsuarioId = 1;

/* Debe lanzar STOCK_INSUFICIENTE y no cambiar stock ni historial. */
EXEC dbo.usp_Movimiento_RegistrarSalida
    @ProductoId = 1, @Cantidad = 999999,
    @FechaMovimiento = '2026-11-02',
    @Motivo = N'Prueba de stock insuficiente', @UsuarioId = 1;
```

La fecha del ejemplo se debe reemplazar por la fecha actual o una anterior si se ejecuta después del 2 de noviembre de 2026.

## 3. Historial e indicadores

```sql
EXEC dbo.usp_Movimiento_Listar
    @ProductoId = 1, @FechaDesde = '2026-11-01', @FechaHasta = '2026-11-30',
    @Tipo = NULL, @Pagina = 1, @TamanoPagina = 20;

EXEC dbo.usp_Dashboard_ObtenerIndicadores
    @FechaDesde = '2026-11-01', @FechaHasta = '2026-11-30';
```

`FechaHasta` es inclusiva: internamente se compara con `< DATEADD(DAY, 1, @FechaHasta)`.

## 4. Reglas que se deben observar

- Cantidad cero o negativa: `DATOS_INVALIDOS`.
- Cantidad mayor al stock: `STOCK_INSUFICIENTE` (409 en HTTP).
- Producto inactivo: `PRODUCTO_INACTIVO`.
- Fecha futura: `DATOS_INVALIDOS`.
- El registro de movimiento y el cambio del stock están dentro de una sola transacción; el SP revierte ambos ante un error.
- Una salida adquiere `UPDLOCK` en la fila del producto. Dos salidas concurrentes se serializan en esa fila y no pueden gastar el mismo stock.
- Los movimientos no tienen procedimientos de actualización ni eliminación.
