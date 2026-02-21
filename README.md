# BaseShop — E-commerce Fullstack (Flutter + Node.js Microservicios)

## Descripción
BaseShop es una plataforma de e-commerce completa para vender cualquier producto. Incluye catálogo de productos con categorías jerárquicas, carrito de compras, sistema de pedidos, integración con PayU para pagos, reseñas de productos, lista de favoritos, y panel de administración.

## Arquitectura

### Backend (Microservicios Node.js)
| Servicio | Puerto | Descripción |
|----------|--------|-------------|
| api-gateway | 3000 | Proxy reverso a todos los servicios |
| auth-service | 3001 | Autenticación JWT + Google Sign-In |
| users-service | 3002 | Perfiles, direcciones, device tokens |
| products-service | 3003 | Productos y categorías jerárquicas |
| cart-service | 3004 | Carrito de compras |
| orders-service | 3005 | Pedidos y estados |
| payments-service | 3006 | Integración PayU |
| reviews-service | 3007 | Reseñas y valoraciones |
| favorites-service | 3008 | Lista de favoritos |

### Frontend (Flutter)
- **State Management**: flutter_bloc + equatable
- **Navegación**: go_router con auth guard
- **HTTP**: dio con interceptors (auto-refresh token)
- **DI**: get_it (manual)
- **Auth**: Email/Password + Google Sign-In
- **Push**: Firebase Messaging + Local Notifications

## Roles
- **admin**: Gestión completa (productos, pedidos, usuarios)
- **client**: Comprar, ver pedidos, reseñar, favoritos

## Quick Start

### Backend (desarrollo local)
```bash
cd backend
docker-compose up --build
```
O servicio por servicio:
```bash
cd backend/auth-service && npm install && npm run dev
cd backend/users-service && npm install && npm run dev
# ... repetir para cada servicio
cd backend/api-gateway && npm install && npm run dev
```

### Frontend
```bash
cd frontend
flutter pub get
flutter run
```

### Build para producción
```bash
# APK
flutter build apk --release --dart-define=API_BASE_URL=https://tu-gateway.up.railway.app/api

# Web
flutter build web --release --dart-define=API_BASE_URL=https://tu-gateway.up.railway.app/api
```

## Variables de Entorno
Ver `backend/.env.production.template` para la lista completa.

## Credenciales por defecto (desarrollo)
- **Admin**: admin@baseshop.com / Admin123!

## Tech Stack
- **Backend**: Node.js 20, Express 4, SQLite (sql.js), JWT, bcrypt
- **Frontend**: Flutter 3.x, Dart 3.x, BLoC, go_router, dio, get_it
- **Pagos**: PayU (sandbox/producción)
- **CI/CD**: GitHub Actions → Docker Hub → Railway
