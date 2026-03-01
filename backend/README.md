# BaseShop Backend Services

## Puertos

| Servicio | Puerto |
|----------|--------|
| api-gateway | 3000 |
| auth-service | 3001 |
| users-service | 3002 |
| products-service | 3003 |
| cart-service | 3004 |
| orders-service | 3005 |
| payments-service | 3006 |
| reviews-service | 3007 |
| favorites-service | 3008 |
| config-service | 3009 |

## Iniciar todos los servicios

```bash
# En backend/
cd backend

# Iniciar todos los servicios en paralelo
for service in auth-service users-service products-service cart-service orders-service payments-service reviews-service favorites-service config-service api-gateway; do
  cd $service
  npm start &
  cd ..
done
```

O usar concurrently si está instalado:

```bash
npx concurrently "cd auth-service && npm start" "cd users-service && npm start" ...
```
