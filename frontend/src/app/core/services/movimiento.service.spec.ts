import { TestBed } from '@angular/core/testing';
import { provideHttpClient } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { MovimientoService } from './movimiento.service';

describe('MovimientoService', () => {
  let service: MovimientoService;
  let http: HttpTestingController;

  beforeEach(() => {
    TestBed.configureTestingModule({ providers: [provideHttpClient(), provideHttpClientTesting()] });
    service = TestBed.inject(MovimientoService);
    http = TestBed.inject(HttpTestingController);
  });

  afterEach(() => http.verify());

  it('registra una salida con el contrato esperado', () => {
    const payload = { producto_id: 4, cantidad: 3, fecha_movimiento: '2026-10-20', motivo: 'Venta al cliente' };
    service.registerExit(payload).subscribe();
    const request = http.expectOne('/api/v1/movimientos/salidas');
    expect(request.request.method).toBe('POST');
    expect(request.request.body).toEqual(payload);
    request.flush({ id: 12, ...payload, producto_codigo: 'LAP-001', producto_nombre: 'Laptop', tipo_movimiento: 'SALIDA', stock_anterior: 10, stock_posterior: 7, usuario_id: 1, usuario_nombre: 'Administrador', fecha_registro: '2026-10-20T12:00:00' });
  });

  it('envía filtros de rango y producto para el historial', () => {
    service.list({ producto_id: 4, fecha_desde: '2026-10-01', fecha_hasta: '2026-10-31', page: 1, page_size: 15 }).subscribe();
    const request = http.expectOne((req) => req.url === '/api/v1/movimientos');
    expect(request.request.params.get('producto_id')).toBe('4');
    expect(request.request.params.get('fecha_hasta')).toBe('2026-10-31');
    request.flush({ items: [], total: 0, page: 1, page_size: 15 });
  });
});
