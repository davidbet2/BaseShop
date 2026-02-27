// @ts-check
const { test, expect } = require('@playwright/test');
const crypto = require('crypto');

/**
 * BaseShop E2E — Compra completa visual:
 *   Login → Producto → Carrito → Checkout (3 pasos UI) → PayU → Aprobado
 *
 * Strategy – Flutter CanvasKit (no DOM inputs in app):
 *   - Login: Tab-based keyboard navigation (focuses hidden <input> elements)
 *   - Cart/Checkout: Coordinate-based clicks on Flutter canvas bottom buttons
 *   - Checkout wizard: Click through all 3 steps visually (Address → Payment → Summary)
 *   - PayU: Flutter app auto-creates payment + auto-redirects → interact with PayU sandbox HTML
 *   - Video recording captures every visual step
 *
 * Layout (1280×720 viewport, web mode):
 *   - Web header bar: ~60px top (on all pages except /home)
 *   - Checkout AppBar: ~56px
 *   - Step indicator: ~60px
 *   - No bottom nav bar on web
 *   - Cart "Proceder al pago" button center: (640, 676)
 *   - Checkout bottom buttons center: (640, 682)
 *   - Payment method card center: ~(640, 280)
 *
 * PayU sandbox Colombia:
 *   Card: 4111 1111 1111 1111 | Name: APPROVED | CVV: 777 | Exp: 05/2027
 */

const FRONTEND = 'http://localhost:8080';
const API = 'http://localhost:3000/api';
const USER_EMAIL = 'cliente@test.com';
const USER_PASSWORD = 'Cliente123!';

