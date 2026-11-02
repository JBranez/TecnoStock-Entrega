import { ChangeDetectionStrategy, Component, computed, inject, signal } from '@angular/core';
import { CurrencyPipe } from '@angular/common';
import { ActivatedRoute } from '@angular/router';
import { toObservable } from '@angular/core/rxjs-interop';
import { debounceTime, distinctUntilChanged, firstValueFrom, map, switchMap } from 'rxjs';
import { form, FormField, maxLength, min, required, submit, validate } from '@angular/forms/signals';
import { Producto, Movimiento } from '../../core/models/api.models';
import { ProductoService } from '../../core/services/producto.service';
import { MovimientoService } from '../../core/services/movimiento.service';
import { ApiError } from '../../core/services/api-error';
import { ToastService } from '../../core/services/toast.service';
import { FieldErrorComponent } from '../../shared/field-error.component';
import { SectionHeaderComponent } from '../../componentes/header/section-header';

@Component({
  selector: 'app-movimientos-page', standalone: true,
  imports: [CurrencyPipe, FormField, FieldErrorComponent, SectionHeaderComponent],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <app-section-header title="Movimientos" description="Registra entradas y salidas; cada operación actualiza el stock y el historial." />
    <section class="panel">
      <div class="tabs"><button type="button" [class.active]="mode() === 'ENTRADA'" (click)="setMode('ENTRADA')">＋ Registrar entrada</button><button type="button" [class.active]="mode() === 'SALIDA'" (click)="setMode('SALIDA')">− Registrar salida</button></div>
      @if (error()) { <div class="alert-error" role="alert">{{ error() }}</div> }
      <form class="movement-form" novalidate (submit)="save($event)">
        <div class="field full"><label for="product-search">Buscar producto activo</label><input id="product-search" class="control" [formField]="searchForm.term" placeholder="Código o nombre del producto"><small class="hint">La búsqueda consulta el catálogo activo de la API.</small></div>
        <div class="field full"><label for="producto">Producto *</label><select id="producto" class="control" [formField]="movementForm.producto_id"><option value="">Selecciona un producto</option>@for (product of products(); track product.id) { <option [value]="product.id">{{ product.codigo }} — {{ product.nombre }} (stock: {{ product.stock_actual }})</option> }</select><app-field-error [errors]="movementForm.producto_id().errors()" [visible]="movementForm.producto_id().touched()" /></div>
        @if (selectedProduct(); as product) {
          <div class="product-summary full"><div><span>Stock actual</span><strong>{{ product.stock_actual }}</strong></div><div><span>Stock mínimo</span><strong>{{ product.stock_minimo }}</strong></div><div><span>Precio de compra</span><strong>{{ product.precio_compra | currency:'PEN':'symbol':'1.2-2':'es-PE' }}</strong></div></div>
        }
        <div class="field"><label for="cantidad">Cantidad *</label><input id="cantidad" class="control" type="number" step="1" [formField]="movementForm.cantidad"><app-field-error [errors]="movementForm.cantidad().errors()" [visible]="movementForm.cantidad().touched()" />
          @if (mode() === 'SALIDA' && selectedProduct()) { <small class="hint">Máximo disponible: {{ selectedProduct()!.stock_actual }} unidades.</small> }
        </div>
        <div class="field"><label for="fecha">Fecha del movimiento *</label><input id="fecha" class="control" type="date" [formField]="movementForm.fecha_movimiento"><app-field-error [errors]="movementForm.fecha_movimiento().errors()" [visible]="movementForm.fecha_movimiento().touched()" /></div>
        <div class="field full"><label for="motivo">Motivo *</label><textarea id="motivo" class="control" rows="3" [formField]="movementForm.motivo" placeholder="Ej. Compra a proveedor / Venta al cliente"></textarea><app-field-error [errors]="movementForm.motivo().errors()" [visible]="movementForm.motivo().touched()" /></div>
        <div class="form-actions full"><button class="button button-dark" type="submit" [disabled]="saving()">{{ saving() ? 'Registrando…' : mode() === 'ENTRADA' ? 'Registrar entrada' : 'Registrar salida' }}</button></div>
      </form>
    </section>
    @if (lastMovement(); as movement) {
      <section class="result-panel"><div><p class="eyebrow">MOVIMIENTO REGISTRADO</p><h2>{{ movement.tipo_movimiento }} · {{ movement.producto_nombre }}</h2><p>{{ movement.motivo }}</p></div><div class="stock-change"><span>Stock anterior</span><strong>{{ movement.stock_anterior }}</strong><span>Stock posterior</span><strong>{{ movement.stock_posterior }}</strong></div></section>
    }
  `,
  styles: [`
    .panel,.result-panel{padding:21px;border:1px solid var(--line);border-radius:14px;background:white;box-shadow:var(--shadow)}.tabs{display:flex;gap:8px;border-bottom:1px solid var(--line);padding-bottom:13px;margin-bottom:18px}.tabs button{padding:10px 14px;border:0;border-radius:8px;background:#f1f2ec;color:#697278;font:inherit;font-size:.78rem;font-weight:750;cursor:pointer}.tabs button.active{background:var(--graphite);color:white}.movement-form{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:16px}.field{display:grid;align-content:start;gap:7px}.field label{font-size:.76rem;font-weight:750}.full{grid-column:1/-1}.control{width:100%;padding:11px;border:1px solid var(--line);border-radius:8px;background:white;font:inherit;font-size:.82rem}.control:focus{outline:2px solid #b7e34b70;border-color:#96b83e}.hint{color:var(--ink-muted);font-size:.68rem}.product-summary{display:grid;grid-template-columns:repeat(3,1fr);gap:10px;padding:13px;border-radius:9px;background:#f6f7ef}.product-summary div{display:grid;gap:5px}.product-summary span,.stock-change span{color:var(--ink-muted);font-size:.67rem}.product-summary strong{font-size:1.05rem}.button{padding:11px 17px;border:0;border-radius:8px;background:var(--graphite);color:#fff;font:inherit;font-size:.78rem;font-weight:750;cursor:pointer}.button:disabled{opacity:.5;cursor:not-allowed}.form-actions{display:flex;justify-content:flex-end}.alert-error{margin-bottom:14px;padding:11px;border-radius:8px;background:#fff1ed;color:#a43d2f;font-size:.8rem}.result-panel{display:flex;align-items:center;justify-content:space-between;gap:18px;margin-top:16px;border-color:#dbe8bf;background:#fbfdf6}.eyebrow{margin:0 0 5px;color:#72834b;font-size:.6rem;font-weight:800;letter-spacing:.13em}.result-panel h2{margin:0;font-size:1.03rem}.result-panel p:not(.eyebrow){margin:7px 0 0;color:var(--ink-muted);font-size:.75rem}.stock-change{display:grid;grid-template-columns:auto auto;align-items:center;gap:7px 15px}.stock-change strong{font-size:1.1rem}
    @media(max-width:620px){.panel{padding:16px}.movement-form{grid-template-columns:1fr}.full{grid-column:auto}.product-summary{grid-template-columns:1fr 1fr}.result-panel{align-items:flex-start;flex-direction:column}.form-actions button{width:100%}}
  `],
})
export class MovimientosPage {
  private readonly productApi = inject(ProductoService);
  private readonly movementApi = inject(MovimientoService);
  private readonly toast = inject(ToastService);
  private readonly route = inject(ActivatedRoute);
  protected readonly mode = signal<'ENTRADA' | 'SALIDA'>('ENTRADA');
  protected readonly products = signal<Producto[]>([]);
  protected readonly saving = signal(false);
  protected readonly error = signal('');
  protected readonly lastMovement = signal<Movimiento | null>(null);
  protected readonly searchModel = signal({ term: '' });
  protected readonly searchForm = form(this.searchModel, (p) => { maxLength(p.term, 120); });
  protected readonly model = signal({ producto_id: '', cantidad: 1, fecha_movimiento: this.todayLocal(), motivo: '' });
  protected readonly selectedProduct = computed(() => this.products().find((p) => p.id === Number(this.model().producto_id)) ?? null);
  protected readonly movementForm = form(this.model, (p) => {
    required(p.producto_id, { message: 'Selecciona un producto.' });
    required(p.cantidad, { message: 'La cantidad es obligatoria.' }); min(p.cantidad, 1, { message: 'La cantidad debe ser mayor que cero.' });
    validate(p.cantidad, ({ value }) => Number.isInteger(value()) ? null : { kind: 'integer', message: 'La cantidad debe ser un número entero.' });
    required(p.fecha_movimiento, { message: 'La fecha es obligatoria.' });
    validate(p.fecha_movimiento, ({ value }) => value() <= this.todayLocal() ? null : { kind: 'future-date', message: 'La fecha no puede ser futura.' });
    required(p.motivo, { message: 'El motivo es obligatorio.' }); maxLength(p.motivo, 200, { message: 'Máximo 200 caracteres.' });
    validate(p.motivo, ({ value }) => value().trim().length > 0 ? null : { kind: 'required', message: 'El motivo no puede contener solo espacios.' });
    validate(p.cantidad, ({ value }) => {
      const selected = this.selectedProduct();
      if (this.mode() === 'SALIDA' && selected && Number(value()) > selected.stock_actual) return { kind: 'stock', message: `Stock insuficiente. Disponible: ${selected.stock_actual}.` };
      return null;
    });
  });

  private todayLocal(): string {
    const now = new Date();
    const month = String(now.getMonth() + 1).padStart(2, '0');
    const day = String(now.getDate()).padStart(2, '0');
    return `${now.getFullYear()}-${month}-${day}`;
  }

  constructor() {
    const productId = Number(this.route.snapshot.queryParamMap.get('producto_id'));
    if (productId > 0) this.model.update((v) => ({ ...v, producto_id: String(productId) }));
    toObservable(this.searchModel).pipe(
      map((value) => value.term.trim()), debounceTime(300), distinctUntilChanged(),
      switchMap((term) => this.productApi.list({ search: term || undefined, estado: 'activos', page: 1, page_size: 100 })),
    ).subscribe({ next: (result) => this.products.set(result.items), error: (e: unknown) => this.error.set(ApiError.fromHttp(e).message) });
  }
  protected setMode(mode: 'ENTRADA' | 'SALIDA'): void { this.mode.set(mode); this.error.set(''); }
  protected save(event: Event): void {
    event.preventDefault(); this.error.set(''); this.lastMovement.set(null);
    submit(this.movementForm, async () => {
      this.saving.set(true);
      try {
        const value = this.model();
        const payload = { producto_id: Number(value.producto_id), cantidad: value.cantidad, fecha_movimiento: value.fecha_movimiento, motivo: value.motivo.trim() };
        const request = this.mode() === 'ENTRADA' ? this.movementApi.registerEntry(payload) : this.movementApi.registerExit(payload);
        const result = await firstValueFrom(request);
        this.lastMovement.set(result);
        this.toast.success(this.mode() === 'ENTRADA' ? 'Entrada registrada' : 'Salida registrada', `Stock actualizado: ${result.stock_anterior} → ${result.stock_posterior}.`);
        this.model.set({ ...value, producto_id: '', cantidad: 1, motivo: '' });
        this.searchModel.set({ term: '' });
        const products = await firstValueFrom(this.productApi.list({ estado: 'activos', page: 1, page_size: 100 }));
        this.products.set(products.items);
      } catch (e) { this.error.set(ApiError.fromHttp(e).message); }
      finally { this.saving.set(false); }
    });
  }
}
