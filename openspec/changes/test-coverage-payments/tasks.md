# Tasks: Test Coverage - Payments Service

## Phase 1: Infrastructure

- [x] 1.1 Crear `backend/payments-service/jest.config.js` con configuración de Jest
- [x] 1.2 Crear `backend/payments-service/tests/setup.js` con configuración de base de datos en memoria
- [x] 1.3 Añadir scripts de test en `backend/payments-service/package.json`:
  - `"test": "jest --forceExit --detectOpenHandles"`
  - `"test:watch": "jest --watch"`
  - `"test:coverage": "jest --coverage"`

## Phase 2: Test Files

- [x] 2.1 Crear `backend/payments-service/tests/payments.test.js` con estructura básica
- [x] 2.2 Crear `backend/payments-service/tests/mocks/` para mocks de axios

## Phase 3: Auth Middleware Tests

- [x] 3.1 Test: Request sin token → 401
- [x] 3.2 Test: Request con token válido → proceed
- [x] 3.3 Test: Request con token inválido → 401

## Phase 4: Payment Endpoint Tests

- [x] 4.1 Test: POST /api/payments/create con datos válidos → 201
- [x] 4.2 Test: POST /api/payments/create sin datos requeridos → 400
- [x] 4.3 Test: POST /api/payments/create sin auth → 401
- [x] 4.4 Test: GET /api/payments/order/:orderId como owner → 200
- [x] 4.5 Test: GET /api/payments/order/:orderId como otro usuario → 404

## Phase 5: Admin Endpoint Tests

- [x] 5.1 Test: GET /api/payments como admin → 200
- [x] 5.2 Test: GET /api/payments como usuario no-admin → 403
- [x] 5.3 Test: GET /api/payments/stats/summary como admin → 200
- [x] 5.4 Test: POST /api/payments/:id/refund como admin → 200
- [x] 5.5 Test: POST /api/payments/:id/refund en pago no-aprobado → 400

## Phase 6: Webhook Tests

- [x] 6.1 Test: POST /api/payments/webhook/payu con firma válida → 200
- [x] 6.2 Test: POST /api/payments/webhook/payu con firma inválida → 400
- [x] 6.3 Test: POST /api/payments/webhook/payu para pago inexistente → 400

## Phase 7: Coverage

- [x] 7.1 Ejecutar tests y verificar coverage mínimo 70%
- [x] 7.2 Corregir tests que fallen
- [x] 7.3 Verificar que todos los tests pasen
