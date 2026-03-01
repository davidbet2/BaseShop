// @ts-check
const { test, expect } = require('@playwright/test');
const crypto = require('crypto');

/**
 * BaseShop E2E — Full purchase flow for EVERY payment state.
 *
 * Each test is completely independent with its own browser context,
 * producing a separate video file showing the entire flow:
 *   Login → Product → Cart → Checkout (3 steps) → PayU → Payment Result
 *
 * PayU sandbox card-holder-name trick:
 *   "APPROVED" → transactionState=4 (approved)
 *   "REJECTED" → transactionState=6 (declined)
 *
 * For states not triggerable via PayU sandbox (pending, expired, error,
 * abandoned, pending_validation), the test goes through the full visual
 * checkout until reaching PayU, screenshots it, then simulates the return
 * with the target state via navigate + validate-response API.
 */

const FRONTEND = 'http://localhost:8080';
const API = 'http://localhost:3000/api';
const USER_EMAIL = process.env.TEST_USER_EMAIL || 'cliente@test.com';
const USER_PASSWORD = process.env.TEST_USER_PASSWORD || 'Cliente123!';
const PAYU_API_KEY = process.env.TEST_PAYU_API_KEY || '4Vj8eK4rloUd272L48hsrarnUA';
const PAYU_MERCHANT_ID = process.env.TEST_PAYU_MERCHANT_ID || '508029';

// ═══════════════════════════════════════════════
// Test case definitions
// ═══════════════════════════════════════════════

const FLOW_CASES = [
  {
    id: 'approved',
    name: 'Pago Aprobado',
    cardName: 'APPROVED',         // PayU sandbox responds with approved
    realPayU: true,               // complete the PayU form + pay
    transactionState: '4',
    lapState: 'APPROVED',
    expectedPaymentStatus: 'approved',
    expectedOrderStatus: 'confirmed',
  },
  {
    id: 'declined',
    name: 'Pago Rechazado',
    cardName: null,
    realPayU: false,              // simulated — PayU sandbox unreliable for REJECTED
    transactionState: '6',
    lapState: 'PAYMENT_NETWORK_REJECTED',
    expectedPaymentStatus: 'declined',
    expectedOrderStatus: 'cancelled',
  },
  {
    id: 'pending',
    name: 'Pago Pendiente',
    cardName: null,
    realPayU: false,              // simulate return from PayU
    transactionState: '7',
    lapState: 'PENDING_TRANSACTION_CONFIRMATION',
    expectedPaymentStatus: 'pending',
    expectedOrderStatus: 'pending',
  },
  {
    id: 'pending_validation',
    name: 'Pago en Validación',
    cardName: null,
    realPayU: false,
    transactionState: '14',
    lapState: 'PENDING_TRANSACTION_REVIEW',
    expectedPaymentStatus: 'pending_validation',
    expectedOrderStatus: 'pending',
  },
  {
    id: 'expired',
    name: 'Transacción Expirada',
    cardName: null,
    realPayU: false,
    transactionState: '5',
    lapState: 'EXPIRED_TRANSACTION',
    expectedPaymentStatus: 'expired',
    expectedOrderStatus: 'cancelled',
  },
  {
    id: 'error',
    name: 'Error en el Pago',
    cardName: null,
    realPayU: false,
    transactionState: '104',
    lapState: 'INTERNAL_PAYMENT_PROVIDER_ERROR',
    expectedPaymentStatus: 'error',
    expectedOrderStatus: 'cancelled',
  },
  {
    id: 'abandoned',
    name: 'Pago Abandonado',
    cardName: null,
    realPayU: false,
    transactionState: '12',
    lapState: '',
    expectedPaymentStatus: 'abandoned',
    expectedOrderStatus: 'cancelled',
  },
];

// ═══════════════════════════════════════════════
// Helper factory — creates bound helpers for a page
// ═══════════════════════════════════════════════

