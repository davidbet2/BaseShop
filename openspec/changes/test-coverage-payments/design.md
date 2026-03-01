# Design: Test Coverage - Payments Service

## Technical Approach

Crear tests de integración para el payments-service usando Jest y supertest, siguiendo el patrón existente en auth-service. Los tests usarán una base de datos en memoria para evitar efectos secundarios.

## Architecture Decisions

### Decision: Test Database Setup

**Choice**: Usar base de datos en memoria SQLite (`:memory:`)
**Alternatives considered**: Mockear la base de datos completamente, usar archivo temporal
**Rationale**: El patrón en auth-service usa `:memory:` lo cual es rápido y no requiere cleanup

### Decision: Test Structure

**Choice**: Tests de integración que llaman directamente al router de Express
**Alternatives considered**: Tests unitarios puros con mocks de todo
**Rationale**: El patrón en auth-service usa integración, lo cual prueba más código real con menos complejidad

### Decision: Mock External Services

**Choice**: Mockear axios para las llamadas a orders-service
**Alternatives considered**: Usar ordenes-service real corriendo
**Rationale**: Aísla los tests de payments-service y evita dependencias externas

## Data Flow

```
Tests → supertest → Express App → Routes → Database (in-memory)
                              ↓
                         Mock axios → orders-service
```

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `backend/payments-service/jest.config.js` | Create | Configuración de Jest |
| `backend/payments-service/tests/payments.test.js` | Create | Tests principales de payments |
| `backend/payments-service/tests/mocks/database.js` | Create | Mock de base de datos |
| `backend/payments-service/package.json` | Modify | Añadir scripts de test |

## Interfaces / Contracts

```javascript
// jest.config.js
module.exports = {
  testEnvironment: 'node',
  testMatch: ['**/tests/**/*.test.js'],
  coverageDirectory: 'coverage',
  collectCoverageFrom: [
    'src/**/*.js',
    '!src/database.js'
  ],
  setupFilesAfterEnv: ['<rootDir>/tests/setup.js'],
  verbose: true
};
```

```javascript
// tests/setup.js
beforeAll(async () => {
  process.env.DB_PATH = ':memory:';
  process.env.JWT_SECRET = 'test-secret-key';
  process.env.PAYU_IS_TEST = 'true';
  process.env.INTERNAL_SERVICE_SECRET = 'test-secret';
  
  const { initDatabase } = require('../src/database');
  await initDatabase();
});

afterAll(() => {
  const { close } = require('../src/database');
  close();
});
```

## Testing Strategy

| Layer | What to Test | Approach |
|-------|-------------|----------|
| Integration | Endpoints de payments | supertest + app express |
| Auth | Middleware de autenticación | Tokens JWT válidos e inválidos |
| Validation | Validación de input | Datos válidos e inválidos |
| Errors | Manejo de errores | 400, 401, 404, 500 |

## Migration / Rollout

No migration required.

## Open Questions

- [ ] ¿Necesitamos tests específicos para el webhook de PayU? (Requiere mock de firma válida)
