# Proposal: Test Coverage - Payments Service

## Intent

Añadir tests unitarios y de integración al payments-service. Actualmente tiene 0% de cobertura de tests, lo cual representa un riesgo crítico para la lógica de pagos del sistema.

## Scope

### In Scope
- Tests unitarios para middleware de autenticación
- Tests de integración para endpoints de pagos (CRUD)
- Tests de validación de datos de pago
- Tests de manejo de errores
- Configuración de Jest y supertest

### Out of Scope
- Tests E2E (ya existen en /e2e)
- Tests de integración con pasarelas de pago reales (PayU)

## Approach

1. Configurar Jest en payments-service (sigue patrón de auth-service)
2. Crear mocks de base de datos
3. Escribir tests para rutas existentes
4. Cubrir casos de error y validación

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `backend/payments-service/` | Modified | Añadir tests Jest |
| `backend/payments-service/src/routes/payments.routes.js` | Tested | Endpoints de pagos |
| `backend/payments-service/src/middleware/auth.js` | Tested | Middleware auth |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Tests que rompen con cambios futuros | Medium | Mantener tests actualizados |
| Cobertura insuficiente | Low | Target 80% mínimo |

## Rollback Plan

Si los tests fallan o generan conflictos:
1. Eliminar carpeta `__tests__/`
2. Eliminar jest.config.js
3. Revertir cambios en package.json

## Dependencies

- Ninguna dependencia externa

## Success Criteria

- [ ] Jest configurado correctamente
- [ ] Tests para endpoint POST /api/payments/create
- [ ] Tests para endpoint GET /api/payments
- [ ] Tests para endpoint GET /api/payments/:id
- [ ] Tests para autenticación
- [ ] Tests de manejo de errores (400, 401, 500)
- [ ] Coverage mínimo 70%
- [ ] Todos los tests pasan
