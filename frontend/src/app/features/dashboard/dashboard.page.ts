import { ChangeDetectionStrategy, Component, inject, signal } from '@angular/core';
import { CurrencyPipe, DatePipe } from '@angular/common';
import { RouterLink } from '@angular/router';
import { form, FormField, validate } from '@angular/forms/signals';
import { forkJoin } from 'rxjs';
import { DashboardService } from '../../core/services/dashboard.service';
import { MovimientoService } from '../../core/services/movimiento.service';
import { ProductoService } from '../../core/services/producto.service';
import { DashboardIndicadores, Movimiento, Producto } from '../../core/models/api.models';
import { ApiError } from '../../core/services/api-error';
import { SectionHeaderComponent } from '../../componentes/header/section-header';

@Component({
  selector: 'app-dashboard-page', standalone: true, imports: [CurrencyPipe, DatePipe, FormField, RouterLink, SectionHeaderComponent],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <app-section-header title="Dashboard" description="Una vista actualizada del estado general de tu inventario." />
    <section class="filter-panel">
      <form class="date-form" novalidate (submit)="applyDates($event)">
        <label>Desde <input type="date" class="control" [formField]="dateForm.desde"></label>
        <label>Hasta <input type="date" class="control" [formField]="dateForm.hasta"></label>
        <button class="button button-dark" type="submit">Aplicar rango</button>
        <button class="button button-light" type="button" (click)="clearDates()">Limpiar</button>
      </form>
      @if (dateError()) { <p class="inline-error">{{ dateError() }}</p> }
    </section>
    @if (error()) { <div class="alert-error" role="alert">{{ error() }}</div> }
    @if (loading()) { <div class="empty">Consultando indicadores de la base de datos…</div> }
    @if (data(); as kpi) {
      <section class="metrics-grid">
        <article class="metric-card"><span>Productos activos</span><strong>{{ kpi.productos_activos }}</strong><small>En el catálogo</small></article>
        <article class="metric-card warning"><span>Productos con stock bajo</span><strong>{{ kpi.productos_stock_bajo }}</strong><small>Igual o inferior al mínimo</small></article>
        <article class="metric-card"><span>Valor referencial</span><strong>{{ kpi.valor_referencial | currency:'PEN':'symbol':'1.2-2':'es-PE' }}</strong><small>Calculado al precio de compra</small></article>
        <article class="metric-card"><span>Movimientos del rango</span><strong>{{ kpi.total_movimientos }}</strong><small>{{ kpi.total_entradas }} entradas · {{ kpi.total_salidas }} salidas</small></article>
      </section>
    }
    <section class="panels">
      <article class="panel">
        <div class="panel-head"><div><p class="eyebrow">ACTIVIDAD</p><h2>Movimientos recientes</h2></div><a routerLink="/historial">Ver historial →</a></div>
        @if (movements().length) {
          <div class="table-wrap"><table><thead><tr><th>Fecha</th><th>Producto</th><th>Tipo</th><th>Cantidad</th><th>Stock</th></tr></thead><tbody>
            @for (movement of movements(); track movement.id) {
              <tr><td>{{ movement.fecha_movimiento | date:'dd/MM/yyyy' }}</td><td><strong>{{ movement.producto_nombre }}</strong><small>{{ movement.producto_codigo }}</small></td><td><span class="pill" [class.out]="movement.tipo_movimiento === 'SALIDA'">{{ movement.tipo_movimiento }}</span></td><td>{{ movement.cantidad }}</td><td>{{ movement.stock_anterior }} → {{ movement.stock_posterior }}</td></tr>
            }
          </tbody></table></div>
        } @else { <div class="empty">No hay movimientos registrados en este rango.</div> }
      </article>
      <article class="panel">
        <div class="panel-head"><div><p class="eyebrow">ATENCIÓN</p><h2>Stock bajo</h2></div><a routerLink="/consultas">Ver todos →</a></div>
        @if (lowStock().length) {
          @for (product of lowStock(); track product.id) {
            <div class="low-row"><div><strong>{{ product.nombre }}</strong><small>{{ product.codigo }} · mínimo {{ product.stock_minimo }}</small></div><b>{{ product.stock_actual }} un.</b></div>
          }
        } @else { <div class="empty">No hay productos por debajo del mínimo.</div> }
      </article>
    </section>
  `,
  styles: [`
    .filter-panel,.panel,.metric-card{border:1px solid var(--line);border-radius:14px;background:#fff;box-shadow:var(--shadow)}.filter-panel{padding:13px 16px;margin-bottom:17px}.date-form{display:flex;gap:12px;align-items:end;flex-wrap:wrap}.date-form label{display:grid;gap:5px;color:var(--ink-muted);font-size:.72rem;font-weight:700}.control{padding:9px 10px;border:1px solid var(--line);border-radius:8px;background:white;font:inherit;color:var(--graphite)}.button{padding:10px 14px;border:0;border-radius:8px;font:inherit;font-size:.78rem;font-weight:750;cursor:pointer}.button-dark{background:var(--graphite);color:white}.button-light{background:#f1f1ea;color:var(--graphite)}.inline-error{margin:8px 0 0;color:#a43d2f;font-size:.78rem}.alert-error{padding:12px;background:#fff3f0;color:#a43d2f;border-radius:9px;margin:12px 0}.metrics-grid{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:14px}.metric-card{padding:19px;display:grid;gap:9px}.metric-card span{color:var(--ink-muted);font-size:.78rem;font-weight:650}.metric-card strong{font-size:clamp(1.4rem,2.4vw,2rem);letter-spacing:-.05em;overflow-wrap:anywhere}.metric-card small,.low-row small{color:var(--ink-muted);font-size:.69rem}.metric-card.warning strong{color:#c26a4c}.panels{display:grid;grid-template-columns:minmax(0,1.35fr) minmax(260px,.85fr);gap:15px;margin-top:18px}.panel{padding:20px;min-width:0}.panel-head{display:flex;align-items:center;justify-content:space-between;gap:10px;margin-bottom:14px}.eyebrow{margin:0 0 5px;color:var(--ink-muted);font-size:.58rem;font-weight:800;letter-spacing:.13em}.panel h2{margin:0;font-size:1.05rem}.panel-head a{font-size:.74rem;color:#68842a;text-decoration:none;font-weight:700}.table-wrap{overflow-x:auto}table{width:100%;border-collapse:collapse;font-size:.76rem}th,td{padding:11px 9px;border-top:1px solid #efeee8;text-align:left;white-space:nowrap}th{color:var(--ink-muted);font-size:.66rem}td small{display:block;color:var(--ink-muted);margin-top:3px}.pill{padding:4px 7px;border-radius:6px;background:#eff5dd;color:#637d25;font-size:.62rem;font-weight:800}.pill.out{background:#fbede8;color:#b86149}.low-row{display:flex;justify-content:space-between;gap:12px;align-items:center;padding:13px 0;border-top:1px solid #efeee8}.low-row div{display:grid;gap:4px;min-width:0}.low-row strong{font-size:.78rem;overflow:hidden;text-overflow:ellipsis}.low-row b{font-size:.8rem;color:#b86149;white-space:nowrap}.empty{padding:20px;color:var(--ink-muted);font-size:.8rem;text-align:center;background:#faf9f5;border-radius:9px}
    @media(max-width:1050px){.metrics-grid{grid-template-columns:repeat(2,minmax(0,1fr))}.panels{grid-template-columns:1fr}}@media(max-width:560px){.metrics-grid{gap:9px}.metric-card{padding:14px}.metric-card strong{font-size:1.35rem}.date-form>*{flex:1 1 42%}.date-form button{flex:1 1 auto}}
  `],
})
export class DashboardPage {
  private readonly dashboard = inject(DashboardService);
  private readonly movementApi = inject(MovimientoService);
  private readonly productApi = inject(ProductoService);
  protected readonly loading = signal(false);
  protected readonly error = signal('');
  protected readonly data = signal<DashboardIndicadores | null>(null);
  protected readonly movements = signal<Movimiento[]>([]);
  protected readonly lowStock = signal<Producto[]>([]);
  protected readonly dateModel = signal({ desde: '', hasta: '' });
  protected readonly dateForm = form(this.dateModel, (p) => {
    validate(p.hasta, ({ value }) => !value() || !this.dateModel().desde || value() >= this.dateModel().desde ? null : { kind: 'date-range', message: 'La fecha final debe ser igual o posterior a la inicial.' });
  });
  protected readonly dateError = () => this.dateForm.hasta().errors()[0]?.message ?? '';

  constructor() { this.load(); }
  protected applyDates(event: Event): void { event.preventDefault(); if (this.dateForm().invalid()) return; this.load(); }
  protected clearDates(): void { this.dateModel.set({ desde: '', hasta: '' }); this.load(); }
  private load(): void {
    this.loading.set(true); this.error.set('');
    const { desde, hasta } = this.dateModel();
    forkJoin({
      indicators: this.dashboard.indicators(desde || undefined, hasta || undefined),
      movements: this.movementApi.list({ fecha_desde: desde || undefined, fecha_hasta: hasta || undefined, page: 1, page_size: 5 }),
      low: this.productApi.listLowStock(),
    }).subscribe({
      next: (result) => { this.data.set(result.indicators); this.movements.set(result.movements.items); this.lowStock.set(result.low.slice(0, 5)); this.loading.set(false); },
      error: (err: unknown) => { this.error.set(ApiError.fromHttp(err).message); this.loading.set(false); },
    });
  }
}
