import { Injectable, signal } from '@angular/core';

export type ToastKind = 'success' | 'error' | 'info';

export interface ToastMessage {
  id: number;
  kind: ToastKind;
  title: string;
  message: string;
}

@Injectable({ providedIn: 'root' })
export class ToastService {
  readonly messages = signal<ToastMessage[]>([]);
  private sequence = 0;

  success(title: string, message: string): void {
    this.show('success', title, message);
  }

  error(title: string, message: string): void {
    this.show('error', title, message);
  }

  info(title: string, message: string): void {
    this.show('info', title, message);
  }

  dismiss(id: number): void {
    this.messages.update((items) => items.filter((item) => item.id !== id));
  }

  private show(kind: ToastKind, title: string, message: string): void {
    const id = ++this.sequence;
    this.messages.update((items) => [...items, { id, kind, title, message }].slice(-4));
    // Los avisos desaparecen solos; el usuario también puede cerrarlos manualmente.
    setTimeout(() => this.dismiss(id), 5000);
  }
}
