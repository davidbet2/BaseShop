# Proposal: Test Coverage - API Gateway

## Intent

Añadir tests al api-gateway para verificar el routing y proxy de solicitudes a los microservicios. Actualmente sin cobertura de tests.

## Scope

### In Scope
- Tests de routing a servicios
- Tests de configuración de CORS
- Tests de rate limiting
- Tests de manejo de errores
- Tests de health check

### Out of Scope
- Tests de los servicios downstream (tienen sus propios tests)

## Approach

1. Configurar Jest + supertest en api-gateway
2. Crear tests de integración que llamen al gateway
3. Verificar que las peticiones se proxyan correctamente
4. Testear configuración de CORS

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `backend/api-gateway/` | Modified | Añadir tests |
| `backend/api-gateway/src/server.js` | Tested | Routing y proxy |
| `backend/api-gateway/src/middleware/` | Tested | CORS, rate limit |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Dependencia de servicios externos | Medium | Mockear respuestas o usar servicios locales |
| Tests flaky por timing | Low | Añadir timeouts adecuados |

## Rollback Plan

1. Eliminar carpeta `__tests__/`
2. Eliminar jest.config.js
3. Revertir package.json

## Dependencies

- Todos los servicios backend corriendo localmente

## Success Criteria

- [ ] Jest configurado
- [ ] Tests para /health
- [ ] Tests de proxy a auth-service
- [ ] Tests de proxy a products-service
- [ ] Tests de CORS
- [ ] Tests de rate limiting
- [ ] Tests de 404 catch-all
- [ ] Coverage mínimo 60%
- [ ] Todos los tests pasan
