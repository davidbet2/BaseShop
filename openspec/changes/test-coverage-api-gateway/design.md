# Design: Test Coverage - API Gateway

## Technical Approach

Crear tests de integración para el api-gateway usando Jest y supertest. Los tests verificarán el routing, proxy, CORS y rate limiting.

## Architecture Decisions

### Decision: Test Approach

**Choice**: Tests de integración con servicios reales corriendo
**Alternatives considered**: Mockear todos los servicios downstream
**Rationale**: Los servicios ya están corriendo localmente, es más simple y covering más real

### Decision: Rate Limit Testing

**Choice**: No testear rate limit exhaustivamente (solo verificar que existe)
**Alternatives considered**: Test con múltiples requests
**Rationale**: Rate limit puede ser flaky en CI, verificar configuración es suficiente

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `backend/api-gateway/jest.config.js` | Create | Configuración de Jest |
| `backend/api-gateway/tests/gateway.test.js` | Create | Tests principales |

## Interfaces / Contracts

```javascript
// jest.config.js
module.exports = {
  testEnvironment: 'node',
  testMatch: ['**/tests/**/*.test.js'],
  testTimeout: 30000,
  verbose: true
};
```

## Testing Strategy

| Layer | What to Test | Approach |
|-------|-------------|----------|
| Integration | Health check | supertest |
| Integration | Proxy routing | supertest + servicios reales |
| Config | CORS headers | Verificar headers |
| Config | Rate limiting | Verificar configuración |

## Migration / Rollout

No migration required.

## Open Questions

- [ ] ¿Necesitamos testear todos los servicios o solo los principales?
