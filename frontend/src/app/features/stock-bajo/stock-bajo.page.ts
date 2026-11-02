import { ChangeDetectionStrategy, Component, inject, signal } from '@angular/core';
import { CurrencyPipe } from '@angular/common';
import { RouterLink } from '@angular/router';
import { Producto } from '../../core/models/api.models';
import { ProductoService } from '../../core/services/producto.service';
import { ApiError } from '../../core/services/api-error';
import { SectionHeaderComponent } from '../../componentes/header/section-header';

@Component({
  selector: 'app-stock-bajo-page', standalone: true, imports: [CurrencyPipe, RouterLink, SectionHeaderComponent],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <app-section-header title="Stock bajo" description="Productos activos cuyo stock actual alcanzó o cayó por debajo del mínimo." />
    @if (error()) { <div class="alert-error" role="alert">{{ error() }}</div> }
    <section class="panel">
      <div class="panel-head"><h2>Productos que requieren atención</h2><span class="count">{{ products().length }}</span></div>
      @if (loading()) { <div class="empty">Consultando niveles de stock…</div> }
      @else if (!products().length) { <div class="empty">Excelente: no hay productos con stock bajo.</div> }
      @else {
        <div class="table-wrap"><table><thead><tr><th>Producto</th><th>Categoría</th><th>Stock actual</th><th>Stock mínimo</th><th>Precio de compra</th><th>Acción</th></tr></thead><tbody>
          @for (product of products(); track product.id) {
            <tr><td><strong>{{ product.nombre }}</strong><small>{{ product.codigo }}</small></td><td>{{ product.categoria_nombre }}</td><td><b class="critical">{{ product.stock_actual }}</b></td><td>{{ product.stock_minimo }}</td><td>{{ product.precio_compra | currency:'PEN':'symbol':'1.2-2':'es-PE' }}</td><td><a class="button" [routerLink]="['/movimientos']" [queryParams]="{ producto_id: product.id }">Registrar entrada</a></td></tr>
          }
        </tbody></table></div>
      }
    </section>
  `,
  styles: [`
    .panel{padding:20px;border:1px solid var(--line);border-radius:14px;background:white;box-shadow:var(--shadow)}.panel-head{display:flex;justify-content:space-between;align-items:center;margin-bottom:15px}.panel-head h2{margin:0;font-size:1rem}.count{padding:5px 9px;border-radius:7px;background:#fbede8;color:#b86149;font-size:.78rem;font-weight:800}.table-wrap{overflow-x:auto}table{width:100%;min-width:720px;border-collapse:collapse;font-size:.75rem}th,td{padding:12px 10px;border-top:1px solid #efeee8;text-align:left;white-space:nowrap}th{color:var(--ink-muted);font-size:.66rem}td strong{display:block}td small{display:block;margin-top:3px;color:var(--ink-muted);font-size:.65rem}.critical{color:#ba6047}.button{display:inline-block;padding:8px 10px;border-radius:7px;background:var(--graphite);color:white;font-size:.69rem;font-weight:750;text-decoration:none}.empty{padding:25px;text-align:center;background:#faf9f5;color:var(--ink-muted);border-radius:9px;font-size:.8rem}.alert-error{margin:12px 0;padding:11px;border-radius:8px;background:#fff1ed;color:#a43d2f;font-size:.8rem}
    @media(max-width:560px){.panel{padding:14px}}
  `],
})
export class StockBajoPage {
  private readonly api = inject(ProductoService);
  protected readonly products = signal<Producto[]>([]);
  protected readonly loading = signal(false);
  protected readonly error = signal('');
  constructor() { this.load(); }
  private load(): void { this.loading.set(true); this.api.listLowStock().subscribe({ next: (r) => { this.products.set(r); this.loading.set(false); }, error: (e: unknown) => { this.error.set(ApiError.fromHttp(e).message); this.loading.set(false); } }); }
}