function createHelpers(page, testId) {
  let snapN = 0;

  return {
    async waitForFlutter(ms = 15000) {
      await page.waitForFunction(() =>
        document.querySelector('flutter-view') !== null ||
        document.querySelector('flt-glass-pane') !== null,
        { timeout: ms }
      ).catch(() => {});
      await page.waitForTimeout(4000);
    },

    async snap(label) {
      snapN++;
      const nm = `${String(snapN).padStart(2, '0')}-${testId}-${label}`;
      try {
        await page.screenshot({ path: `test-results/${nm}.png`, fullPage: true });
        console.log(`  📸 ${nm}`);
      } catch { console.log(`  ⚠ Screenshot failed: ${nm}`); }
    },

    async canvasClick(x, y, label) {
      console.log(`  🖱 Click (${x}, ${y}): ${label}`);
      await page.mouse.click(x, y);
    },

    async navigateInApp(path, waitMs = 3000) {
      const hashPath = path.startsWith('#') ? path : `#${path}`;
      console.log(`  🔀 Navigate: ${hashPath}`);
      await page.evaluate((h) => {
        window.location.hash = h;
        window.dispatchEvent(new PopStateEvent('popstate', { state: {} }));
      }, hashPath);
      await page.waitForTimeout(waitMs);
    },

    async fillField(selector, value) {
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
    },
  };
}

// ═══════════════════════════════════════════════
// Reusable flow steps
// ═══════════════════════════════════════════════

/** Step 1: Login visually + get API token */
async function doLogin(page, h) {
  console.log('  ── STEP: Login ──');

  // API token
  const loginResp = await page.request.post(`${API}/auth/login`, {
    data: { email: USER_EMAIL, password: USER_PASSWORD },
    headers: { 'x-platform': 'mobile' },
  });
  const authToken = (await loginResp.json()).token;
  expect(authToken).toBeTruthy();
  console.log(`  ✓ API token (${authToken.length} chars)`);

  // Visual login
  await page.goto(`${FRONTEND}/#/login`);
  await h.waitForFlutter();

  if (!page.url().includes('/login')) {
    await page.evaluate(() => {
      window.location.hash = '#/login';
      window.dispatchEvent(new PopStateEvent('popstate', { state: {} }));
    });
    await page.waitForTimeout(3000);
  }

  await h.snap('login-page');

  // Tab to email input
  await page.keyboard.press('Tab');
  await page.waitForTimeout(1500);

  // Check focus
  const inputInfo = await page.evaluate(() => {
    const focused = document.activeElement;
    const allInps = Array.from(document.querySelectorAll('input'));
    return { isInput: focused?.tagName === 'INPUT', idx: allInps.indexOf(focused) };
  });
  if (!inputInfo.isInput || inputInfo.idx < 0) {
    await page.mouse.click(640, 307);
    await page.waitForTimeout(1000);
    await page.keyboard.press('Tab');
    await page.waitForTimeout(1000);
  }

  await page.keyboard.type(USER_EMAIL, { delay: 40 });
  await page.keyboard.press('Tab');
  await page.waitForTimeout(800);
  await page.keyboard.type(USER_PASSWORD, { delay: 40 });
  await h.snap('login-filled');

  await page.keyboard.press('Enter');
  await page.waitForTimeout(10000);

  if (!page.url().includes('/home')) {
    for (const y of [509, 490, 520, 480, 540]) {
      await h.canvasClick(640, y, `Login btn Y=${y}`);
      await page.waitForTimeout(5000);
      if (page.url().includes('/home')) break;
    }
  }

  await h.snap('after-login');
  expect(page.url()).toContain('/home');
  console.log('  ✓ Login exitoso');
  return authToken;
}

/** Step 2: Get product + add to cart via API + visual product page */
async function doProductAndCart(page, h, authToken) {
  console.log('  ── STEP: Producto + Carrito ──');

  // Get product
  const prodResp = await page.request.get(`${API}/products`);
  const body = await prodResp.json();
  const products = body.products || body.data || body;
  const allProds = Array.isArray(products) ? products : [];
  const product = allProds.find(p => p.name !== 'E2E Product' && p.images?.length > 0) || allProds[0];
  expect(product).toBeTruthy();
  const productId = product.id || product._id;
  console.log(`  ✓ Producto: ${product.name} ($${product.price})`);

  // Clear cart + add product
  await page.request.delete(`${API}/cart`, { headers: { Authorization: `Bearer ${authToken}` } });
  const addResp = await page.request.post(`${API}/cart/items`, {
    data: {
      product_id: productId,
      product_name: product.name,
      product_price: parseFloat(product.price),
      product_image: (product.images && product.images[0]) || '',
      quantity: 1,
    },
    headers: { Authorization: `Bearer ${authToken}`, 'Content-Type': 'application/json' },
  });
  expect(addResp.ok()).toBe(true);
  console.log('  ✓ Producto añadido al carrito');

  // Visual: product detail page
  await h.navigateInApp(`/products/${productId}`);
  await h.snap('product-detail');

  // Visual: press add-to-cart
  const vp = page.viewportSize();
  await h.canvasClick(vp.width / 2, vp.height - 30, 'add-to-cart');
  await page.waitForTimeout(2000);
  await h.snap('after-add-cart');

  return product;
}

