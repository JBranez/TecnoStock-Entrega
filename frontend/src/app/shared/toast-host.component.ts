import { ChangeDetectionStrategy, Component, inject } from '@angular/core';
import { ToastService } from '../core/services/toast.service';

@Component({
  selector: 'app-toast-host',
  standalone: true,
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <section class="toast-stack" aria-label="Notificaciones" aria-live="polite" aria-relevant="additions">
      @for (toast of service.messages(); track toast.id) {
        <article class="toast" [class.success]="toast.kind === 'success'" [class.error]="toast.kind === 'error'" [class.info]="toast.kind === 'info'" [attr.role]="toast.kind === 'error' ? 'alert' : 'status'">
          <span class="toast-mark" aria-hidden="true">{{ toast.kind === 'success' ? '✓' : toast.kind === 'error' ? '!' : 'i' }}</span>
          <div class="toast-copy"><strong>{{ toast.title }}</strong><p>{{ toast.message }}</p></div>
          <button type="button" class="toast-close" (click)="service.dismiss(toast.id)" [attr.aria-label]="'Cerrar aviso: ' + toast.title">×</button>
        </article>
      }
    </section>
  `,
  styles: [`
    .toast-stack{position:fixed;z-index:1000;top:18px;right:18px;display:grid;gap:9px;width:min(390px,calc(100vw - 36px));pointer-events:none}.toast{display:grid;grid-template-columns:28px 1fr 24px;align-items:start;gap:10px;padding:13px 14px;border:1px solid var(--line);border-left:4px solid #8ba83b;border-radius:11px;background:#fff;box-shadow:0 12px 35px #1b273022;pointer-events:auto}.toast.error{border-left-color:#b95d48}.toast.info{border-left-color:#6e8ca0}.toast-mark{display:grid;width:25px;height:25px;place-items:center;border-radius:50%;background:#eff5df;color:#5f772a;font-weight:900}.toast.error .toast-mark{background:#fff0ec;color:#a84635}.toast.info .toast-mark{background:#edf3f7;color:#42687f}.toast-copy strong{display:block;font-size:.8rem}.toast-copy p{margin:3px 0 0;color:var(--ink-muted);font-size:.74rem;line-height:1.4}.toast-close{border:0;background:transparent;color:var(--ink-muted);font-size:1.15rem;line-height:1;cursor:pointer}
  `],
})
export class ToastHostComponent {
  protected readonly service = inject(ToastService);
}
