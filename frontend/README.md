# TecnoStock S.A.C.

Interfaz inicial de un sistema de gestión de inventario, desarrollada con Angular 22 y CSS tradicional. En esta etapa solo incluye la estructura visual, las rutas principales y un dashboard con datos demostrativos; no se conecta a servicios ni APIs.

## Requisitos

- Node.js compatible con Angular 22.
- npm.

## Ejecutar en desarrollo

Desde esta carpeta (`frontend`):

```bash
npm install
npm start
```

Abre `http://localhost:4200/`. El servidor recarga la aplicación cuando se actualizan los archivos.

## Verificar y compilar

```bash
npm test
npm run build
```

## Secciones

- Dashboard: indicadores, movimientos recientes y alertas con información ficticia identificada como demostrativa.
- Productos, Categorías, Movimientos, Historial y Consultas e indicadores: páginas de construcción con navegación funcional.

La aplicación no incluye autenticación, formularios, operaciones CRUD ni conexión con FastAPI.