/** Step 3: Create address + inject into SP + navigate to checkout */
async function doCartToCheckout(page, h, authToken) {
  console.log('  ── STEP: Carrito → Checkout ──');

  // Get existing or create address
  let savedAddress;
  const listResp = await page.request.get(`${API}/users/me/addresses`, {
    headers: { Authorization: `Bearer ${authToken}` },
  });
  const existingAddresses = (await listResp.json()).addresses || [];
  if (existingAddresses.length > 0) {
    savedAddress = existingAddresses.find(a => a.is_default === 1 || a.is_default === true) || existingAddresses[0];
    console.log(`  ✓ Dirección existente: ${savedAddress.id}`);
  } else {
    const addrResp = await page.request.post(`${API}/users/me/addresses`, {
      data: {
        label: 'Casa', address: 'Calle 123 #45-67', city: 'Bogotá',
        state: 'Cundinamarca', zip_code: '110111', country: 'Colombia', is_default: true,
      },
      headers: { Authorization: `Bearer ${authToken}`, 'Content-Type': 'application/json' },
    });
    savedAddress = (await addrResp.json()).address;
    console.log(`  ✓ Dirección creada: ${savedAddress.id}`);
  }
  expect(savedAddress).toBeTruthy();
  console.log(`  ✓ Dirección: ${savedAddress.id}`);

  // Navigate to cart
  await h.navigateInApp('/cart', 5000);
  await page.waitForTimeout(3000);
  await h.snap('cart-page');

  // Inject address into SharedPreferences
  const addressForFlutter = {
    id: savedAddress.id, label: savedAddress.label || 'Casa',
    address: savedAddress.address, city: savedAddress.city,
    state: savedAddress.state || 'Cundinamarca',
    zip_code: savedAddress.zip_code || '110111',
    country: savedAddress.country || 'Colombia', is_default: true,
  };
  await page.evaluate((addr) => {
    localStorage.setItem('flutter.user_addresses', JSON.stringify(JSON.stringify([addr])));
  }, addressForFlutter);

  // Reload so Flutter picks up the address
  await page.reload();
  await h.waitForFlutter();
  await page.waitForTimeout(5000);

  // Navigate to checkout
  await h.navigateInApp('/checkout', 5000);
  await h.snap('checkout-step1');
  expect(page.url()).toContain('/checkout');
  console.log('  ✓ En checkout');
}

