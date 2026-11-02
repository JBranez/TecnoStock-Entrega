import { ChangeDetectionStrategy, Component, inject, signal } from '@angular/core';
import { form, FormField, maxLength, minLength, required, submit, validate } from '@angular/forms/signals';
import { firstValueFrom } from 'rxjs';
import { Categoria } from '../../core/models/api.models';
import { CategoriaService } from '../../core/services/categoria.service';
import { ApiError } from '../../core/services/api-error';
import { ToastService } from '../../core/services/toast.service';
import { FieldErrorComponent } from '../../shared/field-error.component';
import { SectionHeaderComponent } from '../../componentes/header/section-header';

@Component({
  selector: 'app-categorias-page', standalone: true, imports: [FormField, FieldErrorComponent, SectionHeaderComponent],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <app-section-header title="Categorías" description="Organiza los productos por familias y características." />
    <div class="columns">
      <section class="panel">
        <div class="panel-head"><h2>{{ editingId() ? 'Editar categoría' : 'Nueva categoría' }}</h2>@if (editingId()) { <button class="text-button" type="button" (click)="reset()">Cancelar edición</button> }</div>
        @if (error()) { <div class="alert-error" role="alert">{{ error() }}</div> }
        <form novalidate (submit)="save($event)">
          <label for="nombre">Nombre *</label><input id="nombre" class="control" [formField]="categoryForm.nombre" placeholder="Ej. Laptops">
          <app-field-error [errors]="categoryForm.nombre().errors()" [visible]="categoryForm.nombre().touched()" />
          <label for="descripcion">Descripción</label><textarea id="descripcion" class="control" rows="3" [formField]="categoryForm.descripcion" placeholder="Descripción breve"></textarea>
          <app-field-error [errors]="categoryForm.descripcion().errors()" [visible]="categoryForm.descripcion().touched()" />
          <button class="button button-dark" type="submit" [disabled]="saving()">{{ saving() ? 'Guardando…' : editingId() ? 'Guardar cambios' : 'Crear categoría' }}</button>
        </form>
      </section>
      <section class="panel">
        <div class="panel-head"><h2>Categorías registradas</h2><span class="counter">{{ categories().length }}</span></div>
        @if (loading()) { <div class="empty">Cargando categorías…</div> }
        @else if (!categories().length) { <div class="empty">Todavía no hay categorías registradas.</div> }
        @else {
          @for (category of categories(); track category.id) {
            <article class="category-row"><div><strong>{{ category.nombre }}</strong><p>{{ category.descripcion || 'Sin descripción' }}</p></div><div class="actions"><button class="button button-light" type="button" (click)="edit(category)">Editar</button><button class="button button-danger" type="button" (click)="askDelete(category)">Eliminar</button></div></article>
          }
        }
      </section>
    </div>
    @if (pendingDelete(); as target) {
      <div class="confirm-backdrop"><section class="confirm-box" role="dialog" aria-modal="true" aria-label="Confirmar eliminación"><h2>Eliminar categoría</h2><p>¿Deseas eliminar <strong>{{ target.nombre }}</strong>? No se podrá eliminar si tiene productos asociados.</p><div class="actions"><button class="button button-light" type="button" (click)="pendingDelete.set(null)">Cancelar</button><button class="button button-danger" type="button" [disabled]="saving()" (click)="remove()">Confirmar eliminación</button></div></section></div>
    }
  `,
  styles: [`
    .columns{display:grid;grid-template-columns:minmax(270px,.8fr) minmax(0,1.2fr);gap:16px}.panel{padding:21px;border:1px solid var(--line);border-radius:14px;background:white;box-shadow:var(--shadow);min-width:0}.panel-head{display:flex;justify-content:space-between;align-items:center;gap:10px;margin-bottom:18px}.panel h2{margin:0;font-size:1rem}form{display:grid;gap:8px}label{margin-top:8px;font-size:.75rem;font-weight:700;color:#5e696e}.control{width:100%;padding:10px 11px;border:1px solid var(--line);border-radius:8px;font:inherit;font-size:.83rem;resize:vertical}.control:focus{outline:2px solid #b7e34b70;border-color:#96b83e}.button{padding:9px 12px;border:0;border-radius:8px;font:inherit;font-size:.74rem;font-weight:750;cursor:pointer}.button:disabled{opacity:.5;cursor:not-allowed}.button-dark{margin-top:10px;background:var(--graphite);color:white}.button-light{background:#f0f1e9;color:var(--graphite)}.button-danger{background:#fff0ed;color:#ad4e3b}.text-button{border:0;background:none;color:#668229;font-size:.75rem;cursor:pointer}.counter{padding:5px 9px;border-radius:7px;background:#eff4e3;color:#668229;font-size:.7rem;font-weight:800}.category-row{display:flex;justify-content:space-between;align-items:center;gap:12px;padding:14px 0;border-top:1px solid #efeee8}.category-row strong{font-size:.84rem}.category-row p{margin:5px 0 0;color:var(--ink-muted);font-size:.73rem}.actions{display:flex;gap:7px;flex-wrap:wrap}.alert-error{padding:10px;border-radius:8px;background:#fff1ed;color:#a43d2f;font-size:.78rem}.empty{padding:25px;text-align:center;border-radius:9px;background:#faf9f5;color:var(--ink-muted);font-size:.8rem}.confirm-backdrop{position:fixed;inset:0;z-index:20;display:grid;place-items:center;padding:18px;background:#111a20a8}.confirm-box{width:min(100%,430px);padding:23px;border-radius:15px;background:white;box-shadow:0 20px 70px #0003}.confirm-box h2{margin:0 0 10px}.confirm-box p{color:var(--ink-muted);font-size:.85rem;line-height:1.5}.confirm-box .actions{justify-content:flex-end;margin-top:18px}
    @media(max-width:850px){.columns{grid-template-columns:1fr}}@media(max-width:520px){.panel{padding:16px}.category-row{align-items:flex-start;flex-direction:column}.actions{width:100%}}
  `],
})
export class CategoriasPage {
  private readonly api = inject(CategoriaService);
  private readonly toast = inject(ToastService);
  protected readonly categories = signal<Categoria[]>([]);
  protected readonly loading = signal(false);
  protected readonly saving = signal(false);
  protected readonly error = signal('');
  protected readonly editingId = signal<number | null>(null);
  protected readonly pendingDelete = signal<Categoria | null>(null);
  protected readonly model = signal({ nombre: '', descripcion: '' });
  protected readonly categoryForm = form(this.model, (p) => {
    required(p.nombre, { message: 'El nombre es obligatorio.' });
    minLength(p.nombre, 2, { message: 'Ingresa al menos 2 caracteres.' });
    validate(p.nombre, ({ value }) => value().trim().length > 0 ? null : { kind: 'required', message: 'El nombre no puede contener solo espacios.' });
    maxLength(p.nombre, 80, { message: 'Máximo 80 caracteres.' });
    maxLength(p.descripcion, 250, { message: 'Máximo 250 caracteres.' });
  });

  constructor() { this.load(); }
  private load(): void { this.loading.set(true); this.api.list().subscribe({ next: (items) => { this.categories.set(items); this.loading.set(false); }, error: (e: unknown) => { this.error.set(ApiError.fromHttp(e).message); this.loading.set(false); } }); }
  protected edit(item: Categoria): void { this.editingId.set(item.id); this.model.set({ nombre: item.nombre, descripcion: item.descripcion ?? '' }); this.error.set(''); }
  protected reset(): void { this.editingId.set(null); this.model.set({ nombre: '', descripcion: '' }); this.error.set(''); }
  protected save(event: Event): void {
    event.preventDefault(); this.error.set('');
    submit(this.categoryForm, async () => {
      this.saving.set(true);
      try {
        const payload = { nombre: this.model().nombre.trim(), descripcion: this.model().descripcion.trim() || null };
        const id = this.editingId();
        if (id) await firstValueFrom(this.api.update(id, payload)); else await firstValueFrom(this.api.create(payload));
        this.reset(); this.load();
        this.toast.success(id ? 'Categoría actualizada' : 'Categoría creada', 'La lista se consultó nuevamente desde la base de datos.');
      } catch (e) { this.error.set(ApiError.fromHttp(e).message); }
      finally { this.saving.set(false); }
    });
  }
  protected askDelete(item: Categoria): void { this.pendingDelete.set(item); this.error.set(''); }
  protected remove(): void {
    const target = this.pendingDelete(); if (!target) return;
    this.saving.set(true);
    this.api.delete(target.id).subscribe({ next: () => { this.pendingDelete.set(null); this.load(); this.saving.set(false); this.toast.success('Categoría eliminada', 'La lista se actualizó desde la API.'); }, error: (e: unknown) => { this.error.set(ApiError.fromHttp(e).message); this.pendingDelete.set(null); this.saving.set(false); } });
  }
}
