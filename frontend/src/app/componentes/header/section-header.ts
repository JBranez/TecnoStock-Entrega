import { ChangeDetectionStrategy, Component, input } from '@angular/core';

@Component({
  selector: 'app-section-header',
  standalone: true,
  changeDetection: ChangeDetectionStrategy.OnPush,
  templateUrl: './section-header.html',
  styleUrl: './section-header.css',
})
export class SectionHeaderComponent {
  readonly title = input.required<string>();
  readonly description = input.required<string>();
}
