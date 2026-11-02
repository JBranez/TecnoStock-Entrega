import { HttpErrorResponse } from '@angular/common/http';
import { ApiErrorBody } from '../models/api.models';

export class ApiError extends Error {
  readonly code: string;
  readonly status: number;
  readonly fieldErrors: { field?: string; message: string }[];

  constructor(message: string, status: number, code = 'ERROR_API', fieldErrors: { field?: string; message: string }[] = []) {
    super(message);
    this.name = 'ApiError';
    this.code = code;
    this.status = status;
    this.fieldErrors = fieldErrors;
  }

  static fromHttp(error: unknown): ApiError {
    if (error instanceof ApiError) return error;
    if (error instanceof HttpErrorResponse) {
      const body = (error.error ?? {}) as ApiErrorBody;
      const fieldErrors = body.errors ?? [];
      const detail = body.detail ?? (error.status === 0 ? 'No se pudo conectar con la API. Comprueba que el backend esté iniciado.' : 'La solicitud no pudo procesarse.');
      const fieldSummary = fieldErrors.map((item) => `${item.field ? `${item.field}: ` : ''}${item.message}`).join(' ');
      const message = fieldSummary ? `${detail} ${fieldSummary}` : detail;
      return new ApiError(message, error.status, body.code ?? 'ERROR_API', fieldErrors);
    }
    return new ApiError('Ocurrió un error inesperado.', 0);
  }
}