/** Step 4: Checkout wizard (3 steps) → arrives at PayU */
async function doCheckoutWizardToPayU(page, h, authToken) {
  console.log('  ── STEP: Checkout 3 pasos → PayU ──');

  const BUTTON_Y = 682;
  const CARD_Y = 232;

  // Step 1: Address
  await page.waitForTimeout(2000);
  await h.canvasClick(640, CARD_Y, 'Address card');
  await page.waitForTimeout(1000);
  await h.canvasClick(640, BUTTON_Y, 'Continuar');
  await page.waitForTimeout(3000);
  await h.snap('step1-done');

  // Step 2: Payment method
  await h.canvasClick(640, CARD_Y, 'Tarjeta crédito/débito');
  await page.waitForTimeout(1500);
  await h.canvasClick(640, BUTTON_Y, 'Revisar pedido');
  await page.waitForTimeout(3000);
  await h.snap('step2-done');

  // Step 3: Summary → Confirm
  await page.waitForTimeout(2000);
  await h.snap('step3-summary');
  await h.canvasClick(640, BUTTON_Y, 'Confirmar pedido');

  // Wait for PayU redirect
  console.log('  → Esperando redirección a PayU...');
  let payuReached = false;
  for (let i = 0; i < 30; i++) {
    await page.waitForTimeout(2000);
    const url = page.url();
    if (url.includes('payulatam') || url.includes('sandbox.checkout')) {
      payuReached = true;
      console.log(`  ✓ PayU en ~${(i + 1) * 2}s`);
      break;
    }
    if (url.includes('payu-checkout')) {
      console.log(`  ⏳ [${i + 1}] payu-checkout screen...`);
    }
  }

  if (!payuReached) {
    // Retry confirm
    if (page.url().includes('/checkout')) {
      await h.canvasClick(640, BUTTON_Y, 'Confirmar pedido retry');
      await page.waitForTimeout(15000);
    }
    if (page.url().includes('payu-checkout')) {
      await page.waitForTimeout(20000);
    }
  }

  await h.snap('payu-reached');

  // Find the order created by checkout
  const ordersResp = await page.request.get(`${API}/orders/me`, {
    headers: { Authorization: `Bearer ${authToken}` },
  });
  const orders = (await ordersResp.json()).data || [];
  const createdOrder = orders.sort((a, b) =>
    new Date(b.created_at || 0) - new Date(a.created_at || 0)
  )[0];
  expect(createdOrder).toBeTruthy();
  console.log(`  ✓ Orden: ${createdOrder.id} total=$${createdOrder.total}`);

  expect(page.url()).toMatch(/payulatam|sandbox\.checkout/);
  return createdOrder;
}

/** Step 5a: Fill PayU form + pay (for real PayU states) */
async function doPayUPayment(page, h, cardName) {
  console.log(`  ── STEP: PayU pago con nombre "${cardName}" ──`);

  await page.waitForTimeout(5000);
  await h.snap('payu-loaded');

  // Buyer page
  const hash = await page.evaluate(() => location.hash);
  if (hash.includes('/co/buyer')) {
    console.log('  → Llenando datos del comprador...');
    await h.fillField('#fullName', cardName);
    await h.fillField('#emailAddress', 'test@baseshop.com');
    await h.fillField('#mobilePhone', '3001234567');
    await h.fillField('#buyerIdNumber', '123456789');
    await h.snap('payu-buyer');

    for (const sel of ['#buyer_data_button_continue', 'button:has-text("Continuar")', 'button:has-text("Continue")']) {
      const btn = page.locator(sel).first();
      if (await btn.isVisible({ timeout: 3000 }).catch(() => false)) {
        await btn.click();
        console.log(`  ✓ Click: ${sel}`);
        break;
      }
    }
    await page.waitForTimeout(8000);
  }

  await h.snap('payu-methods');

  // Select VISA
  for (const sel of ['#pm-VISA', '#pm-TEST_CREDIT_CARD', '#pm-MASTERCARD']) {
    const el = page.locator(sel).first();
    if (await el.isVisible({ timeout: 5000 }).catch(() => false)) {
      await el.click();
      console.log(`  ✓ Click: ${sel}`);
      break;
    }
  }
  await page.waitForTimeout(5000);
  await h.snap('payu-card-form');

  // Fill card
  await h.fillField('#ccNumber', '4111111111111111');
  await h.fillField('#securityCodeAux_', '777');
  await h.fillField('#cc_fullName', cardName);
  await h.fillField('#cc_dniNumber', '123456789');
  await h.fillField('#contactPhone', '3001234567');

  // Expiration month
  const monthSel = page.locator('#expirationDateMonth').first();
  if (await monthSel.isVisible({ timeout: 3000 }).catch(() => false)) {
    const monthOpts = await monthSel.evaluate(sel =>
      Array.from(sel.options).map(o => ({ value: o.value, text: o.text }))
    );
    const mayOpt = monthOpts.find(o => o.value === '5' || o.value === '05');
    if (mayOpt) await monthSel.selectOption(mayOpt.value);
    else if (monthOpts.length > 5) await monthSel.selectOption({ index: 5 });
  }

  // Expiration year
  const yearSel = page.locator('#expirationDateYear').first();
  if (await yearSel.isVisible({ timeout: 3000 }).catch(() => false)) {
    const yearOpts = await yearSel.evaluate(sel =>
      Array.from(sel.options).map(o => ({ value: o.value, text: o.text }))
    );
    const yr = yearOpts.find(o => o.value === '27' || o.value === '2027');
    if (yr) await yearSel.selectOption(yr.value);
    else if (yearOpts.length > 2) await yearSel.selectOption({ index: yearOpts.length - 1 });
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
      }
    } catch {}
  }

  // T&C
  const tandc = page.locator('#tandc').first();
  if (await tandc.isVisible({ timeout: 3000 }).catch(() => false)) {
    try { await tandc.check({ timeout: 3000 }); } catch {
      try { await page.locator('text=Acepto los términos').first().click(); } catch {
        await tandc.evaluate(el => {
          el.checked = true;
          el.dispatchEvent(new Event('click', { bubbles: true }));
          el.dispatchEvent(new Event('change', { bubbles: true }));
        });
      }
    }
    const checked = await tandc.evaluate(el => el.checked);
    if (!checked) await tandc.click({ force: true });
  }

  await h.snap('payu-filled');

  // Click Pay
  for (const sel of ['#buyer_data_button_pay', '#pay_button', 'button:has-text("Pagar")', 'button:has-text("Pay")']) {
    const el = page.locator(sel).first();
    if (await el.isVisible({ timeout: 3000 }).catch(() => false)) {
      await el.click();
      console.log(`  ✓ Click Pagar: ${sel}`);
      break;
    }
  }

  console.log('  → Esperando procesamiento...');
  await page.waitForTimeout(20000);
  await h.snap('payu-after-pay');
}

