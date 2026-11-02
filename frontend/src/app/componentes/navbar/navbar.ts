import { ChangeDetectionStrategy, Component, inject, signal } from '@angular/core';
import { RouterLink, RouterLinkActive } from '@angular/router';
import { AuthService } from '../../core/services/auth.service';

interface NavigationItem { label: string; path: string; icon: string; exact?: boolean; }

@Component({
  selector: 'app-navbar',
  standalone: true,
  imports: [RouterLink, RouterLinkActive],
  changeDetection: ChangeDetectionStrategy.OnPush,
  templateUrl: './navbar.html',
  styleUrl: './navbar.css',
})
export class NavbarComponent {
  protected readonly auth = inject(AuthService);
  protected readonly menuOpen = signal(false);
  protected readonly items: NavigationItem[] = [
    { label: 'Dashboard', path: '/', icon: 'M3 10.5 12 3l9 7.5v9a1.5 1.5 0 0 1-1.5 1.5h-15A1.5 1.5 0 0 1 3 19.5z M9 21v-7h6v7', exact: true },
    { label: 'Productos', path: '/productos', icon: 'M4 5.5 12 2l8 3.5v13L12 22l-8-3.5z M4 5.5l8 4 8-4 M12 9.5V22' },
    { label: 'Categorías', path: '/categorias', icon: 'M4 4h7v7H4z M14 4h6v4h-6z M14 11h6v9h-6z M4 14h7v6H4z' },
    { label: 'Movimientos', path: '/movimientos', icon: 'M7 7h13l-3-3 M20 7l-3 3 M17 17H4l3 3 M4 17l3-3 M12 7v10' },
    { label: 'Historial', path: '/historial', icon: 'M3 12a9 9 0 1 0 2.64-6.36L3 8 M3 3v5h5 M12 7v5l3 2' },
    { label: 'Stock bajo', path: '/consultas', icon: 'M12 3 2.8 20h18.4L12 3z M12 9v5 M12 17.5v.1' },
  ];
  protected closeMenu(): void { this.menuOpen.set(false); }
  protected toggleMenu(): void { this.menuOpen.update((open) => !open); }
  protected logout(): void { this.closeMenu(); this.auth.logout(); }
}
