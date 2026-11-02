import { ChangeDetectionStrategy, Component, inject, signal } from '@angular/core';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
import { form, FormField, maxLength, min, pattern, required, submit, validate } from '@angular/forms/signals';
import { firstValueFrom } from 'rxjs';
import { Categoria, Producto, ProductoPayload } from '../../core/models/api.models';
import { CategoriaService } from '../../core/services/categoria.service';
import { ProductoService } from '../../core/services/producto.service';
import { ApiError } from '../../core/services/api-error';
import { ToastService } from '../../core/services/toast.service';
import { FieldErrorComponent } from '../../shared/field-error.component';
import { SectionHeaderComponent } from '../../componentes/header/section-header';

@Component({
  selector: 'app-producto-form-page', standalone: true,
  imports: [FormField, FieldErrorComponent, RouterLink, SectionHeaderComponent],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <app-section-header [title]="productId ? 'Editar producto' : 'Nuevo producto'" description="Registra la información comercial y los niveles de inventario." />
    @if (error()) { <div class="alert-error" role="alert">{{ error() }}</div> }
    @if (loading()) { <div class="empty">Cargando información del producto…</div> }
    @else {
      <section class="panel">
        <form class="form-grid" novalidate (submit)="save($event)">
          <div class="field"><label for="codigo">Código *</label><input id="codigo" class="control" [formField]="productForm.codigo" placeholder="LAP-0001" autocomplete="off"><app-field-error [errors]="productForm.codigo().errors()" [visible]="productForm.codigo().touched()" /></div>
          <div class="field"><label for="nombre">Nombre *</label><input id="nombre" class="control" [formField]="productForm.nombre" placeholder="Nombre comercial"><app-field-error [errors]="productForm.nombre().errors()" [visible]="productForm.nombre().touched()" /></div>
          <div class="field full"><label for="descripcion">Descripción</label><textarea id="descripcion" class="control" rows="3" [formField]="productForm.descripcion" placeholder="Detalles del producto"></textarea><app-field-error [errors]="productForm.descripcion().errors()" [visible]="productForm.descripcion().touched()" /></div>
          <div class="field"><label for="categoria">Categoría *</label><select id="categoria" class="control" [formField]="productForm.categoria_id"><option value="">Selecciona una categoría</option>@for (category of categories(); track category.id) { <option [value]="category.id">{{ category.nombre }}</option> }</select><app-field-error [errors]="productForm.categoria_id().errors()" [visible]="productForm.categoria_id().touched()" /></div>
          <div class="field"><label for="compra">Precio de compra (S/) *</label><input id="compra" class="control" inputmode="decimal" [formField]="productForm.precio_compra" placeholder="0.00"><app-field-error [errors]="productForm.precio_compra().errors()" [visible]="productForm.precio_compra().touched()" /></div>
          <div class="field"><label for="venta">Precio de venta (S/) *</label><input id="venta" class="control" inputmode="decimal" [formField]="productForm.precio_venta" placeholder="0.00"><app-field-error [errors]="productForm.precio_venta().errors()" [visible]="productForm.precio_venta().touched()" /></div>
          <div class="field"><label for="minimo">Stock mínimo *</label><input id="minimo" class="control" type="number" step="1" [formField]="productForm.stock_minimo"><app-field-error [errors]="productForm.stock_minimo().errors()" [visible]="productForm.stock_minimo().touched()" /></div>
          @if (currentProduct(); as product) { <div class="stock-note full">Existencias actuales: <strong>{{ product.stock_actual }}</strong>. El stock solo se modifica registrando entradas o salidas.</div> }
          <div class="form-actions full"><a class="button button-light" routerLink="/productos">Volver</a><button class="button button-dark" type="submit" [disabled]="saving()">{{ saving() ? 'Guardando…' : productId ? 'Guardar cambios' : 'Crear producto' }}</button></div>
        </form>
      </section>
    }
  `,
  styles: [`
    .panel{padding:24px;border:1px solid var(--line);border-radius:14px;background:white;box-shadow:var(--shadow)}.form-grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:17px}.field{display:grid;align-content:start;gap:7px}.field label{font-size:.76rem;font-weight:750;color:#536066}.control{width:100%;padding:11px 12px;border:1px solid var(--line);border-radius:8px;font:inherit;font-size:.83rem;background:white;color:var(--graphite)}.control:focus{outline:2px solid #b7e34b70;border-color:#96b83e}.full{grid-column:1/-1}.stock-note{padding:11px 13px;border-radius:8px;background:#f5f6ee;color:#5d6a52;font-size:.78rem}.form-actions{display:flex;justify-content:flex-end;gap:9px;padding-top:8px}.button{padding:11px 16px;border:0;border-radius:8px;font:inherit;font-size:.78rem;font-weight:750;text-decoration:none;cursor:pointer}.button:disabled{opacity:.5;cursor:not-allowed}.button-dark{background:var(--graphite);color:#fff}.button-light{background:#eff0e9;color:var(--graphite)}.alert-error{margin-bottom:14px;padding:11px;border-radius:8px;background:#fff1ed;color:#a43d2f;font-size:.8rem}.empty{padding:24px;text-align:center;color:var(--ink-muted)}
    @media(max-width:650px){.panel{padding:17px}.form-grid{grid-template-columns:1fr}.full{grid-column:auto}.form-actions{justify-content:stretch}.form-actions>*{flex:1;text-align:center}}
  `],
})
export class ProductoFormPage {
  private readonly route = inject(ActivatedRoute);
  private readonly router = inject(Router);
  private readonly categoryApi = inject(CategoriaService);
  private readonly api = inject(ProductoService);
  private readonly toast = inject(ToastService);
  protected readonly productId = Number(this.route.snapshot.paramMap.get('id')) || null;
  protected readonly categories = signal<Categoria[]>([]);
  protected readonly currentProduct = signal<Producto | null>(null);
  protected readonly loading = signal(!!this.productId);
  protected readonly saving = signal(false);
  protected readonly error = signal('');
  protected readonly model = signal({ codigo: '', nombre: '', descripcion: '', categoria_id: '', precio_compra: '', precio_venta: '', stock_minimo: 0 });
  protected readonly productForm = form(this.model, (p) => {
    required(p.codigo, { message: 'El código es obligatorio.' });
    maxLength(p.codigo, 30, { message: 'Máximo 30 caracteres.' });
    pattern(p.codigo, /^[A-Za-z0-9][A-Za-z0-9._-]*$/, { message: 'Usa letras, números, punto, guion o guion bajo; sin espacios.' });
    required(p.nombre, { message: 'El nombre es obligatorio.' }); maxLength(p.nombre, 120, { message: 'Máximo 120 caracteres.' });
    validate(p.nombre, ({ value }) => value().trim().length > 0 ? null : { kind: 'required', message: 'El nombre no puede contener solo espacios.' });
    maxLength(p.descripcion, 500, { message: 'Máximo 500 caracteres.' });
    required(p.categoria_id, { message: 'Selecciona una categoría.' });
    required(p.precio_compra, { message: 'El precio de compra es obligatorio.' });
    pattern(p.precio_compra, /^\d+(\.\d{1,2})?$/, { message: 'Usa un número con máximo 2 decimales.' });
    validate(p.precio_compra, ({ value }) => Number(value()) > 0 ? null : { kind: 'min', message: 'El precio de compra debe ser mayor que cero.' });
    required(p.precio_venta, { message: 'El precio de venta es obligatorio.' });
    pattern(p.precio_venta, /^\d+(\.\d{1,2})?$/, { message: 'Usa un número con máximo 2 decimales.' });
    validate(p.precio_venta, ({ value }) => Number(value()) > 0 ? null : { kind: 'min', message: 'El precio de venta debe ser mayor que cero.' });
    required(p.stock_minimo, { message: 'El stock mínimo es obligatorio.' }); min(p.stock_minimo, 0, { message: 'El stock mínimo no puede ser negativo.' });
    validate(p.stock_minimo, ({ value }) => Number.isInteger(value()) ? null : { kind: 'integer', message: 'El stock mínimo debe ser un número entero.' });
  });

  constructor() {
    this.categoryApi.list().subscribe({ next: (items) => this.categories.set(items), error: (e: unknown) => this.error.set(ApiError.fromHttp(e).message) });
    if (this.productId) this.api.get(this.productId).subscribe({
      next: (p) => { this.currentProduct.set(p); this.model.set({ codigo: p.codigo, nombre: p.nombre, descripcion: p.descripcion ?? '', categoria_id: String(p.categoria_id), precio_compra: String(p.precio_compra), precio_venta: String(p.precio_venta), stock_minimo: p.stock_minimo }); this.loading.set(false); },
      error: (e: unknown) => { this.error.set(ApiError.fromHttp(e).message); this.loading.set(false); },
    });
  }

  protected save(event: Event): void {
    event.preventDefault(); this.error.set('');
    submit(this.productForm, async () => {
      this.saving.set(true);
      try {
        const value = this.model();
        const payload: ProductoPayload = { codigo: value.codigo.trim().toUpperCase(), nombre: value.nombre.trim(), descripcion: value.descripcion.trim() || null, categoria_id: Number(value.categoria_id), precio_compra: Number(value.precio_compra), precio_venta: Number(value.precio_venta), stock_minimo: value.stock_minimo };
        if (!Number.isInteger(payload.stock_minimo)) throw new Error('El stock mínimo debe ser un número entero.');
        if (this.productId) {
          await firstValueFrom(this.api.update(this.productId, payload));
          this.toast.success('Producto actualizado', 'El catálogo se consultará nuevamente al volver a la lista.');
        } else {
          await firstValueFrom(this.api.create(payload));
          this.toast.success('Producto creado', 'El producto ya está registrado en el inventario.');
        }
        await this.router.navigateByUrl('/productos');
      } catch (e) { this.error.set(ApiError.fromHttp(e).message); }
      finally { this.saving.set(false); }
    });
  }
}
