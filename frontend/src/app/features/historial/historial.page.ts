import { ChangeDetectionStrategy, Component, inject, signal } from '@angular/core';
import { DatePipe } from '@angular/common';
import { form, FormField, validate } from '@angular/forms/signals';
import { Producto, Movimiento } from '../../core/models/api.models';
import { ProductoService } from '../../core/services/producto.service';
import { MovimientoService } from '../../core/services/movimiento.service';
import { ApiError } from '../../core/services/api-error';
import { SectionHeaderComponent } from '../../componentes/header/section-header';

@Component({
  selector: 'app-historial-page', standalone: true,
  imports: [DatePipe, FormField, SectionHeaderComponent],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <app-section-header title="Historial de movimientos" description="Audita cada entrada y salida con su stock anterior y posterior." />
    <section class="panel filters">
      <form class="filter-form" novalidate (submit)="apply($event)">
        <label>Producto<select class="control" [formField]="filterForm.producto_id"><option value="">Todos los productos</option>@for (product of products(); track product.id) { <option [value]="product.id">{{ product.codigo }} — {{ product.nombre }}</option> }</select></label>
        <label>Desde<input class="control" type="date" [formField]="filterForm.fecha_desde"></label>
        <label>Hasta<input class="control" type="date" [formField]="filterForm.fecha_hasta"></label>
        <label>Tipo<select class="control" [formField]="filterForm.tipo"><option value="">Todos</option><option value="ENTRADA">Entradas</option><option value="SALIDA">Salidas</option></select></label>
        <button class="button button-dark" type="submit">Aplicar filtros</button>
        <button class="button button-light" type="button" (click)="clear()">Limpiar</button>
      </form>
      @if (filterError()) { <p class="inline-error">{{ filterError() }}</p> }
    </section>
    @if (error()) { <div class="alert-error" role="alert">{{ error() }}</div> }
    <section class="panel table-panel">
      <div class="list-head"><h2>Movimientos registrados</h2><span>{{ total() }} resultados</span></div>
      @if (loading()) { <div class="empty">Consultando historial…</div> }
      @else if (!items().length) { <div class="empty">No hay movimientos para los filtros seleccionados.</div> }
      @else {
        <div class="table-wrap"><table><thead><tr><th>Fecha</th><th>Producto</th><th>Tipo</th><th>Cantidad</th><th>Motivo</th><th>Stock anterior</th><th>Stock posterior</th><th>Usuario</th></tr></thead><tbody>
          @for (item of items(); track item.id) {
            <tr><td>{{ item.fecha_movimiento | date:'dd/MM/yyyy' }}</td><td><strong>{{ item.producto_nombre }}</strong><small>{{ item.producto_codigo }}</small></td><td><span class="pill" [class.out]="item.tipo_movimiento === 'SALIDA'">{{ item.tipo_movimiento }}</span></td><td>{{ item.cantidad }}</td><td class="reason">{{ item.motivo }}</td><td>{{ item.stock_anterior }}</td><td><strong>{{ item.stock_posterior }}</strong></td><td>{{ item.usuario_nombre }}</td></tr>
          }
        </tbody></table></div>
      }
      <div class="pagination"><span>Página {{ page() }} de {{ pages() }}</span><div><button class="button button-light" type="button" [disabled]="page() <= 1" (click)="changePage(page()-1)">Anterior</button><button class="button button-light" type="button" [disabled]="page() >= pages()" (click)="changePage(page()+1)">Siguiente</button></div></div>
    </section>
  `,
  styles: [`
    .panel{padding:18px;border:1px solid var(--line);border-radius:14px;background:#fff;box-shadow:var(--shadow);min-width:0}.filters{margin-bottom:15px}.filter-form{display:flex;align-items:end;gap:10px;flex-wrap:wrap}.filter-form label{display:grid;gap:5px;flex:1 1 150px;font-size:.7rem;font-weight:700;color:var(--ink-muted)}.control{width:100%;min-width:0;padding:9px 10px;border:1px solid var(--line);border-radius:8px;background:white;font:inherit;font-size:.78rem;color:var(--graphite)}.button{padding:10px 13px;border:0;border-radius:8px;font:inherit;font-size:.72rem;font-weight:750;cursor:pointer}.button:disabled{opacity:.45}.button-dark{background:var(--graphite);color:white}.button-light{background:#eff0e9;color:var(--graphite)}.inline-error{margin:8px 0 0;color:#a43d2f;font-size:.75rem}.alert-error{margin:12px 0;padding:11px;border-radius:8px;background:#fff1ed;color:#a43d2f;font-size:.8rem}.list-head{display:flex;justify-content:space-between;align-items:center;margin-bottom:12px}.list-head h2{margin:0;font-size:1rem}.list-head span,.pagination span{color:var(--ink-muted);font-size:.72rem}.table-wrap{overflow-x:auto}table{width:100%;min-width:1000px;border-collapse:collapse;font-size:.72rem}th,td{padding:11px 9px;border-top:1px solid #efeee8;text-align:left;white-space:nowrap}th{color:var(--ink-muted);font-size:.65rem}td strong{display:block}td small{display:block;margin-top:3px;color:var(--ink-muted);font-size:.65rem}.pill{padding:5px 7px;border-radius:6px;background:#eff5dd;color:#617b2c;font-size:.61rem;font-weight:800}.pill.out{background:#fbede8;color:#b86149}.reason{max-width:220px;overflow:hidden;text-overflow:ellipsis}.pagination{display:flex;justify-content:space-between;align-items:center;padding-top:14px}.pagination div{display:flex;gap:8px}.empty{padding:25px;text-align:center;background:#faf9f5;border-radius:9px;color:var(--ink-muted);font-size:.8rem}
    @media(max-width:560px){.panel{padding:14px}.filter-form label,.filter-form .button{flex:1 1 100%}.pagination{align-items:flex-start;flex-direction:column;gap:10px}}
  `],
})
export class HistorialPage {
  private readonly productApi = inject(ProductoService);
  private readonly api = inject(MovimientoService);
  protected readonly products = signal<Producto[]>([]);
  protected readonly items = signal<Movimiento[]>([]);
  protected readonly total = signal(0);
  protected readonly page = signal(1);
  protected readonly pageSize = 15;
  protected readonly pages = () => Math.max(1, Math.ceil(this.total() / this.pageSize));
  protected readonly loading = signal(false);
  protected readonly error = signal('');
  protected readonly model = signal({ producto_id: '', fecha_desde: '', fecha_hasta: '', tipo: '' as '' | 'ENTRADA' | 'SALIDA' });
  protected readonly filterForm = form(this.model, (p) => {
    validate(p.fecha_hasta, ({ value }) => !value() || !this.model().fecha_desde || value() >= this.model().fecha_desde ? null : { kind: 'date-range', message: 'La fecha final debe ser igual o posterior a la inicial.' });
  });
  protected readonly filterError = () => this.filterForm.fecha_hasta().errors()[0]?.message ?? '';

  constructor() { this.productApi.list({ estado: 'todos', page: 1, page_size: 100 }).subscribe({ next: (r) => this.products.set(r.items) }); this.load(); }
  protected apply(event: Event): void { event.preventDefault(); if (this.filterForm().invalid()) return; this.page.set(1); this.load(); }
  protected clear(): void { this.model.set({ producto_id: '', fecha_desde: '', fecha_hasta: '', tipo: '' }); this.page.set(1); this.load(); }
  protected changePage(page: number): void { this.page.set(page); this.load(); }
  private load(): void {
    this.loading.set(true); this.error.set(''); const f = this.model();
    this.api.list({ producto_id: f.producto_id ? Number(f.producto_id) : undefined, fecha_desde: f.fecha_desde || undefined, fecha_hasta: f.fecha_hasta || undefined, tipo: f.tipo || undefined, page: this.page(), page_size: this.pageSize }).subscribe({
      next: (r) => { this.items.set(r.items); this.total.set(r.total); this.loading.set(false); },
      error: (e: unknown) => { this.error.set(ApiError.fromHttp(e).message); this.loading.set(false); },
    });
  }
}
