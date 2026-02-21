#!/bin/bash
# ══════════════════════════════════════════════
# Seed script: creates test categories & products
# Run: bash backend/seed-products.sh
# ══════════════════════════════════════════════
set -e

API="http://localhost:3000/api"

echo "═══════════════════════════════════════"
echo "  BaseShop — Seed Products"
echo "═══════════════════════════════════════"

# 1. Login as admin to get token
echo "[1/3] Logging in as admin..."
TOKEN=$(curl -s -X POST "$API/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@baseshop.com","password":"Admin123!"}' \
  | grep -o '"token":"[^"]*"' | head -1 | cut -d'"' -f4)

if [ -z "$TOKEN" ]; then
  echo "ERROR: Could not get admin token. Is Docker running?"
  exit 1
fi
echo "  Token obtained."

AUTH="Authorization: Bearer $TOKEN"

# 2. Get category IDs
echo "[2/3] Fetching categories..."
CATS=$(curl -s "$API/categories?flat=true" -H "$AUTH")

# Extract category IDs by name
get_cat_id() {
  echo "$CATS" | grep -o "\"id\":\"[^\"]*\",\"name\":\"$1\"" | head -1 | grep -o '"id":"[^"]*"' | cut -d'"' -f4
}

CAT_ELEC=$(get_cat_id "Electrónica")
CAT_ROPA=$(get_cat_id "Ropa")
CAT_HOGAR=$(get_cat_id "Hogar")
CAT_DEPO=$(get_cat_id "Deportes")
CAT_BELL=$(get_cat_id "Belleza")

echo "  Electrónica: $CAT_ELEC"
echo "  Ropa: $CAT_ROPA"
echo "  Hogar: $CAT_HOGAR"
echo "  Deportes: $CAT_DEPO"
echo "  Belleza: $CAT_BELL"

# 3. Create products
echo "[3/3] Creating products..."

create_product() {
  local name="$1"
  local price="$2"
  local compare="$3"
  local stock="$4"
  local cat="$5"
  local desc="$6"
  local image="$7"
  local featured="$8"
  local tags="$9"

  curl -s -X POST "$API/products" \
    -H "Content-Type: application/json" \
    -H "$AUTH" \
    -d "{
      \"name\": \"$name\",
      \"price\": $price,
      \"compare_price\": $compare,
      \"stock\": $stock,
      \"category_id\": \"$cat\",
      \"description\": \"$desc\",
      \"short_description\": \"$desc\",
      \"images\": [\"$image\"],
      \"is_featured\": $featured,
      \"tags\": $tags
    }" > /dev/null 2>&1

  echo "  + $name (\$$price)"
}

# ── Electrónica ─────────────────────
create_product "iPhone 15 Pro Max" 5499000 5999000 25 "$CAT_ELEC" \
  "Smartphone Apple con chip A17 Pro, pantalla Super Retina XDR de 6.7 pulgadas" \
  "https://images.unsplash.com/photo-1695048133142-1a20484d2569?w=400" \
  true '["apple","smartphone","iphone"]'

create_product "Samsung Galaxy S24 Ultra" 4999000 5499000 30 "$CAT_ELEC" \
  "Smartphone Samsung con S Pen integrado, cámara de 200MP, Galaxy AI" \
  "https://images.unsplash.com/photo-1610945265064-0e34e5519bbf?w=400" \
  true '["samsung","smartphone","galaxy"]'

create_product "MacBook Air M3" 5299000 5799000 15 "$CAT_ELEC" \
  "Laptop Apple con chip M3, 15 pulgadas, 8GB RAM, 256GB SSD" \
  "https://images.unsplash.com/photo-1517336714731-489689fd1ca8?w=400" \
  true '["apple","laptop","macbook"]'

create_product "AirPods Pro 2" 899000 999000 50 "$CAT_ELEC" \
  "Auriculares inalámbricos con cancelación activa de ruido y audio espacial" \
  "https://images.unsplash.com/photo-1606220945770-b5b6c2c55bf1?w=400" \
  false '["apple","auriculares","airpods"]'

create_product "Sony WH-1000XM5" 1299000 1499000 20 "$CAT_ELEC" \
  "Auriculares over-ear con la mejor cancelación de ruido del mercado" \
  "https://images.unsplash.com/photo-1618366712010-f4ae9c647dcb?w=400" \
  false '["sony","auriculares","noise-cancelling"]'

# ── Ropa ─────────────────────
create_product "Camiseta Nike Dri-FIT" 129000 159000 100 "$CAT_ROPA" \
  "Camiseta deportiva con tecnología Dri-FIT para máxima comodidad. Tallas: S, M, L, XL" \
  "https://images.unsplash.com/photo-1521572163474-6864f9cf17ab?w=400" \
  true '["nike","camiseta","deportiva","ropa"]'

