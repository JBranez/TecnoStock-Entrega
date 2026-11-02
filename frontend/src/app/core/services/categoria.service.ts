import { Injectable, inject } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '../../../environments/environment';
import { Categoria, CategoriaPayload } from '../models/api.models';

@Injectable({ providedIn: 'root' })
export class CategoriaService {
  private readonly http = inject(HttpClient);
  private readonly url = `${environment.apiUrl}/categorias`;
  list(): Observable<Categoria[]> { return this.http.get<Categoria[]>(this.url); }
  get(id: number): Observable<Categoria> { return this.http.get<Categoria>(`${this.url}/${id}`); }
  create(payload: CategoriaPayload): Observable<Categoria> { return this.http.post<Categoria>(this.url, payload); }
  update(id: number, payload: CategoriaPayload): Observable<Categoria> { return this.http.put<Categoria>(`${this.url}/${id}`, payload); }
  delete(id: number): Observable<{ id: number; eliminada: boolean }> { return this.http.delete<{ id: number; eliminada: boolean }>(`${this.url}/${id}`); }
}
