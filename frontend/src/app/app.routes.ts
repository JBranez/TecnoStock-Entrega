import { Routes } from '@angular/router';
import { authGuard } from './core/guards/auth.guard';
import { guestGuard } from './core/guards/guest.guard';

export const routes: Routes = [
  {
    path: 'login',
    canActivate: [guestGuard],
    loadComponent: () => import('./features/auth/login.page').then((m) => m.LoginPage),
    title: 'Iniciar sesión | TecnoStock',
  },
  {
    path: '',
    canActivate: [authGuard],
    children: [
      { path: '', loadComponent: () => import('./features/dashboard/dashboard.page').then((m) => m.DashboardPage), title: 'Dashboard | TecnoStock' },
      { path: 'categorias', loadComponent: () => import('./features/categorias/categorias.page').then((m) => m.CategoriasPage), title: 'Categorías | TecnoStock' },
      { path: 'productos', loadComponent: () => import('./features/productos/productos.page').then((m) => m.ProductosPage), title: 'Productos | TecnoStock' },
      { path: 'productos/nuevo', loadComponent: () => import('./features/productos/producto-form.page').then((m) => m.ProductoFormPage), title: 'Nuevo producto | TecnoStock' },
      { path: 'productos/:id/editar', loadComponent: () => import('./features/productos/producto-form.page').then((m) => m.ProductoFormPage), title: 'Editar producto | TecnoStock' },
      { path: 'movimientos', loadComponent: () => import('./features/movimientos/movimientos.page').then((m) => m.MovimientosPage), title: 'Movimientos | TecnoStock' },
      { path: 'historial', loadComponent: () => import('./features/historial/historial.page').then((m) => m.HistorialPage), title: 'Historial | TecnoStock' },
      { path: 'consultas', loadComponent: () => import('./features/stock-bajo/stock-bajo.page').then((m) => m.StockBajoPage), title: 'Stock bajo | TecnoStock' },
      { path: '**', redirectTo: '' },
    ],
  },
];