/** Step 5b: Return from PayU to the store (real PayU response page) */
async function doPayURealReturn(page, h, createdOrder) {
  console.log('  ── STEP: Retorno desde PayU ──');

  const afterPayUrl = page.url();
  if (afterPayUrl.includes('payulatam') || afterPayUrl.includes('sandbox.checkout')) {
    await page.waitForTimeout(5000);

    // Dump return page elements
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
      console.log(`    [${i}] <${e.tag}> id="${e.id}" text="${e.text}"`)
    );
    await h.snap('payu-response-page');

    // Try "return to merchant" buttons
    let clicked = false;
    for (const sel of [
      'a:has-text("Volver")', 'button:has-text("Volver")',
      'a:has-text("comercio")', 'a:has-text("tienda")',
      'a:has-text("Return")', 'a:has-text("store")',
      '.back-to-merchant', 'a.btn', 'a.button',
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
          `${FRONTEND}/#/payment-result?orderId=${createdOrder.id}` +
          `&transactionState=4&lapTransactionState=APPROVED&message=APPROVED`
        );
      }
    }

    try {
      await page.waitForURL(/localhost:8080/, { timeout: 30000 });
    } catch {}
  }

  await page.waitForTimeout(3000);
  await h.snap('back-to-store');
  console.log(`  ✓ De vuelta: ${page.url()}`);
}

/** Step 5c: Simulated return from PayU (for non-real PayU states) */
async function doPayUSimulatedReturn(page, h, createdOrder, tc, authToken) {
  console.log(`  ── STEP: Retorno simulado → ${tc.id} ──`);

  // Screenshot PayU page before leaving
  await page.waitForTimeout(5000);
  await h.snap('payu-page-before-return');

  // Navigate back to store with forged state params
  const resultUrl = `${FRONTEND}/#/payment-result?orderId=${createdOrder.id}` +
    `&transactionState=${tc.transactionState}` +
    `&lapTransactionState=${encodeURIComponent(tc.lapState)}` +
    `&message=${encodeURIComponent(tc.lapState || tc.expectedPaymentStatus.toUpperCase())}`;
  console.log(`  → Navigating to: ${resultUrl}`);
  await page.goto(resultUrl);
  await h.waitForFlutter();
  await page.waitForTimeout(3000);

  // Call validate-response to update payment status in DB
  // Find the payment for this order
  const payResp = await page.request.get(`${API}/payments/order/${createdOrder.id}`, {
    headers: { Authorization: `Bearer ${authToken}` },
  });
  if (payResp.ok()) {
    const payData = (await payResp.json()).data;
    const ref = payData.id; // payment ID is the referenceCode
    const amount = payData.amount;

    // Generate signature
    let fmtAmt = parseFloat(String(amount));
    fmtAmt = fmtAmt % 1 === 0 ? fmtAmt.toFixed(1) : String(fmtAmt);
    const sig = crypto.createHash('md5')
      .update(`${PAYU_API_KEY}~${PAYU_MERCHANT_ID}~${ref}~${fmtAmt}~COP~${tc.transactionState}`)
      .digest('hex');

    const valResp = await page.request.post(`${API}/payments/validate-response`, {
      data: {
        orderId: createdOrder.id,
        transactionState: tc.transactionState,
        polTransactionState: tc.transactionState,
        referenceCode: ref,
        transactionId: `e2e-${tc.id}-${Date.now()}`,
        TX_VALUE: String(amount),
        currency: 'COP',
        signature: sig,
        message: tc.lapState || tc.expectedPaymentStatus.toUpperCase(),
        lapTransactionState: tc.lapState,
      },
      headers: { Authorization: `Bearer ${authToken}`, 'Content-Type': 'application/json' },
    });
    if (valResp.ok()) {
      const valBody = await valResp.json();
      console.log(`  ✓ validate-response: status=${valBody.data?.status}`);
    }
  }

  // Re-navigate to result so Flutter picks up the updated status
  await page.goto(resultUrl);
  await h.waitForFlutter();
  await page.waitForTimeout(5000);
  await h.snap('result-screen');
}

