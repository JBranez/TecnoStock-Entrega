import { TestBed } from '@angular/core/testing';
import { provideHttpClient } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { ProductoService } from './producto.service';

describe('ProductoService', () => {
  let service: ProductoService;
  let http: HttpTestingController;

  beforeEach(() => {
    TestBed.configureTestingModule({ providers: [provideHttpClient(), provideHttpClientTesting()] });
    service = TestBed.inject(ProductoService);
    http = TestBed.inject(HttpTestingController);
  });

  afterEach(() => http.verify());

  it('envía búsqueda, categoría y paginación al backend', () => {
    service.list({ search: 'ThinkPad', categoria_id: 2, estado: 'activos', page: 2, page_size: 10 }).subscribe();
    const request = http.expectOne((req) => req.url === '/api/v1/productos');
    expect(request.request.method).toBe('GET');
    expect(request.request.params.get('search')).toBe('ThinkPad');
    expect(request.request.params.get('categoria_id')).toBe('2');
    expect(request.request.params.get('page')).toBe('2');
    request.flush({ items: [], total: 0, page: 2, page_size: 10 });
  });

  it('envía creación del producto con los campos del schema Pydantic', () => {
    const payload = { codigo: 'LAP-001', nombre: 'Laptop', descripcion: null, categoria_id: 2, precio_compra: 100, precio_venta: 130, stock_minimo: 3 };
    service.create(payload).subscribe();
    const request = http.expectOne('/api/v1/productos');
    expect(request.request.method).toBe('POST');
    expect(request.request.body).toEqual(payload);
    request.flush({ id: 1, ...payload, categoria_nombre: 'Laptops', stock_actual: 0, activo: true, fecha_creacion: '2026-01-01T10:00:00', fecha_actualizacion: null });
  });
});
