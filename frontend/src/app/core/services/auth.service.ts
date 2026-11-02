import { Injectable, computed, inject, signal } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Router } from '@angular/router';
import { Observable, catchError, map, of, tap } from 'rxjs';
import { environment } from '../../../environments/environment';
import { CurrentUser, LoginResponse } from '../models/api.models';

const TOKEN_KEY = 'tecnostock.access_token';

@Injectable({ providedIn: 'root' })
export class AuthService {
  private readonly http = inject(HttpClient);
  private readonly router = inject(Router);
  readonly user = signal<CurrentUser | null>(null);
  readonly authenticated = computed(() => !!this.user() && !!this.token);

  get token(): string | null {
    return sessionStorage.getItem(TOKEN_KEY);
  }

  login(username: string, password: string): Observable<LoginResponse> {
    return this.http.post<LoginResponse>(`${environment.apiUrl}/auth/login`, { username, password }).pipe(
      tap((response) => {
        sessionStorage.setItem(TOKEN_KEY, response.access_token);
        this.user.set(response.user);
      }),
    );
  }

  restoreSession(): Observable<boolean> {
    if (this.user() && this.token) return of(true);
    const token = this.token;
    if (!token) return of(false);
    return this.http.get<CurrentUser>(`${environment.apiUrl}/auth/me`).pipe(
      tap((user) => this.user.set(user)),
      map(() => true),
      catchError(() => {
        this.clearSession();
        return of(false);
      }),
    );
  }

  clearSession(): void {
    sessionStorage.removeItem(TOKEN_KEY);
    this.user.set(null);
  }

  logout(): void {
    this.clearSession();
    void this.router.navigateByUrl('/login');
  }
}