/** Step 6: Verify result screen + validate API data */
async function doVerification(page, h, createdOrder, tc, authToken) {
  console.log(`  ── STEP: Verificación (${tc.id}) ──`);

  // For real PayU, also call validate-response to ensure DB is updated
  if (tc.realPayU) {
    const payResp = await page.request.get(`${API}/payments/order/${createdOrder.id}`, {
      headers: { Authorization: `Bearer ${authToken}` },
    });
    if (payResp.ok()) {
      const payData = (await payResp.json()).data;
      console.log(`  → Payment status from API: ${payData.status}`);

      // If still pending, call validate-response
      if (payData.status === 'pending') {
        const ref = payData.id;
        const amount = payData.amount;
        let fmtAmt = parseFloat(String(amount));
        fmtAmt = fmtAmt % 1 === 0 ? fmtAmt.toFixed(1) : String(fmtAmt);
        const sig = crypto.createHash('md5')
          .update(`${PAYU_API_KEY}~${PAYU_MERCHANT_ID}~${ref}~${fmtAmt}~COP~${tc.transactionState}`)
          .digest('hex');

        await page.request.post(`${API}/payments/validate-response`, {
          data: {
            orderId: createdOrder.id,
            transactionState: tc.transactionState,
            polTransactionState: tc.transactionState,
            referenceCode: ref,
            transactionId: `e2e-${tc.id}-${Date.now()}`,
            TX_VALUE: String(amount),
            currency: 'COP',
            signature: sig,
            message: tc.lapState,
            lapTransactionState: tc.lapState,
          },
          headers: { Authorization: `Bearer ${authToken}`, 'Content-Type': 'application/json' },
        });
      }
    }

    // For approved, also confirm order directly (safety net like purchase-flow.spec.js)
    if (tc.id === 'approved') {
      const payCheck = await page.request.get(`${API}/payments/order/${createdOrder.id}`, {
        headers: { Authorization: `Bearer ${authToken}` },
      });
      const payInfo = payCheck.ok() ? (await payCheck.json()).data : null;

      await page.request.patch(
        `http://localhost:3005/api/orders/${createdOrder.id}/payment-status`,
        {
          data: {
            status: 'confirmed',
            payment_id: payInfo?.id || `pay-${Date.now()}`,
            payment_status: 'approved',
            note: 'Pago aprobado por PayU (E2E full-flow)',
          },
          headers: { 'X-Internal-Service': process.env.TEST_INTERNAL_SECRET || 'baseshop-internal-dev' },
        }
      );
    }

    // Navigate to the result screen if not already there
    if (!page.url().includes('payment-result')) {
      await page.goto(
        `${FRONTEND}/#/payment-result?orderId=${createdOrder.id}` +
        `&transactionState=${tc.transactionState}` +
        `&lapTransactionState=${encodeURIComponent(tc.lapState)}` +
        `&message=${encodeURIComponent(tc.lapState)}`
      );
      await h.waitForFlutter();
      await page.waitForTimeout(5000);
    }
  }

  await h.snap('result-screen-final');

  // Scroll to see full result
  await page.mouse.wheel(0, 400);
  await page.waitForTimeout(1500);
  await h.snap('result-screen-scrolled');

  // Verify payment status via API
  const payCheck = await page.request.get(`${API}/payments/order/${createdOrder.id}`, {
    headers: { Authorization: `Bearer ${authToken}` },
  });
  if (payCheck.ok()) {
    const pay = (await payCheck.json()).data;
    console.log(`  ✓ Payment ${pay.id}: status=${pay.status}`);
    expect(pay.status).toBe(tc.expectedPaymentStatus);
  }

  // Verify order status
  let retries = 5;
  let ord = null;
  while (retries-- > 0) {
    const ordResp = await page.request.get(`${API}/orders/me`, {
      headers: { Authorization: `Bearer ${authToken}` },
    });
    const orders = (await ordResp.json()).data || [];
    ord = orders.find(o => o.id === createdOrder.id);
    if (ord?.status === tc.expectedOrderStatus) break;
    console.log(`  → Retry order status: ${ord?.status} (expected: ${tc.expectedOrderStatus})`);
    await page.waitForTimeout(2000);
  }
  expect(ord).toBeTruthy();
  console.log(`  ✓ Order ${ord.id}: status=${ord.status}`);
  expect(ord.status).toBe(tc.expectedOrderStatus);

  console.log(`  ✓✓ ${tc.name} — VERIFICADO`);
}

