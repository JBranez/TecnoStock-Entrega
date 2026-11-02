import { Injectable, inject } from '@angular/core';
import { HttpClient, HttpParams } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '../../../environments/environment';
import { Paginated, Producto, ProductoPayload, ProductoQuery } from '../models/api.models';

@Injectable({ providedIn: 'root' })
export class ProductoService {
  private readonly http = inject(HttpClient);
  private readonly url = `${environment.apiUrl}/productos`;
  list(query: ProductoQuery = {}): Observable<Paginated<Producto>> {
    let params = new HttpParams();
    Object.entries({ estado: 'activos', page: 1, page_size: 10, ...query }).forEach(([key, value]) => {
      if (value !== undefined && value !== null && value !== '') params = params.set(key, String(value));
    });
    return this.http.get<Paginated<Producto>>(this.url, { params });
  }
  listLowStock(): Observable<Producto[]> { return this.http.get<Producto[]>(`${this.url}/stock-bajo`); }
  get(id: number): Observable<Producto> { return this.http.get<Producto>(`${this.url}/${id}`); }
  create(payload: ProductoPayload): Observable<Producto> { return this.http.post<Producto>(this.url, payload); }
  update(id: number, payload: ProductoPayload): Observable<Producto> { return this.http.put<Producto>(`${this.url}/${id}`, payload); }
  changeStatus(id: number, activo: boolean): Observable<Producto> {
    return this.http.patch<Producto>(`${this.url}/${id}/estado`, { activo });
  }
  delete(id: number): Observable<{ id: number; eliminado: boolean }> {
    return this.http.delete<{ id: number; eliminado: boolean }>(`${this.url}/${id}`);
  }
}
