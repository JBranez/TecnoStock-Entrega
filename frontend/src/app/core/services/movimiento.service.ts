import { Injectable, inject } from '@angular/core';
import { HttpClient, HttpParams } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '../../../environments/environment';
import { Movimiento, MovimientoPayload, MovimientoQuery, Paginated } from '../models/api.models';

@Injectable({ providedIn: 'root' })
export class MovimientoService {
  private readonly http = inject(HttpClient);
  private readonly url = `${environment.apiUrl}/movimientos`;
  list(query: MovimientoQuery = {}): Observable<Paginated<Movimiento>> {
    let params = new HttpParams();
    Object.entries({ page: 1, page_size: 10, ...query }).forEach(([key, value]) => {
      if (value !== undefined && value !== null && value !== '') params = params.set(key, String(value));
    });
    return this.http.get<Paginated<Movimiento>>(this.url, { params });
  }
  registerEntry(payload: MovimientoPayload): Observable<Movimiento> {
    return this.http.post<Movimiento>(`${this.url}/entradas`, payload);
  }
  registerExit(payload: MovimientoPayload): Observable<Movimiento> {
    return this.http.post<Movimiento>(`${this.url}/salidas`, payload);
  }
}
