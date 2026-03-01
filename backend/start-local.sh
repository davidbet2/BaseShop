#!/bin/bash
# ============================================
# BaseShop - Start all services locally
# ============================================

BACKEND_DIR="$(cd "$(dirname "$0")" && pwd)"

# Load centralized .env file
ENV_FILE="$BACKEND_DIR/.env"
if [ -f "$ENV_FILE" ]; then
  echo "Loading environment from $ENV_FILE"
  set -a
  source "$ENV_FILE"
  set +a
else
  echo "WARNING: $ENV_FILE not found. Copy .env.example to .env and fill in values."
  echo "  cp $BACKEND_DIR/.env.example $BACKEND_DIR/.env"
fi

# Validate required variables
if [ -z "$JWT_SECRET" ] || [ "$JWT_SECRET" = "CHANGE_ME_use_64_chars_minimum" ]; then
  echo "FATAL: JWT_SECRET is required and must be changed from the placeholder."
  exit 1
fi
export ALLOWED_ORIGINS="${ALLOWED_ORIGINS:-http://localhost:9090,http://localhost:8080,http://localhost:3000}"
PIDS=()

cleanup() {
  echo ""
  echo "Stopping all services..."
  for pid in "${PIDS[@]}"; do
    kill "$pid" 2>/dev/null
  done
  exit 0
}
trap cleanup SIGINT SIGTERM

start_service() {
  local name=$1
  local port=$2
  local dir="$BACKEND_DIR/$name"

  export PORT=$port
  export DB_PATH="$dir/data/$name.db"

  # Extra env for specific services
  if [ "$name" = "auth-service" ]; then
    export ADMIN_EMAIL="${ADMIN_EMAIL:?ADMIN_EMAIL is required}"
    export ADMIN_PASSWORD="${ADMIN_PASSWORD:?ADMIN_PASSWORD is required}"
    export JWT_EXPIRATION="${JWT_EXPIRATION:-24h}"
    # BREVO SMTP creds loaded from auth-service/.env via dotenv
  fi

  if [ "$name" = "payments-service" ]; then
    export PAYU_IS_TEST="${PAYU_IS_TEST:-true}"
    export PAYU_API_KEY="${PAYU_API_KEY:?PAYU_API_KEY is required}"
    export PAYU_API_LOGIN="${PAYU_API_LOGIN:?PAYU_API_LOGIN is required}"
    export PAYU_MERCHANT_ID="${PAYU_MERCHANT_ID:?PAYU_MERCHANT_ID is required}"
    export PAYU_ACCOUNT_ID="${PAYU_ACCOUNT_ID:?PAYU_ACCOUNT_ID is required}"
    export ORDERS_SERVICE_URL="http://localhost:3005"
    export FRONTEND_URL="http://localhost:8080"
    export GATEWAY_URL="http://localhost:3000"
  fi

  if [ "$name" = "api-gateway" ]; then
    export AUTH_SERVICE_URL="http://localhost:3001"
    export USERS_SERVICE_URL="http://localhost:3002"
    export PRODUCTS_SERVICE_URL="http://localhost:3003"
    export CART_SERVICE_URL="http://localhost:3004"
    export ORDERS_SERVICE_URL="http://localhost:3005"
    export PAYMENTS_SERVICE_URL="http://localhost:3006"
    export REVIEWS_SERVICE_URL="http://localhost:3007"
    export FAVORITES_SERVICE_URL="http://localhost:3008"
    export CONFIG_SERVICE_URL="http://localhost:3009"
  fi

  mkdir -p "$dir/data"
  cd "$dir"
  node src/server.js &
  PIDS+=($!)
  echo "[$name] Started on port $port (PID: $!)"
}

echo "========================================"
echo " BaseShop Backend - Local Development"
echo "========================================"
echo ""

# Start microservices first
start_service "auth-service" 3001
start_service "users-service" 3002
start_service "products-service" 3003
start_service "cart-service" 3004
start_service "orders-service" 3005
start_service "payments-service" 3006
start_service "reviews-service" 3007
start_service "favorites-service" 3008
start_service "config-service" 3009

# Wait for services to start
sleep 3

# Start API Gateway last
start_service "api-gateway" 3000

echo ""
echo "========================================"
echo " All services running!"
echo " API Gateway: http://localhost:3000"
echo "========================================"
echo ""
echo " Admin credentials: set via ADMIN_EMAIL and ADMIN_PASSWORD env vars"
echo ""
echo " Press Ctrl+C to stop all services"
echo "========================================"

# Wait for all
wait
