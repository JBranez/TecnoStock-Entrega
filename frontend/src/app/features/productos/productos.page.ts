import { ChangeDetectionStrategy, Component, DestroyRef, inject, signal } from '@angular/core';
import { takeUntilDestroyed, toObservable } from '@angular/core/rxjs-interop';
import { CurrencyPipe } from '@angular/common';
import { RouterLink } from '@angular/router';
import { form, FormField, maxLength, submit } from '@angular/forms/signals';
import { debounceTime, distinctUntilChanged, firstValueFrom, map } from 'rxjs';
import { Categoria, Producto } from '../../core/models/api.models';
import { CategoriaService } from '../../core/services/categoria.service';
import { ProductoService } from '../../core/services/producto.service';
import { ApiError } from '../../core/services/api-error';
import { ToastService } from '../../core/services/toast.service';
import { SectionHeaderComponent } from '../../componentes/header/section-header';

@Component({
  selector: 'app-productos-page', standalone: true, imports: [CurrencyPipe, RouterLink, FormField, SectionHeaderComponent],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <app-section-header title="Productos" description="Administra el catálogo, los precios y los niveles de inventario." />
    <section class="panel filters">
      <form class="filter-form" novalidate (submit)="applyFilters($event)">
        <label class="search">Buscar por código o nombre<input class="control" placeholder="Ej. LAP-0142 o Lenovo" [formField]="filterForm.search"></label>
        <label>Categoría<select class="control" [formField]="filterForm.categoria_id"><option value="">Todas</option>@for (category of categories(); track category.id) { <option [value]="category.id">{{ category.nombre }}</option> }</select></label>
        <label>Estado<select class="control" [formField]="filterForm.estado"><option value="activos">Activos</option><option value="inactivos">Inactivos</option><option value="todos">Todos</option></select></label>
        <button class="button button-dark" type="submit">Filtrar</button>
        <a class="button button-accent" routerLink="/productos/nuevo">+ Nuevo producto</a>
      </form>
    </section>
    @if (error()) { <div class="alert-error" role="alert">{{ error() }}</div> }
    <section class="panel table-panel">
      <div class="list-head"><h2>Catálogo</h2><span>{{ total() }} registros</span></div>
      @if (loading()) { <div class="empty">Consultando productos…</div> }
      @else if (!items().length) { <div class="empty">No se encontraron productos con esos filtros.</div> }
      @else {
        <div class="table-wrap"><table><thead><tr><th>Producto</th><th>Categoría</th><th>Compra</th><th>Venta</th><th>Stock</th><th>Estado</th><th>Acciones</th></tr></thead><tbody>
          @for (product of items(); track product.id) {
            <tr><td><strong>{{ product.nombre }}</strong><small>{{ product.codigo }}</small></td><td>{{ product.categoria_nombre }}</td><td>{{ product.precio_compra | currency:'PEN':'symbol':'1.2-2':'es-PE' }}</td><td>{{ product.precio_venta | currency:'PEN':'symbol':'1.2-2':'es-PE' }}</td><td><span class="stock" [class.low]="product.stock_actual <= product.stock_minimo" [class.empty-stock]="product.stock_actual === 0">{{ product.stock_actual }} <small>/ mín. {{ product.stock_minimo }}</small></span></td><td><span class="state" [class.inactive]="!product.activo">{{ product.activo ? 'Activo' : 'Inactivo' }}</span></td><td><div class="actions"><a class="small-action" [routerLink]="['/productos', product.id, 'editar']">Editar</a><button class="small-action" type="button" (click)="details.set(product)">Ver</button><button class="small-action" type="button" (click)="toggleStatus(product)">{{ product.activo ? 'Desactivar' : 'Activar' }}</button><button class="small-action danger" type="button" (click)="askDelete(product)">Eliminar</button></div></td></tr>
          }
        </tbody></table></div>
      }
      <div class="pagination"><span>Página {{ page() }} de {{ pages() }}</span><div><button class="button button-light" type="button" [disabled]="page() <= 1" (click)="changePage(page()-1)">Anterior</button><button class="button button-light" type="button" [disabled]="page() >= pages()" (click)="changePage(page()+1)">Siguiente</button></div></div>
    </section>
    @if (details(); as product) {
      <div class="confirm-backdrop"><section class="confirm-box details-box" role="dialog" aria-modal="true" aria-label="Detalle del producto"><h2>{{ product.nombre }}</h2><p class="detail-code">{{ product.codigo }} · {{ product.categoria_nombre }}</p><div class="detail-grid"><span>Descripción</span><strong>{{ product.descripcion || 'Sin descripción' }}</strong><span>Precio compra</span><strong>{{ product.precio_compra | currency:'PEN':'symbol':'1.2-2':'es-PE' }}</strong><span>Precio venta</span><strong>{{ product.precio_venta | currency:'PEN':'symbol':'1.2-2':'es-PE' }}</strong><span>Stock actual / mínimo</span><strong>{{ product.stock_actual }} / {{ product.stock_minimo }}</strong><span>Estado</span><strong>{{ product.activo ? 'Activo' : 'Inactivo' }}</strong></div><div class="actions"><button class="button button-light" type="button" (click)="details.set(null)">Cerrar</button></div></section></div>
    }
    @if (pendingAction(); as action) {
      <div class="confirm-backdrop"><section class="confirm-box" role="dialog" aria-modal="true"><h2>{{ action.kind === 'delete' ? 'Eliminar producto' : (action.product.activo ? 'Desactivar producto' : 'Activar producto') }}</h2><p>{{ action.kind === 'delete' ? 'El producto solo puede eliminarse físicamente si no tiene movimientos. Si tiene historial, deberás desactivarlo.' : '¿Confirmas el cambio de estado de este producto?' }} <strong>{{ action.product.nombre }}</strong></p><div class="actions"><button class="button button-light" type="button" (click)="pendingAction.set(null)">Cancelar</button><button class="button button-danger" type="button" [disabled]="saving()" (click)="confirmAction()">Confirmar</button></div></section></div>
    }
  `,
  styles: [`
    .panel{padding:17px 19px;border:1px solid var(--line);border-radius:14px;background:white;box-shadow:var(--shadow);min-width:0}.filters{margin-bottom:15px}.filter-form{display:flex;align-items:end;gap:10px;flex-wrap:wrap}.filter-form label{display:grid;gap:5px;color:var(--ink-muted);font-size:.7rem;font-weight:700}.search{flex:1 1 220px}.control{min-width:140px;padding:9px 10px;border:1px solid var(--line);border-radius:8px;background:white;font:inherit;font-size:.8rem;color:var(--graphite)}.search .control{width:100%}.button{display:inline-flex;justify-content:center;align-items:center;padding:10px 13px;border:0;border-radius:8px;font:inherit;font-size:.74rem;font-weight:750;text-decoration:none;cursor:pointer}.button:disabled{opacity:.45;cursor:not-allowed}.button-dark{background:var(--graphite);color:#fff}.button-accent{background:var(--acid);color:var(--graphite)}.button-light{background:#f0f1e9;color:var(--graphite)}.table-panel{padding-bottom:12px}.list-head{display:flex;justify-content:space-between;align-items:center;margin-bottom:12px}.list-head h2{margin:0;font-size:1rem}.list-head span,.pagination span{color:var(--ink-muted);font-size:.72rem}.table-wrap{overflow-x:auto}table{width:100%;border-collapse:collapse;min-width:830px;font-size:.75rem}th,td{padding:12px 10px;border-top:1px solid #efeee8;text-align:left;white-space:nowrap}th{color:var(--ink-muted);font-size:.66rem;font-weight:750}td strong{display:block}td small{display:block;margin-top:4px;color:var(--ink-muted);font-size:.66rem}.stock{font-weight:800;color:#617b2c}.stock.low{color:#c06b4c}.stock.empty-stock{color:#b33c31}.stock small{display:inline;color:var(--ink-muted);font-weight:500}.state{padding:5px 7px;border-radius:6px;background:#eff5dd;color:#617b2c;font-size:.65rem;font-weight:750}.state.inactive{background:#eff0f0;color:#727b80}.actions{display:flex;gap:8px}.small-action{padding:0;border:0;background:none;color:#64812a;font:inherit;font-size:.69rem;font-weight:750;text-decoration:none;cursor:pointer}.small-action.danger{color:#b24e3c}.pagination{display:flex;justify-content:space-between;align-items:center;padding-top:14px}.pagination div{display:flex;gap:8px}.alert-error{margin:12px 0;padding:11px;border-radius:8px;background:#fff1ed;color:#a43d2f;font-size:.8rem}.empty{padding:25px;text-align:center;background:#faf9f5;border-radius:9px;color:var(--ink-muted);font-size:.8rem}.confirm-backdrop{position:fixed;inset:0;z-index:20;display:grid;place-items:center;padding:18px;background:#111a20a8}.confirm-box{width:min(100%,430px);padding:23px;border-radius:15px;background:white}.confirm-box h2{margin:0 0 10px}.confirm-box p{color:var(--ink-muted);font-size:.84rem;line-height:1.5}.confirm-box .actions{justify-content:flex-end;margin-top:18px}.details-box{max-height:85vh;overflow:auto}.detail-code{margin:0;color:var(--ink-muted);font-size:.78rem}.detail-grid{display:grid;grid-template-columns:1fr 1.4fr;gap:10px;padding:17px 0}.detail-grid span{color:var(--ink-muted);font-size:.74rem}.detail-grid strong{font-size:.78rem}
    @media(max-width:560px){.panel{padding:14px}.filter-form label,.filter-form .button{flex:1 1 100%}.control{width:100%}.pagination{align-items:flex-start;gap:10px;flex-direction:column}}
  `],
})
export class ProductosPage {
  private readonly destroyRef = inject(DestroyRef);
  private readonly toast = inject(ToastService);
  private readonly api = inject(ProductoService);
  private readonly categoryApi = inject(CategoriaService);
  protected readonly items = signal<Producto[]>([]);
  protected readonly categories = signal<Categoria[]>([]);
  protected readonly total = signal(0);
  protected readonly page = signal(1);
  protected readonly pageSize = 10;
  protected readonly loading = signal(false);
  protected readonly saving = signal(false);
  protected readonly error = signal('');
  protected readonly pendingAction = signal<{ kind: 'delete' | 'status'; product: Producto } | null>(null);
  protected readonly details = signal<Producto | null>(null);
  protected readonly filterModel = signal({ search: '', categoria_id: '', estado: 'activos' as 'activos' | 'inactivos' | 'todos' });
  protected readonly filterForm = form(this.filterModel, (p) => { maxLength(p.search, 120, { message: 'Máximo 120 caracteres.' }); });
  protected readonly pages = () => Math.max(1, Math.ceil(this.total() / this.pageSize));

  constructor() {
    this.categoryApi.list().pipe(takeUntilDestroyed(this.destroyRef)).subscribe({
      next: (items) => this.categories.set(items),
      error: (e: unknown) => this.error.set(ApiError.fromHttp(e).message),
    });
    // Espera 300 ms tras la última edición para no enviar una petición por tecla.
    toObservable(this.filterModel).pipe(
      debounceTime(300),
      distinctUntilChanged((a, b) => a.search === b.search && a.categoria_id === b.categoria_id && a.estado === b.estado),
      takeUntilDestroyed(this.destroyRef),
    ).subscribe(() => {
      this.page.set(1);
      this.load();
    });
  }
  protected applyFilters(event: Event): void { event.preventDefault(); this.page.set(1); this.load(); }
  protected changePage(value: number): void { this.page.set(value); this.load(); }
  private load(): void {
    this.loading.set(true); this.error.set(''); const filters = this.filterModel();
    this.api.list({ search: filters.search.trim() || undefined, categoria_id: filters.categoria_id ? Number(filters.categoria_id) : undefined, estado: filters.estado, page: this.page(), page_size: this.pageSize }).subscribe({
      next: (result) => { this.items.set(result.items); this.total.set(result.total); this.loading.set(false); },
      error: (e: unknown) => { this.error.set(ApiError.fromHttp(e).message); this.loading.set(false); },
    });
  }
  protected toggleStatus(product: Producto): void { this.pendingAction.set({ kind: 'status', product }); }
  protected askDelete(product: Producto): void { this.pendingAction.set({ kind: 'delete', product }); }
  protected confirmAction(): void {
    const action = this.pendingAction(); if (!action) return;
    this.saving.set(true);
    const request = action.kind === 'delete'
      ? this.api.delete(action.product.id).pipe(map(() => void 0))
      : this.api.changeStatus(action.product.id, !action.product.activo).pipe(map(() => void 0));
    request.subscribe({ next: () => { this.pendingAction.set(null); this.load(); this.saving.set(false); this.toast.success(action.kind === 'delete' ? 'Producto eliminado' : 'Estado actualizado', 'El catálogo se consultó nuevamente desde la API.'); }, error: (e: unknown) => { this.error.set(ApiError.fromHttp(e).message); this.pendingAction.set(null); this.saving.set(false); } });
  }
}
