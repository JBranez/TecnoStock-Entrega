import { TestBed } from '@angular/core/testing';
import { provideHttpClient } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { CategoriaService } from './categoria.service';

describe('CategoriaService', () => {
  let service: CategoriaService;
  let http: HttpTestingController;

  beforeEach(() => {
    TestBed.configureTestingModule({ providers: [provideHttpClient(), provideHttpClientTesting()] });
    service = TestBed.inject(CategoriaService);
    http = TestBed.inject(HttpTestingController);
  });

  afterEach(() => http.verify());

  it('consulta las categorías del backend sin usar datos locales', () => {
    let result = null as unknown;
    service.list().subscribe((value) => result = value);
    const request = http.expectOne('/api/v1/categorias');
    expect(request.request.method).toBe('GET');
    request.flush([{ id: 2, nombre: 'Monitores', descripcion: null, fecha_creacion: '2026-01-01T10:00:00' }]);
    expect(result).toEqual([expect.objectContaining({ id: 2, nombre: 'Monitores' })]);
  });

  it('envía el contrato de creación al endpoint', () => {
    let completed = false;
    service.create({ nombre: 'Redes', descripcion: null }).subscribe(() => completed = true);
    const request = http.expectOne('/api/v1/categorias');
    expect(request.request.method).toBe('POST');
    expect(request.request.body).toEqual({ nombre: 'Redes', descripcion: null });
    request.flush({ id: 5, nombre: 'Redes', descripcion: null, fecha_creacion: '2026-01-01T10:00:00' });
    expect(completed).toBe(true);
  });
});
