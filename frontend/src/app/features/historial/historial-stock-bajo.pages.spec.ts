import { TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { of } from 'rxjs';
import { HistorialPage } from './historial.page';
import { StockBajoPage } from '../stock-bajo/stock-bajo.page';
import { ProductoService } from '../../core/services/producto.service';
import { MovimientoService } from '../../core/services/movimiento.service';

describe('Pantallas de historial y stock bajo', () => {
  it('muestra el estado vacío del historial consultado a la API', async () => {
    await TestBed.configureTestingModule({
      imports: [HistorialPage],
      providers: [
        provideRouter([]),
        { provide: ProductoService, useValue: { list: () => of({ items: [], total: 0, page: 1, page_size: 100 }) } },
        { provide: MovimientoService, useValue: { list: () => of({ items: [], total: 0, page: 1, page_size: 15 }) } },
      ],
    }).compileComponents();
    const fixture = TestBed.createComponent(HistorialPage);
    fixture.detectChanges();
    expect(fixture.nativeElement.textContent).toContain('No hay movimientos');
  });

  it('muestra el estado vacío de stock bajo sin inventar productos', async () => {
    await TestBed.configureTestingModule({
      imports: [StockBajoPage],
      providers: [provideRouter([]), { provide: ProductoService, useValue: { listLowStock: () => of([]) } }],
    }).compileComponents();
    const fixture = TestBed.createComponent(StockBajoPage);
    fixture.detectChanges();
    expect(fixture.nativeElement.textContent).toContain('no hay productos con stock bajo');
  });
});
