export interface ApiFieldError {
  field?: string;
  message: string;
}

export interface ApiErrorBody {
  code?: string;
  detail?: string;
  errors?: ApiFieldError[];
}

export interface CurrentUser {
  id: number;
  username: string;
  nombre_completo: string;
}

export interface LoginResponse {
  access_token: string;
  token_type: 'bearer';
  expires_in: number;
  user: CurrentUser;
}

export interface Categoria {
  id: number;
  nombre: string;
  descripcion: string | null;
  fecha_creacion: string;
}

export interface CategoriaPayload {
  nombre: string;
  descripcion: string | null;
}

export interface Producto {
  id: number;
  codigo: string;
  nombre: string;
  descripcion: string | null;
  categoria_id: number;
  categoria_nombre: string;
  precio_compra: number;
  precio_venta: number;
  stock_actual: number;
  stock_minimo: number;
  activo: boolean;
  fecha_creacion: string;
  fecha_actualizacion: string | null;
}

export interface ProductoPayload {
  codigo: string;
  nombre: string;
  descripcion: string | null;
  categoria_id: number;
  precio_compra: number;
  precio_venta: number;
  stock_minimo: number;
}

export interface ProductoQuery {
  search?: string;
  categoria_id?: number;
  estado?: 'activos' | 'inactivos' | 'todos';
  page?: number;
  page_size?: number;
}

export interface Paginated<T> {
  items: T[];
  total: number;
  page: number;
  page_size: number;
}

export interface Movimiento {
  id: number;
  producto_id: number;
  producto_codigo: string;
  producto_nombre: string;
  tipo_movimiento: 'ENTRADA' | 'SALIDA';
  cantidad: number;
  fecha_movimiento: string;
  motivo: string;
  stock_anterior: number;
  stock_posterior: number;
  usuario_id: number;
  usuario_nombre: string;
  fecha_registro: string;
}

export interface MovimientoPayload {
  producto_id: number;
  cantidad: number;
  fecha_movimiento: string;
  motivo: string;
}

export interface MovimientoQuery {
  producto_id?: number;
  fecha_desde?: string;
  fecha_hasta?: string;
  tipo?: 'ENTRADA' | 'SALIDA';
  page?: number;
  page_size?: number;
}

export interface DashboardIndicadores {
  productos_activos: number;
  productos_stock_bajo: number;
  valor_referencial: number;
  total_entradas: number;
  total_salidas: number;
  total_movimientos: number;
  fecha_desde: string | null;
  fecha_hasta: string | null;
}
