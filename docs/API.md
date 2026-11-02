# API TecnoStock

**Base URL local:** `http://localhost:8000/api/v1`  
**Documentación interactiva:** `http://localhost:8000/docs`  
**Autenticación:** JWT Bearer en todas las rutas `/api/v1`, salvo `POST /auth/login`. `/health` es público.

Los errores siguen el formato `{ "code": "...", "detail": "...", "errors": [] }`. Los errores de validación HTTP 422 incluyen `errors` con `field` y `message`. Las respuestas GET de la API llevan `Cache-Control: no-store`.

## Endpoints

| Método | Ruta | Autenticación | Resultado |
|---|---|---|---|
| POST | `/auth/login` | No | JWT y usuario autenticado |
| GET | `/auth/me` | Sí | Usuario actual |
| GET | `/categorias` | Sí | Lista de categorías |
| POST | `/categorias` | Sí | Crea categoría (201) |
| GET | `/categorias/{category_id}` | Sí | Detalle de categoría |
| PUT | `/categorias/{category_id}` | Sí | Actualiza categoría |
| DELETE | `/categorias/{category_id}` | Sí | Elimina si no tiene productos; 409 si está en uso |
| GET | `/productos` | Sí | Filtros `search`, `categoria_id`, `estado`, `page`, `page_size` |
| POST | `/productos` | Sí | Crea producto (201) |
| GET | `/productos/{product_id}` | Sí | Detalle de producto |
| PUT | `/productos/{product_id}` | Sí | Actualiza catálogo sin modificar stock actual |
| PATCH | `/productos/{product_id}/estado` | Sí | Activa/desactiva mediante `{ "activo": true }` |
| DELETE | `/productos/{product_id}` | Sí | Elimina solo si no hay movimientos; 409 si tiene historial |
| GET | `/productos/stock-bajo` | Sí | Productos activos con stock <= mínimo |
| POST | `/movimientos/entradas` | Sí | Registra entrada y devuelve stock anterior/posterior (201) |
| POST | `/movimientos/salidas` | Sí | Registra salida; 409 si el stock no alcanza |
| GET | `/movimientos` | Sí | Filtros `producto_id`, `fecha_desde`, `fecha_hasta`, `tipo`, `page`, `page_size` |
| GET | `/dashboard/indicadores` | Sí | Indicadores y totales de movimientos por rango |
| GET | `/health` | No | Comprueba API y conexión por un SP |

## Contratos principales

### Producto

```json
{
  "codigo": "LAP-0142",
  "nombre": "Laptop Lenovo ThinkPad E14",
  "descripcion": "Portátil empresarial",
  "categoria_id": 1,
  "precio_compra": 2650.00,
  "precio_venta": 3199.00,
  "stock_minimo": 3
}
```

El stock inicial es cero. Para aumentar o disminuir existencias siempre se registra un movimiento; una edición de catálogo nunca sobrescribe `StockActual`.

### Movimiento de entrada/salida

```json
{
  "producto_id": 1,
  "cantidad": 10,
  "fecha_movimiento": "2026-11-02",
  "motivo": "Compra a proveedor"
}
```

La salida se registra en `/movimientos/salidas`. El usuarioId no lo envía el cliente: se extrae del JWT validado.

### Indicadores

`GET /dashboard/indicadores?fecha_desde=2026-11-01&fecha_hasta=2026-11-30` devuelve productos activos, productos con stock bajo, valor referencial a precio de compra, entradas, salidas y total de movimientos. La fecha final se incluye completa.

## Convenciones

- Los importes se entregan como números JSON con dos decimales; los cálculos y parámetros se conservan como `Decimal` en Python.
- Las fechas son ISO 8601. Las fechas de movimientos no pueden ser futuras.
- `estado` de productos acepta `activos`, `inactivos` o `todos`.
- `tipo` del historial acepta `ENTRADA` o `SALIDA`.
- La paginación empieza en 1 y admite tamaños de 1 a 100.
- Los movimientos no tienen operaciones PUT ni DELETE: su historial es inmutable.

## Adaptación al frontend recibido

La base Angular original tiene navegación a `/productos`, `/categorias`, `/movimientos`, `/historial` y `/consultas`, pero sus páginas funcionales y servicios HTTP aún no estaban incluidos en el ZIP. El backend queda publicado en `/api/v1`; la integración de Angular debe crear servicios tipados que adapten `codigo`, `categoria_nombre`, `stock_actual` y demás DTO a los nombres de presentación que utilice cada componente. El dashboard de demo se debe sustituir por `/dashboard/indicadores`, `/productos/stock-bajo` y `/movimientos`.