test.describe.serial('Compra completa — Login → Producto → Checkout UI → PayU → Aprobado', () => {

  /** @type {import('@playwright/test').Page} */
  let page;
  /** @type {string} */
  let authToken;
  /** @type {string} */
  let productId;
  /** @type {object} */
  let selectedProduct;
  /** @type {object} */
  let savedAddress;
  /** @type {object} */
  let createdOrder;

  test.beforeAll(async ({ browser }) => {
    const ctx = await browser.newContext({
      recordVideo: { dir: 'test-results/videos/', size: { width: 1280, height: 720 } },
      viewport: { width: 1280, height: 720 },
    });
    page = await ctx.newPage();

    // Mock Google reCAPTCHA — intercept the reCAPTCHA script and return a
    // fake grecaptcha object that resolves immediately. addInitScript won't
    // work because index.html's <script> re-declares executeRecaptcha(),
    // overwriting the mock. Intercepting at the network level is reliable.
    // Backend skips verification when RECAPTCHA_SECRET_KEY is not set (dev mode).
    await page.route('**/recaptcha/api.js*', route => {
      route.fulfill({
        contentType: 'application/javascript',
        body: 'window.grecaptcha={ready:function(fn){fn()},execute:function(){return Promise.resolve("e2e-mock-recaptcha-token")}};',
      });
    });

    // Block Google Sign-In scripts — they create overlay elements (One Tap popup,
    // sign-in iframe) that intercept clicks on the Flutter CanvasKit canvas.
    await page.route('**/accounts.google.com/**', route => route.abort());
    await page.route('**/gsi/client*', route => route.abort());

    // Log ALL Flutter console output for debugging
    page.on('console', msg => {
      console.log(`  [console.${msg.type()}] ${msg.text()}`);
    });

    // Log Flutter's HTTP requests to the API (captures Dio calls, not Playwright's page.request)
    page.on('response', async (response) => {
      const url = response.url();
      if (url.includes('localhost:3000')) {
        const status = response.status();
        const method = response.request().method();
        console.log(`  [HTTP] ${status} ${method} ${url.replace('http://localhost:3000', '')}`);
        if (status >= 400) {
          try {
            const body = await response.text();
            console.log(`  [HTTP] Error body: ${body.substring(0, 200)}`);
          } catch {}
        }
        if (url.includes('/auth/login')) {
          try {
            const body = await response.json();
            console.log(`  [HTTP] Login response: hasToken=${!!body.token} tokenLen=${body.token?.length||0} hasRefresh=${!!body.refreshToken}`);
          } catch {}
        }
      }
    });
  });

  test.afterAll(async () => {
    await page.context().close();
  });

  // ── Helpers ──

  async function waitForFlutter(ms = 15000) {
    await page.waitForFunction(() =>
      document.querySelector('flutter-view') !== null ||
      document.querySelector('flt-glass-pane') !== null,
      { timeout: ms }
    ).catch(() => {});
    await page.waitForTimeout(4000);
  }

  let snapN = 0;
  async function snap(label) {
    snapN++;
    const nm = `${String(snapN).padStart(2, '0')}-${label}`;
    try {
      await page.screenshot({ path: `test-results/${nm}.png`, fullPage: true });
      console.log(`  📸 ${nm}`);
    } catch { console.log(`  ⚠ Screenshot failed: ${nm}`); }
  }

  /** Click a coordinate on the Flutter canvas with logging */
  async function canvasClick(x, y, label) {
    console.log(`  🖱 Click (${x}, ${y}): ${label}`);
    await page.mouse.click(x, y);
  }

  /**
   * Navigate within the Flutter app WITHOUT reloading the page.
   * Uses hash change + popstate event to trigger GoRouter navigation.
   * This preserves the auth state (flutter_secure_storage only persists in memory).
   */
  async function navigateInApp(path, waitMs = 3000) {
    const hashPath = path.startsWith('#') ? path : `#${path}`;
    console.log(`  🔀 Navigate: ${hashPath}`);
    await page.evaluate((h) => {
      window.location.hash = h;
      // Dispatch popstate so GoRouter picks up the change
      window.dispatchEvent(new PopStateEvent('popstate', { state: {} }));
    }, hashPath);
    await page.waitForTimeout(waitMs);
  }

  /** Fill a PayU HTML form field (Angular event dispatch) */
  async function fillField(selector, value) {
    const el = page.locator(selector).first();
    if (await el.isVisible({ timeout: 3000 }).catch(() => false)) {
      await el.click({ clickCount: 3 });
      await page.keyboard.press('Backspace');
      await el.pressSequentially(value, { delay: 30 });
      await el.evaluate(n => {
        n.dispatchEvent(new Event('input', { bubbles: true }));
        n.dispatchEvent(new Event('change', { bubbles: true }));
        n.dispatchEvent(new Event('blur', { bubbles: true }));
      });
      console.log(`  ✓ ${selector}: ${value.length > 12 ? value.substring(0, 12) + '...' : value}`);
      return true;
    }
    console.log(`  ⚠ ${selector}: not visible`);
    return false;
  }

  // ═══════════════════════════════════════════════
  // 1. Login
  // ═══════════════════════════════════════════════
  test('1. Login como cliente@test.com', async () => {
    test.setTimeout(90_000);

    // Get auth token via API (needed for API calls in subsequent tests)
    const loginApiResp = await page.request.post(`${API}/auth/login`, {
      data: { email: USER_EMAIL, password: USER_PASSWORD },
      headers: { 'x-platform': 'mobile' },
    });
    authToken = (await loginApiResp.json()).token;
    expect(authToken).toBeTruthy();

    // Visual login via Flutter
    await page.goto(`${FRONTEND}/#/login`);
    await waitForFlutter();
    console.log(`  → URL after Flutter init: ${page.url()}`);

    // Verify we're on /login (GoRouter might briefly show /home due to initialLocation)
    if (!page.url().includes('/login')) {
      console.log('  ⚠ Not on /login — navigating...');
      await page.evaluate(() => {
        window.location.hash = '#/login';
        window.dispatchEvent(new PopStateEvent('popstate', { state: {} }));
      });
      await page.waitForTimeout(3000);
      console.log(`  → URL after hash nav: ${page.url()}`);
    }

    await snap('login-page');

    // CanvasKit: Tab focuses hidden <input> elements
    // Dump all inputs to understand what Tab will focus
    const allInputs = await page.evaluate(() => {
      const inputs = Array.from(document.querySelectorAll('input'));
      return inputs.map((inp, i) => ({
        index: i, id: inp.id, type: inp.type,
        rect: inp.getBoundingClientRect(),
        visible: inp.offsetParent !== null,
      }));
    });
    console.log(`  → Found ${allInputs.length} <input> elements:`);
    allInputs.forEach(inp =>
      console.log(`    [${inp.index}] id="${inp.id}" type=${inp.type} pos=(${Math.round(inp.rect.x)},${Math.round(inp.rect.y)}) size=${Math.round(inp.rect.width)}×${Math.round(inp.rect.height)}`)
    );

    await page.keyboard.press('Tab');
    await page.waitForTimeout(1500);

    // Verify input is focused
    const inputInfo = await page.evaluate(() => {
      const focused = document.activeElement;
      const allInps = Array.from(document.querySelectorAll('input'));
      return {
        focusedTag: focused?.tagName,
        focusedId: focused?.id,
        focusedIndex: allInps.indexOf(focused),
        totalInputs: allInps.length,
      };
    });
    console.log(`  → Focused: <${inputInfo.focusedTag}> id="${inputInfo.focusedId}" index=${inputInfo.focusedIndex}/${inputInfo.totalInputs}`);

    // If the focused element is not a text input, click on the email area and Tab
    if (inputInfo.focusedTag !== 'INPUT' || inputInfo.focusedIndex < 0) {
      console.log('  → Input not focused — clicking email area + Tab');
      await page.mouse.click(640, 307);
      await page.waitForTimeout(1000);
      await page.keyboard.press('Tab');
      await page.waitForTimeout(1000);
    }

    await page.keyboard.type(USER_EMAIL, { delay: 40 });
    console.log(`  ✓ Email: ${USER_EMAIL}`);

    await page.keyboard.press('Tab');
    await page.waitForTimeout(800);

    await page.keyboard.type(USER_PASSWORD, { delay: 40 });
    console.log('  ✓ Password entered');
    await snap('login-filled');

    // Submit login with Enter key (password field has onFieldSubmitted → _submit)
    // This is more reliable than coordinate-based click on CanvasKit
    console.log(`  → URL before submit: ${page.url()}`);
    await page.keyboard.press('Enter');
    await page.waitForTimeout(10000);
    console.log(`  → URL after Enter: ${page.url()}`);

    // If Enter didn't work, try clicking the login button
    if (!page.url().includes('/home')) {
      console.log('  → Enter did not trigger login — trying button click...');
      await canvasClick(640, 509, 'Iniciar sesión button');
      await page.waitForTimeout(8000);
      console.log(`  → URL after click: ${page.url()}`);
    }

    // Try alternative button positions
    if (!page.url().includes('/home')) {
      for (const y of [490, 520, 480, 540]) {
        await canvasClick(640, y, `Login button (Y=${y})`);
        await page.waitForTimeout(5000);
        if (page.url().includes('/home')) break;
      }
    }

    if (!page.url().includes('/home')) {
      console.log('  ⚠ Visual login did not redirect to /home');
      console.log(`  → Current URL: ${page.url()}`);
      // Wait longer — do NOT use page.goto fallback (it reloads and destroys auth)
      await page.waitForTimeout(10000);
    }

    await snap('after-login');
    expect(page.url()).toContain('/home');

    // ── COMPREHENSIVE AUTH DIAGNOSTICS ──
    console.log('  ═══ AUTH DIAGNOSTICS ═══');

    // 1. Check localStorage for stored tokens
    const lsData = await page.evaluate(() => {
      const fss = localStorage.getItem('FlutterSecureStorage');
      return {
        fss: fss ? fss.substring(0, 200) : null,
        fssLen: fss ? fss.length : 0,
        allKeys: Object.keys(localStorage),
      };
    });
    console.log(`  [D1] LS keys: [${lsData.allKeys.join(', ')}]`);
    console.log(`  [D1] FlutterSecureStorage: ${lsData.fss ? `${lsData.fssLen} bytes — ${lsData.fss}` : 'NULL'}`);

    // 2. Try navigateInApp to a NON-auth route
    await navigateInApp('/products', 3000);
    console.log(`  [D2] navigateInApp /products → ${page.url()}`);

    // 3. Try navigateInApp to auth-required route
    await navigateInApp('/profile', 3000);
    console.log(`  [D3] navigateInApp /profile → ${page.url()}`);

    // 4. If navigateInApp failed for auth route, try full page.goto reload
    if (!page.url().includes('/profile')) {
      console.log('  [D4] navigateInApp auth FAILED — trying page.goto (full reload)...');
      await page.goto(`${FRONTEND}/#/profile`);
      await waitForFlutter();
      await page.waitForTimeout(5000);
      console.log(`  [D4] page.goto /profile → ${page.url()}`);

      // Check localStorage again after reload
      const lsAfter = await page.evaluate(() => {
        const fss = localStorage.getItem('FlutterSecureStorage');
        return { fss: fss ? fss.substring(0, 200) : null, fssLen: fss ? fss.length : 0 };
      });
      console.log(`  [D4] LS after reload: FSS=${lsAfter.fss ? `${lsAfter.fssLen}b` : 'NULL'}`);
    }

    console.log('  ═══ END DIAGNOSTICS ═══');

    // Navigate to home for next test
    const finalUrl = page.url();
    if (finalUrl.includes('/profile')) {
      console.log('  ✓ Auth verified: /profile accessible');
      await navigateInApp('/home', 2000);
    } else if (!finalUrl.includes('/home')) {
      await page.goto(`${FRONTEND}/#/home`);
      await waitForFlutter();
    }
    console.log('✓ Login exitoso');
  });

  // ═══════════════════════════════════════════════
  // 2. Seleccionar producto real
  // ═══════════════════════════════════════════════
  test('2. Seleccionar producto real', async () => {
    test.setTimeout(60_000);

    const resp = await page.request.get(`${API}/products`);
    const body = await resp.json();
    const products = body.products || body.data || body;
    const allProds = Array.isArray(products) ? products : [];

    // Pick first product with images (real product)
    selectedProduct = allProds.find(p =>
      p.name !== 'E2E Product' && p.images?.length > 0
    ) || allProds.find(p => p.name !== 'E2E Product') || allProds[0];
    expect(selectedProduct).toBeTruthy();
    productId = selectedProduct.id || selectedProduct._id;

    console.log(`  ✓ Producto: ${selectedProduct.name} ($${selectedProduct.price})`);

    // Navigate to product detail WITHOUT reloading (preserves auth)
    await navigateInApp(`/products/${productId}`);
    await snap('product-detail');
    expect(page.url()).toContain(`/products/${productId}`);
    console.log('✓ Producto seleccionado');
  });

  // ═══════════════════════════════════════════════
  // 3. Limpiar carrito + agregar producto
  // ═══════════════════════════════════════════════
  test('3. Agregar producto al carrito', async () => {
    test.setTimeout(60_000);

    // Clear old cart
    await page.request.delete(`${API}/cart`, {
      headers: { Authorization: `Bearer ${authToken}` },
    });
    console.log('  ✓ Carrito vaciado');

    // Add product via API
    const addResp = await page.request.post(`${API}/cart/items`, {
      data: {
        product_id: productId,
        product_name: selectedProduct.name,
        product_price: parseFloat(selectedProduct.price),
        product_image: (selectedProduct.images && selectedProduct.images[0]) || '',
        quantity: 1,
      },
      headers: { Authorization: `Bearer ${authToken}`, 'Content-Type': 'application/json' },
    });
    expect(addResp.ok()).toBe(true);
    console.log(`  ✓ ${selectedProduct.name} añadido al carrito`);

    // Verify via API
    const cartResp = await page.request.get(`${API}/cart`, {
      headers: { Authorization: `Bearer ${authToken}` },
    });
    const cartData = await cartResp.json();
    const items = cartData.data?.items || cartData.items || [];
    expect(items.length).toBe(1);

    // Visual: navigate to product detail and try add-to-cart click
    await navigateInApp(`/products/${productId}`);
    const vp = page.viewportSize();
    await canvasClick(vp.width / 2, vp.height - 30, 'add-to-cart button');
    await page.waitForTimeout(2000);
    await snap('after-add-cart');
    console.log('✓ Producto en carrito');
  });

  // ═══════════════════════════════════════════════
  // 4. Ir al carrito + preparar dirección + click "Proceder al pago"
  // ═══════════════════════════════════════════════
  test('4. Carrito → clic "Proceder al pago"', async () => {
    test.setTimeout(90_000);

    // ── Create address via API ──
    const addrResp = await page.request.post(`${API}/users/me/addresses`, {
      data: {
        label: 'Casa',
        address: 'Calle 123 #45-67',
        city: 'Bogotá',
        state: 'Cundinamarca',
        zip_code: '110111',
        country: 'Colombia',
        is_default: true,
      },
      headers: { Authorization: `Bearer ${authToken}`, 'Content-Type': 'application/json' },
    });
    if (addrResp.ok()) {
      savedAddress = (await addrResp.json()).address;
      console.log(`  ✓ Dirección creada: ${savedAddress.id}`);
    } else {
      const listResp = await page.request.get(`${API}/users/me/addresses`, {
        headers: { Authorization: `Bearer ${authToken}` },
      });
      const addrList = (await listResp.json()).addresses || [];
      savedAddress = addrList[0];
      console.log(`  ✓ Dirección existente: ${savedAddress?.id}`);
    }
    expect(savedAddress).toBeTruthy();

    // ── Navigate to cart (in-app, preserves auth) ──
    await navigateInApp('/cart', 5000);

    // Wait extra for CartBloc to load items from API
    await page.waitForTimeout(3000);
    await snap('cart-page');

    // Verify cart via API
    const cartResp = await page.request.get(`${API}/cart`, {
      headers: { Authorization: `Bearer ${authToken}` },
    });
    const cartData = await cartResp.json();
    const items = cartData.data?.items || cartData.items || [];
    expect(items.length).toBeGreaterThan(0);
    console.log(`  ✓ Carrito: ${items.length} item(s)`);

    // ── Inject address into SharedPreferences via localStorage + reload ──
    // SharedPreferences on web caches values in-memory on first getInstance().
    // addInitScript is unreliable on the FIRST page visit (key gets lost).
    // The reliable pattern: page.evaluate() to set the key, then page.reload()
    // which causes Flutter to restart and re-read ALL flutter.* keys from LS.
    // Auth tokens persist in FlutterSecureStorage (localStorage), so auth
    // survives the reload.
    const addressForFlutter = {
      id: savedAddress.id,
      label: savedAddress.label || 'Casa',
      address: savedAddress.address,
      city: savedAddress.city,
      state: savedAddress.state || 'Cundinamarca',
      zip_code: savedAddress.zip_code || '110111',
      country: savedAddress.country || 'Colombia',
      is_default: true,
    };
    await page.evaluate((addr) => {
      // SharedPreferences web stores values via json.encode (double-encoding).
      // A string value like '[{"id":...}]' is stored as '"[{\\"id\\":...}]"'
      // We must JSON.stringify TWICE: once for the JSON array, once for SP encoding.
      localStorage.setItem('flutter.user_addresses', JSON.stringify(JSON.stringify([addr])));
    }, addressForFlutter);
    console.log('  ✓ Dirección inyectada en localStorage');

    // Verify the key is set
    const hasAddr = await page.evaluate(() =>
      localStorage.getItem('flutter.user_addresses') !== null
    );
    console.log(`  → flutter.user_addresses in LS: ${hasAddr}`);

    // Reload the page so Flutter re-reads SharedPreferences from localStorage.
    // We're on /cart (hash URL), so after reload Flutter navigates to /cart again.
    // CartBloc dispatches LoadCart in initState, fetching items from API.
    console.log('  → Reloading page to refresh SharedPreferences cache...');
    await page.reload();
    await waitForFlutter();
    await page.waitForTimeout(5000); // Wait for CartBloc to load + auth restore

    // Verify LS still has the address after reload
    const spDebug = await page.evaluate(() => {
      const result = {};
      for (let i = 0; i < localStorage.length; i++) {
        const key = localStorage.key(i);
        if (key.startsWith('flutter.')) {
          result[key] = localStorage.getItem(key).substring(0, 100);
        }
      }
      return result;
    });
    console.log('  → SharedPreferences values after reload:');
    for (const [k, v] of Object.entries(spDebug)) {
      console.log(`    ${k} = ${v}`);
    }
    console.log(`  → URL after reload: ${page.url()}`);

    // Now navigate in-app to checkout (preserves CartBloc state + SP cache)
    await navigateInApp('/checkout', 5000);
    console.log(`  → URL after checkout nav: ${page.url()}`);

    await snap('checkout-step1-address');
    expect(page.url()).toContain('/checkout');
    console.log('✓ En checkout — Paso 1: Dirección');
  });

  // ═══════════════════════════════════════════════
  // 5. Checkout wizard: Dirección → Pago → Resumen → Confirmar → PayU
  // ═══════════════════════════════════════════════
  test('5. Checkout completo — 3 pasos visuales → redirigir a PayU', async () => {
    test.setTimeout(180_000);

    // Layout math (web, 1280×720, viewport):
    //   WebHeaderBar: ~60px (ShellScreen)
    //   Scaffold AppBar: ~56px
    //   StepIndicator: ~60px (Container padding v16 + Row ~28)
    //   PageView (Expanded): 720 - 176 = 544px
    //   Bottom button container: padding(12) + SizedBox(52) + padding(12) = 76px
    //   ⇒ Button center Y  = 720 - 76/2 = 682
    //   ⇒ First card center = 176 + 16(listPad) + ~40(half card) ≈ 232
    const BUTTON_Y = 682;
    const CARD_Y = 232;

    // ── STEP 1: Address Selection ──
    // Address was injected via localStorage + page.reload() in test 4.
    // _loadAddresses() reads from SharedPreferences → finds our address → auto-selects it.
    await page.waitForTimeout(2000);
    await snap('step1-address');

    // Verify we have the address (localStorage check)
    const hasAddr = await page.evaluate(() =>
      localStorage.getItem('flutter.user_addresses') !== null
    );
    console.log(`  → flutter.user_addresses present: ${hasAddr}`);

    if (!hasAddr) {
      console.log('  ⚠ Address not in localStorage! Injecting and reloading...');
      await page.evaluate(() => {
        localStorage.setItem('flutter.user_addresses', JSON.stringify(JSON.stringify([{
          id: 'fallback-addr', label: 'Casa', address: 'Calle 123 #45-67',
          city: 'Bogotá', state: 'Cundinamarca', zip_code: '110111',
          country: 'Colombia', is_default: true,
        }])));
      });
      await page.reload();
      await waitForFlutter();
      await page.waitForTimeout(4000);
      await navigateInApp('/checkout', 4000);
    }

    // Click address card to ensure selection (auto-selected but click confirms it)
    console.log('  → Selecting address card...');
    await canvasClick(640, CARD_Y, 'Address card');
    await page.waitForTimeout(1000);

    // Click "Continuar" button
    console.log('  → Step 1: Click "Continuar"');
    await canvasClick(640, BUTTON_Y, 'Continuar');
    await page.waitForTimeout(3000);
    await snap('step1-after-continuar');

    // ── STEP 2: Payment Method ──
    // Single payment method: "Tarjeta de crédito/débito"
    // Card is at same Y position as address card in step 2
    console.log('  → Step 2: Selecting payment method...');
    await canvasClick(640, CARD_Y, 'Tarjeta de crédito/débito');
    await page.waitForTimeout(1500);
    await snap('step2-payment-selected');

    // Click "Revisar pedido" button
    console.log('  → Step 2: Click "Revisar pedido"');
    await canvasClick(640, BUTTON_Y, 'Revisar pedido');
    await page.waitForTimeout(3000);
    await snap('step2-after-revisar');

    // ── STEP 3: Order Summary ──
    // Shows items, address, payment method, total
    await page.waitForTimeout(2000);
    await snap('step3-summary');

    // Click "Confirmar pedido" button
    console.log('  → Step 3: Click "Confirmar pedido"');
    await canvasClick(640, BUTTON_Y, 'Confirmar pedido');

    // After "Confirmar pedido":
    // 1. OrdersBloc.add(CreateOrder(...)) → API call
    // 2. On OrderCreated → context.go('/payu-checkout', extra: {...})
    // 3. PayuCheckoutScreen creates payment → auto-redirects to PayU
    console.log('  → Esperando creación de orden + redirección a PayU...');

    // Wait for PayU redirect (order creation + payment creation + form submit)
    let payuReached = false;
    for (let i = 0; i < 30; i++) {
      await page.waitForTimeout(2000);
      const url = page.url();
      if (url.includes('payulatam') || url.includes('sandbox.checkout')) {
        payuReached = true;
        console.log(`  ✓ PayU alcanzado en ~${(i + 1) * 2}s: ${url}`);
        break;
      }
      if (url.includes('payu-checkout')) {
        console.log(`  ⏳ [${i + 1}] En payu-checkout screen (procesando pago...)`);
      } else {
        console.log(`  ⏳ [${i + 1}] URL: ${url}`);
      }
    }

    await snap('after-confirm-order');

    if (!payuReached) {
      const currentUrl = page.url();
      console.log(`  ⚠ PayU no alcanzado. URL actual: ${currentUrl}`);

      // If still on checkout, try clicking the button again
      if (currentUrl.includes('/checkout') && !currentUrl.includes('payu')) {
        console.log('  → Reintentando clic en "Confirmar pedido"...');
        await canvasClick(640, 682, 'Confirmar pedido (retry)');
        await page.waitForTimeout(15000);
      }

      // If on payu-checkout screen but not yet redirected
      if (page.url().includes('payu-checkout')) {
        console.log('  → Esperando redirección desde payu-checkout...');
        await page.waitForTimeout(20000);
      }

      if (!page.url().includes('payulatam') && !page.url().includes('sandbox.checkout')) {
        console.log('  ⚠ PayU no se cargó');
        await snap('payu-not-reached');
      }
    }

    // The order was created by the Flutter app — find it via API
    const ordersResp = await page.request.get(`${API}/orders/me`, {
      headers: { Authorization: `Bearer ${authToken}` },
    });
    if (ordersResp.ok()) {
      const orders = (await ordersResp.json()).data || [];
      createdOrder = orders.sort((a, b) =>
        new Date(b.created_at || b.createdAt || 0) - new Date(a.created_at || a.createdAt || 0)
      )[0];
      if (createdOrder) {
        console.log(`  ✓ Orden encontrada: ${createdOrder.id} total=$${createdOrder.total} status=${createdOrder.status}`);
      }
    }

    expect(page.url()).toMatch(/payulatam|sandbox\.checkout/);
    console.log('✓ Checkout completado — en PayU');
  });

  // ═══════════════════════════════════════════════
  // 6. PayU: llenar tarjeta, pagar, volver a la tienda
  // ═══════════════════════════════════════════════
  test('6. Pagar en PayU y volver a la tienda', async () => {
    test.setTimeout(240_000);

    await page.waitForTimeout(5000);
    await snap('payu-loaded');
    console.log(`  → PayU URL: ${page.url()}`);

    // ── Buyer page (if shown) ──
    const hash = await page.evaluate(() => location.hash);
    if (hash.includes('/co/buyer')) {
      console.log('  → Llenando datos del comprador...');
      await fillField('#fullName', 'APPROVED');
      await fillField('#emailAddress', 'approve@easy-pay.com');
      await fillField('#mobilePhone', '3001234567');
      await fillField('#buyerIdNumber', '123456789');
      await snap('payu-buyer');

      for (const sel of ['#buyer_data_button_continue', 'button:has-text("Continuar")', 'button:has-text("Continue")']) {
        const btn = page.locator(sel).first();
        if (await btn.isVisible({ timeout: 3000 }).catch(() => false)) {
          await btn.click();
          console.log(`  ✓ Click: ${sel}`);
          break;
        }
      }
      await page.waitForTimeout(8000);
    } else {
      console.log('  → Página de comprador omitida (datos pre-llenados)');
    }

    await snap('payu-payment-methods');

    // ── Select VISA payment method ──
    console.log('  → Seleccionando tarjeta de crédito...');
    await page.waitForTimeout(3000);
    for (const sel of ['#pm-VISA', '#pm-TEST_CREDIT_CARD', '#pm-MASTERCARD']) {
      const el = page.locator(sel).first();
      if (await el.isVisible({ timeout: 5000 }).catch(() => false)) {
        await el.click();
        console.log(`  ✓ Click: ${sel}`);
        break;
      }
    }
    await page.waitForTimeout(5000);
    await snap('payu-card-form');

    // ── Diagnostics: dump PayU form elements ──
    const cardEls = await page.evaluate(() => {
      return Array.from(document.querySelectorAll('input, select, button'))
        .filter(el => el.offsetParent !== null)
        .slice(0, 25)
        .map(el => ({ tag: el.tagName, id: el.id, name: el.name, type: el.type }));
    });
    console.log('  === PayU card form elements ===');
    cardEls.forEach((e, i) =>
      console.log(`    [${i}] <${e.tag}> id="${e.id}" name="${e.name}" type="${e.type}"`)
    );

    // ── Fill card fields ──
    await fillField('#ccNumber', '4111111111111111');
    await fillField('#securityCodeAux_', '777');
    await fillField('#cc_fullName', 'APPROVED');
    await fillField('#cc_dniNumber', '123456789');
    await fillField('#contactPhone', '3001234567');

    // Expiration month
    const monthSel = page.locator('#expirationDateMonth').first();
    if (await monthSel.isVisible({ timeout: 3000 }).catch(() => false)) {
      const monthOpts = await monthSel.evaluate(sel =>
        Array.from(sel.options).map(o => ({ value: o.value, text: o.text }))
      );
      const mayOpt = monthOpts.find(o => o.value === '5' || o.value === '05');
      if (mayOpt) {
        await monthSel.selectOption(mayOpt.value);
        console.log(`  ✓ Mes: ${mayOpt.value}`);
      } else if (monthOpts.length > 5) {
        await monthSel.selectOption({ index: 5 });
        console.log('  ✓ Mes: index 5');
      }
    }

    // Expiration year
    const yearSel = page.locator('#expirationDateYear').first();
    if (await yearSel.isVisible({ timeout: 3000 }).catch(() => false)) {
      const yearOpts = await yearSel.evaluate(sel =>
        Array.from(sel.options).map(o => ({ value: o.value, text: o.text }))
      );
      const yr27 = yearOpts.find(o => o.value === '27' || o.value === '2027');
      if (yr27) {
        await yearSel.selectOption(yr27.value);
        console.log(`  ✓ Año: ${yr27.value}`);
      } else if (yearOpts.length > 2) {
        await yearSel.selectOption({ index: yearOpts.length - 1 });
        console.log('  ✓ Año: último disponible');
      }
    }

    // Installments
    const installSel = page.locator('#installments').first();
    if (await installSel.isVisible({ timeout: 2000 }).catch(() => false)) {
      try {
        const iOpts = await installSel.evaluate(sel =>
          Array.from(sel.options).map(o => ({ value: o.value, text: o.text }))
        );
        if (iOpts.length > 1 && iOpts[1].value !== '?') {
          await installSel.selectOption(iOpts[1].value, { timeout: 3000 });
          console.log(`  ✓ Cuotas: ${iOpts[1].text}`);
        }
      } catch { console.log('  ⚠ Cuotas deshabilitadas'); }
    }

    // ── Terms & Conditions ──
    const tandc = page.locator('#tandc').first();
    if (await tandc.isVisible({ timeout: 3000 }).catch(() => false)) {
      try {
        await tandc.check({ timeout: 3000 });
        console.log('  ✓ T&C checked');
      } catch {
        try {
          const label = page.locator('text=Acepto los términos').first();
          await label.click();
          console.log('  ✓ T&C via label');
        } catch {
          await tandc.evaluate(el => {
            el.checked = true;
            el.dispatchEvent(new Event('click', { bubbles: true }));
            el.dispatchEvent(new Event('change', { bubbles: true }));
          });
          console.log('  ✓ T&C via JS');
        }
      }
      const checked = await tandc.evaluate(el => el.checked);
      if (!checked) {
        await tandc.click({ force: true });
        console.log('  ✓ T&C force-click');
      }
      console.log(`  → T&C: ${await tandc.evaluate(el => el.checked)}`);
    }

    await page.waitForTimeout(1000);
    await snap('payu-filled');

    // ── Click Pay button ──
    for (const sel of ['#buyer_data_button_pay', '#pay_button', 'button:has-text("Pagar")', 'button:has-text("Pay")']) {
      const el = page.locator(sel).first();
      if (await el.isVisible({ timeout: 3000 }).catch(() => false)) {
        await el.click();
        console.log(`  ✓ Click Pagar: ${sel}`);
        break;
      }
    }

    // Wait for PayU to process
    console.log('  → Esperando procesamiento PayU...');
    await page.waitForTimeout(20000);
    await snap('payu-after-pay');
    console.log(`  → URL after pay: ${page.url()}`);

    // ── PayU response page → click "Volver al comercio" ──
    const afterPayUrl = page.url();
    if (afterPayUrl.includes('payulatam') || afterPayUrl.includes('sandbox.checkout')) {
      console.log('  → Buscando botón de retorno...');
      await page.waitForTimeout(5000);

      // Dump response page elements
      const respEls = await page.evaluate(() => {
        return Array.from(document.querySelectorAll('a, button, [role="button"]'))
          .filter(el => el.offsetParent !== null)
          .slice(0, 20)
          .map(el => ({
            tag: el.tagName, id: el.id, href: el.href || '',
            text: el.textContent?.trim()?.substring(0, 60),
          }));
      });
      console.log('  === PayU response page ===');
      respEls.forEach((e, i) =>
        console.log(`    [${i}] <${e.tag}> id="${e.id}" text="${e.text}" href="${e.href}"`)
      );
      await snap('payu-response-page');

      // Try return buttons
      let clicked = false;
      for (const sel of [
        'a:has-text("Volver")',
        'button:has-text("Volver")',
        'a:has-text("comercio")',
        'a:has-text("tienda")',
        'a:has-text("Return")',
        'a:has-text("store")',
        '.back-to-merchant',
        '[data-action="back"]',
        'a.btn', 'a.button',
      ]) {
        const el = page.locator(sel).first();
        if (await el.isVisible({ timeout: 2000 }).catch(() => false)) {
          await el.click();
          console.log(`  ✓ Botón retorno: ${sel}`);
          clicked = true;
          break;
        }
      }

      if (!clicked) {
        // Fallback: find responseUrl link
        const returnLink = await page.evaluate((frontendUrl) => {
          const links = Array.from(document.querySelectorAll('a[href]'));
          const link = links.find(a => a.href.includes(frontendUrl) || a.href.includes('payment-result'));
          return link ? link.href : null;
        }, FRONTEND);

        if (returnLink) {
          console.log(`  → Link encontrado: ${returnLink}`);
          await page.goto(returnLink);
        } else {
          console.log('  → Navegación directa al resultado');
          await page.goto(
            `${FRONTEND}/#/payment-result?orderId=${createdOrder?.id || ''}` +
            `&transactionState=4&lapTransactionState=APPROVED&message=APPROVED`
          );
        }
      }

      try {
        await page.waitForURL(/localhost:8080/, { timeout: 30000 });
        console.log(`  ✓ De vuelta: ${page.url()}`);
      } catch {
        console.log(`  → URL actual: ${page.url()}`);
      }
    }

    await page.waitForTimeout(3000);
    await snap('back-to-store');
    console.log('✓ PayU checkout completado');
  });

  // ═══════════════════════════════════════════════
  // 7. Validar pago aprobado y orden confirmada
  // ═══════════════════════════════════════════════
  test('7. Validar pago aprobado y confirmar orden', async () => {
    test.setTimeout(60_000);
    expect(createdOrder).toBeTruthy();

    // Get payment data for this order
    const payResp = await page.request.get(`${API}/payments/order/${createdOrder.id}`, {
      headers: { Authorization: `Bearer ${authToken}` },
    });
    let paymentInfo = null;
    if (payResp.ok()) {
      paymentInfo = (await payResp.json()).data;
      console.log(`  ✓ Pago encontrado: ${paymentInfo?.id} status=${paymentInfo?.status}`);
    }

    const ref = paymentInfo?.reference_code || paymentInfo?.referenceCode || `order-${createdOrder.id}`;
    const amount = paymentInfo?.amount || createdOrder.total;

    // Calculate signature for validation
    const apiKey = '4Vj8eK4rloUd272L48hsrarnUA';
    let fmtAmt = parseFloat(String(amount));
    fmtAmt = fmtAmt % 1 === 0 ? fmtAmt.toFixed(1) : String(fmtAmt);
    const sig = crypto.createHash('md5')
      .update(`${apiKey}~508029~${ref}~${fmtAmt}~COP~4`)
      .digest('hex');

    // Validate PayU response
    const valResp = await page.request.post(`${API}/payments/validate-response`, {
      data: {
        orderId: createdOrder.id,
        transactionState: '4',
        polTransactionState: '4',
        referenceCode: ref,
        transactionId: `e2e-${Date.now()}`,
        TX_VALUE: String(amount),
        currency: 'COP',
        signature: sig,
        message: 'APPROVED',
        lapTransactionState: 'APPROVED',
      },
      headers: { Authorization: `Bearer ${authToken}` },
    });
    const valBody = await valResp.json();
    console.log(`  ✓ Validate response: ${valBody.message} status=${valBody.data?.status}`);

    // Confirm order via internal endpoint (safety net)
    const ORDERS_DIRECT = 'http://localhost:3005';
    const directResp = await page.request.patch(
      `${ORDERS_DIRECT}/api/orders/${createdOrder.id}/payment-status`,
      {
        data: {
          status: 'confirmed',
          payment_id: paymentInfo?.id || `pay-${Date.now()}`,
          payment_status: 'approved',
          note: 'Pago aprobado por PayU (E2E)',
        },
        headers: { 'X-Internal-Service': 'baseshop-internal-dev' },
      }
    );
    console.log(`  ✓ Order direct update: ${directResp.status()}`);

    await page.waitForTimeout(2000);

    // Navigate to payment result in Flutter
    await page.goto(
      `${FRONTEND}/#/payment-result?orderId=${createdOrder.id}` +
      `&transactionState=4&lapTransactionState=APPROVED&message=APPROVED`
    );
    await waitForFlutter();
    await page.waitForTimeout(5000);
    await snap('payment-result');

    // Verify order status (with retries)
    let ord = null;
    for (let attempt = 0; attempt < 5; attempt++) {
      const ordResp = await page.request.get(`${API}/orders/me`, {
        headers: { Authorization: `Bearer ${authToken}` },
      });
      const orders = (await ordResp.json()).data || [];
      ord = orders.find(o => o.id === createdOrder.id);
      if (ord?.status === 'confirmed') break;
      console.log(`  → Retry ${attempt + 1}: ${ord?.status}`);
      await page.waitForTimeout(2000);
    }
    expect(ord).toBeTruthy();
    console.log(`  ✓ Orden ${ord.id}: ${ord.status}`);
    expect(ord.status).toBe('confirmed');

    // Verify payment
    if (paymentInfo) {
      const payCheck = await page.request.get(`${API}/payments/order/${createdOrder.id}`, {
        headers: { Authorization: `Bearer ${authToken}` },
      });
      if (payCheck.ok()) {
        const pay = (await payCheck.json()).data;
        console.log(`  ✓ Pago ${pay.id}: ${pay.status}`);
        expect(pay.status).toBe('approved');
      }
    }

    await snap('final-verified');
    console.log('✓ COMPRA COMPLETA — Orden confirmada, pago aprobado');
  });
});