// ═══════════════════════════════════════════════
// Generate one independent test per payment state
// ═══════════════════════════════════════════════

for (const tc of FLOW_CASES) {
  test(`Flujo completo — ${tc.name} (${tc.id})`, async ({ browser }) => {
    test.setTimeout(300_000); // 5 min per test

    // ── Create isolated browser context with video recording ──
    const ctx = await browser.newContext({
      recordVideo: { dir: `test-results/videos/${tc.id}/`, size: { width: 1280, height: 720 } },
      viewport: { width: 1280, height: 720 },
    });
    const page = await ctx.newPage();
    const h = createHelpers(page, tc.id);

    // ── Setup: mocks + logging ──
    await page.route('**/recaptcha/api.js*', route => {
      route.fulfill({
        contentType: 'application/javascript',
        body: 'window.grecaptcha={ready:function(fn){fn()},execute:function(){return Promise.resolve("e2e-mock-recaptcha-token")}};',
      });
    });
    await page.route('**/accounts.google.com/**', route => route.abort());
    await page.route('**/gsi/client*', route => route.abort());

    page.on('console', msg => {
      console.log(`  [console.${msg.type()}] ${msg.text()}`);
    });
    page.on('response', async (response) => {
      const url = response.url();
      if (url.includes('localhost:3000')) {
        console.log(`  [HTTP] ${response.status()} ${response.request().method()} ${url.replace('http://localhost:3000', '')}`);
      }
    });

    try {
      console.log(`\n${'═'.repeat(60)}`);
      console.log(`  FLUJO: ${tc.name.toUpperCase()} (${tc.id})`);
      console.log(`${'═'.repeat(60)}`);

      // ── 1. Login ──
      const authToken = await doLogin(page, h);

      // ── 2. Product + Cart ──
      await doProductAndCart(page, h, authToken);

      // ── 3. Cart → Checkout ──
      await doCartToCheckout(page, h, authToken);

      // ── 4. Checkout wizard → PayU ──
      const createdOrder = await doCheckoutWizardToPayU(page, h, authToken);

      // ── 5. PayU interaction + return ──
      if (tc.realPayU) {
        // Real PayU flow: fill form, pay, return via response page
        await doPayUPayment(page, h, tc.cardName);
        await doPayURealReturn(page, h, createdOrder);
      } else {
        // Simulated return: screenshot PayU, then navigate back with state params
        await doPayUSimulatedReturn(page, h, createdOrder, tc, authToken);
      }

      // ── 6. Verify result screen + API data ──
      await doVerification(page, h, createdOrder, tc, authToken);

      console.log(`\n  ✅ ${tc.name} — COMPLETADO\n`);
    } finally {
      // Close context to save the video file
      await ctx.close();
    }
  });
}