create_product "Jeans Levi's 501 Original" 249000 299000 60 "$CAT_ROPA" \
  "El clásico jean recto que nunca pasa de moda. Tallas: 28-38" \
  "https://images.unsplash.com/photo-1542272454315-4c01d7abdf4a?w=400" \
  false '["levis","jeans","pantalon","ropa"]'

create_product "Chaqueta North Face Thermoball" 599000 749000 25 "$CAT_ROPA" \
  "Chaqueta aislante ligera perfecta para clima frío. Colores: Negro, Azul, Verde" \
  "https://images.unsplash.com/photo-1544923246-77307dd270ce?w=400" \
  true '["north-face","chaqueta","invierno"]'

create_product "Zapatillas Adidas Ultraboost" 599000 699000 40 "$CAT_ROPA" \
  "Zapatillas de running con boost en la mediasuela. Tallas: 7-12" \
  "https://images.unsplash.com/photo-1542291026-7eec264c27ff?w=400" \
  true '["adidas","zapatillas","running"]'

create_product "Vestido Zara Elegante" 189000 249000 35 "$CAT_ROPA" \
  "Vestido midi elegante para ocasiones especiales. Tallas: XS-XL. Colores: Negro, Rojo, Azul" \
  "https://images.unsplash.com/photo-1595777457583-95e059d581b8?w=400" \
  false '["zara","vestido","elegante"]'

# ── Hogar ─────────────────────
create_product "Cafetera Nespresso Vertuo" 799000 999000 20 "$CAT_HOGAR" \
  "Cafetera de cápsulas con tecnología Centrifusion para café perfecto" \
  "https://images.unsplash.com/photo-1517668808822-9ebb02f2a0e6?w=400" \
  true '["nespresso","cafetera","hogar"]'

create_product "Set de Sábanas Premium 600 Hilos" 299000 399000 40 "$CAT_HOGAR" \
  "Juego de sábanas de algodón egipcio 600 hilos. Tamaños: Sencilla, Doble, Queen, King" \
  "https://images.unsplash.com/photo-1631049307264-da0ec9d70304?w=400" \
  false '["sabanas","algodón","cama"]'

create_product "Aspiradora Robot iRobot Roomba" 1899000 2199000 10 "$CAT_HOGAR" \
  "Robot aspirador inteligente con mapeo y navegación avanzada" \
  "https://images.unsplash.com/photo-1558618666-fcd25c85f82e?w=400" \
  true '["irobot","aspiradora","robot","hogar"]'

# ── Deportes ─────────────────────
create_product "Bicicleta MTB Trek Marlin 7" 3499000 3999000 8 "$CAT_DEPO" \
  "Bicicleta de montaña con suspensión delantera RockShox, 29 pulgadas" \
  "https://images.unsplash.com/photo-1532298229144-0ec0c57515c7?w=400" \
  true '["trek","bicicleta","montaña"]'

create_product "Balón de Fútbol Adidas UCL" 149000 189000 80 "$CAT_DEPO" \
  "Balón oficial de la Champions League, tamaño 5" \
  "https://images.unsplash.com/photo-1614632537197-38a17061c2bd?w=400" \
  false '["adidas","futbol","balon"]'

create_product "Kit de Yoga Premium" 199000 249000 45 "$CAT_DEPO" \
  "Kit completo: mat, bloques, correa y bolsa de transporte" \
  "https://images.unsplash.com/photo-1544367567-0f2fcb009e0b?w=400" \
  false '["yoga","kit","fitness"]'

# ── Belleza ─────────────────────
create_product "Perfume Chanel N°5 EDP 100ml" 699000 799000 30 "$CAT_BELL" \
  "El icónico perfume floral-aldehdíco de la maison Chanel" \
  "https://images.unsplash.com/photo-1541643600914-78b084683601?w=400" \
  true '["chanel","perfume","fragancia"]'

create_product "Set de Cuidado Facial The Ordinary" 189000 239000 55 "$CAT_BELL" \
  "Set básico: limpiador, sérum de niacinamida, hidratante y protector solar" \
  "https://images.unsplash.com/photo-1556228578-8c89e6adf883?w=400" \
  false '["the-ordinary","skincare","facial"]'

create_product "Plancha de Cabello GHD Platinum+" 899000 1099000 15 "$CAT_BELL" \
  "Plancha profesional con tecnología predictiva. Temperatura óptima automática" \
  "https://images.unsplash.com/photo-1522337360788-8b13dee7a37e?w=400" \
  false '["ghd","plancha","cabello"]'

echo ""
echo "═══════════════════════════════════════"
echo "  ✓ 19 productos creados exitosamente"
echo "═══════════════════════════════════════"
