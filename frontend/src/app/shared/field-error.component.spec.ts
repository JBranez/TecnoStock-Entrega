import { TestBed } from '@angular/core/testing';
import { FieldErrorComponent } from './field-error.component';

describe('FieldErrorComponent', () => {
  it('muestra los mensajes disponibles de Signal Forms', async () => {
    await TestBed.configureTestingModule({ imports: [FieldErrorComponent] }).compileComponents();
    const fixture = TestBed.createComponent(FieldErrorComponent);
    fixture.componentRef.setInput('errors', [
      { kind: 'required', message: 'Este campo es obligatorio.' },
      { kind: 'min', message: undefined },
    ]);
    fixture.componentRef.setInput('visible', true);
    fixture.detectChanges();

    expect(fixture.nativeElement.textContent).toContain('Este campo es obligatorio.');
    expect(fixture.nativeElement.querySelectorAll('small')).toHaveLength(1);
  });

  it('oculta mensajes si el campo todavía no fue tocado', async () => {
    await TestBed.configureTestingModule({ imports: [FieldErrorComponent] }).compileComponents();
    const fixture = TestBed.createComponent(FieldErrorComponent);
    fixture.componentRef.setInput('errors', [{ kind: 'required', message: 'Obligatorio.' }]);
    fixture.componentRef.setInput('visible', false);
    fixture.detectChanges();

    expect(fixture.nativeElement.textContent).not.toContain('Obligatorio.');
  });
});
