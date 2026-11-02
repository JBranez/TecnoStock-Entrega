import { ChangeDetectionStrategy, Component, inject, signal } from '@angular/core';
import { Router } from '@angular/router';
import { form, FormField, maxLength, required, submit } from '@angular/forms/signals';
import { firstValueFrom } from 'rxjs';
import { AuthService } from '../../core/services/auth.service';
import { ApiError } from '../../core/services/api-error';
import { FieldErrorComponent } from '../../shared/field-error.component';

@Component({
  selector: 'app-login-page', standalone: true, imports: [FormField, FieldErrorComponent],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <main class="login-wrap">
      <section class="login-card">
        <div class="brand-mark">TS</div>
        <p class="eyebrow">TECNO STOCK S.A.C.</p>
        <h1>Bienvenido</h1>
        <p class="muted">Inicia sesión para administrar el inventario.</p>
        @if (error()) { <div class="alert-error" role="alert">{{ error() }}</div> }
        <form novalidate (submit)="onSubmit($event)">
          <label for="username">Usuario</label>
          <input id="username" class="control" autocomplete="username" [formField]="loginForm.username" placeholder="admin">
          <app-field-error [errors]="loginForm.username().errors()" [visible]="loginForm.username().touched()" />
          <label for="password">Contraseña</label>
          <input id="password" class="control" type="password" autocomplete="current-password" [formField]="loginForm.password" placeholder="Tu contraseña">
          <app-field-error [errors]="loginForm.password().errors()" [visible]="loginForm.password().touched()" />
          <button class="button button-primary submit" type="submit" [disabled]="busy()">
            {{ busy() ? 'Ingresando…' : 'Ingresar al sistema' }}
          </button>
        </form>
        <p class="login-foot">Sistema de gestión de inventario · TecnoStock</p>
      </section>
    </main>
  `,
  styles: [`
    .login-wrap{min-height:100vh;display:grid;place-items:center;padding:24px;background:var(--ivory)}
    .login-card{width:min(100%,420px);padding:38px;border:1px solid var(--line);border-radius:20px;background:#fff;box-shadow:var(--shadow)}
    .brand-mark{display:grid;width:52px;height:52px;place-items:center;border-radius:15px;background:var(--acid);font-weight:900;letter-spacing:-.08em}
    .eyebrow{margin:24px 0 7px;color:#78836b;font-size:.68rem;font-weight:800;letter-spacing:.15em}
    h1{margin:0;font-size:2rem;letter-spacing:-.05em}.muted{margin:8px 0 25px;color:var(--ink-muted);font-size:.9rem}
    form{display:grid;gap:9px}label{margin-top:8px;font-size:.8rem;font-weight:700}.control{width:100%;padding:12px 13px;border:1px solid var(--line);border-radius:9px;background:#fff;font:inherit;outline:none}.control:focus{border-color:#92b73a;box-shadow:0 0 0 3px #b7e34b35}
    .button{border:0;border-radius:9px;padding:12px 16px;font:inherit;font-weight:750;cursor:pointer}.button-primary{margin-top:15px;background:var(--graphite);color:#fff}.button:disabled{opacity:.55;cursor:not-allowed}.submit{width:100%}
    .alert-error{margin:14px 0;padding:11px 13px;border:1px solid #f0c7bd;border-radius:9px;background:#fff3f0;color:#a43d2f;font-size:.84rem}.login-foot{margin:25px 0 0;color:var(--ink-muted);font-size:.72rem;text-align:center}
    @media(max-width:480px){.login-card{padding:28px 22px}}
  `],
})
export class LoginPage {
  private readonly auth = inject(AuthService);
  private readonly router = inject(Router);
  protected readonly busy = signal(false);
  protected readonly error = signal('');
  protected readonly model = signal({ username: '', password: '' });
  protected readonly loginForm = form(this.model, (p) => {
    required(p.username, { message: 'El usuario es obligatorio.' });
    maxLength(p.username, 50, { message: 'Máximo 50 caracteres.' });
    required(p.password, { message: 'La contraseña es obligatoria.' });
    maxLength(p.password, 128, { message: 'Máximo 128 caracteres.' });
  });

  protected onSubmit(event: Event): void {
    event.preventDefault();
    this.error.set('');
    submit(this.loginForm, async () => {
      this.busy.set(true);
      try {
        const value = this.model();
        await firstValueFrom(this.auth.login(value.username.trim(), value.password));
        await this.router.navigateByUrl('/');
      } catch (error) {
        this.error.set(ApiError.fromHttp(error).message || 'Credenciales inválidas.');
      } finally {
        this.busy.set(false);
      }
    });
  }
}
