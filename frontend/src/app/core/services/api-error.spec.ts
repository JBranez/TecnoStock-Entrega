import { HttpErrorResponse } from '@angular/common/http';
import { ApiError } from './api-error';

describe('ApiError', () => {
  it('maps a backend business error into a readable client error', () => {
    const error = new HttpErrorResponse({
      status: 409,
      error: { code: 'STOCK_INSUFICIENTE', detail: 'Stock disponible: 4.', errors: [] },
    });
    const result = ApiError.fromHttp(error);
    expect(result.status).toBe(409);
    expect(result.code).toBe('STOCK_INSUFICIENTE');
    expect(result.message).toContain('Stock disponible: 4');
  });

  it('incluye los errores de campos devueltos por Pydantic', () => {
    const error = new HttpErrorResponse({ status: 422, error: { code: 'DATOS_INVALIDOS', detail: 'Revisa los datos enviados.', errors: [{ field: 'precio_compra', message: 'El precio debe ser mayor que cero.' }] } });
    const result = ApiError.fromHttp(error);
    expect(result.message).toContain('precio_compra');
    expect(result.message).toContain('mayor que cero');
    expect(result.fieldErrors).toHaveLength(1);
  });

  it('reports when the API is unreachable', () => {
    const result = ApiError.fromHttp(new HttpErrorResponse({ status: 0 }));
    expect(result.message).toContain('No se pudo conectar con la API');
  });
});
