# Tasks: Test Coverage - API Gateway

## Phase 1: Infrastructure

- [x] 1.1 Crear `backend/api-gateway/jest.config.js` con configuración de Jest

## Phase 2: Gateway Tests

- [x] 2.1 Test: GET /health → 200 con status running
- [x] 2.2 Test: GET /api/products → proxy a products-service
- [x] 2.3 Test: POST /api/auth/login → proxy a auth-service
- [x] 2.4 Test: GET /api/users → proxy a users-service

## Phase 3: CORS Tests

- [x] 3.1 Test: Request desde localhost:8080 tiene Access-Control-Allow-Origin

## Phase 4: Error Handling Tests

- [x] 4.1 Test: Ruta no existente → 404
- [x] 4.2 Test: Servicio no disponible → 503

## Phase 5: Rate Limiting

- [x] 5.1 Verificar que rate limiting está configurado (verificar respuesta 429)

## Phase 6: Execution

- [x] 6.1 Ejecutar todos los tests
- [x] 6.2 Verificar que todos pasen
