import { TestBed } from '@angular/core/testing';
import { provideHttpClient } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { DashboardService } from './dashboard.service';

describe('DashboardService', () => {
  let service: DashboardService;
  let http: HttpTestingController;

  beforeEach(() => {
    TestBed.configureTestingModule({ providers: [provideHttpClient(), provideHttpClientTesting()] });
    service = TestBed.inject(DashboardService);
    http = TestBed.inject(HttpTestingController);
  });

  afterEach(() => http.verify());

  it('consulta los KPIs del rango de fechas sin valores calculados en Angular', () => {
    service.indicators('2026-10-01', '2026-10-31').subscribe();
    const request = http.expectOne((req) => req.url === '/api/v1/dashboard/indicadores');
    expect(request.request.params.get('fecha_desde')).toBe('2026-10-01');
    expect(request.request.params.get('fecha_hasta')).toBe('2026-10-31');
    request.flush({ productos_activos: 10, productos_stock_bajo: 2, valor_referencial: 1250, total_entradas: 4, total_salidas: 3, total_movimientos: 7, fecha_desde: '2026-10-01', fecha_hasta: '2026-10-31' });
  });
});
