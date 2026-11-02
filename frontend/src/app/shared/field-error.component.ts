import { ChangeDetectionStrategy, Component, input } from '@angular/core';
import type { ValidationError } from '@angular/forms/signals';

@Component({
  selector: 'app-field-error',
  standalone: true,
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `@if (visible() && errors().length) { <div class="field-errors" aria-live="polite">@for (error of errors(); track $index) { @if (error.message) { <small>{{ error.message }}</small> } }</div> }`,
  styles: [`.field-errors{display:grid;gap:3px;margin-top:5px;color:#b64e3d}.field-errors small{font-size:.76rem}`],
})
export class FieldErrorComponent {
  readonly errors = input<readonly ValidationError[]>([]);
  readonly visible = input(false);
}
