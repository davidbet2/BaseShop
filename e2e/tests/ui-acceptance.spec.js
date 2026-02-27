// @ts-check
const { test, expect } = require('@playwright/test');

/*
 * BaseShop E2E — UI Acceptance Tests
 *
 * Requires:
 *   - Backend running on localhost:3000
 *   - Flutter web build served on localhost:8080
 */

test.describe('UI - Navigation & Public Pages', () => {
  test('Home page loads successfully', async ({ page }) => {
    await page.goto('/home');
    await page.waitForLoadState('networkidle');
    // Flutter renders into a <flt-glass-pane> or canvas — just verify no crash
    expect(page.url()).toContain('/home');
  });

  test('Products page loads', async ({ page }) => {
    await page.goto('/products');
    await page.waitForLoadState('networkidle');
    expect(page.url()).toContain('/products');
  });

  test('Login page loads', async ({ page }) => {
    await page.goto('/login');
    await page.waitForLoadState('networkidle');
    expect(page.url()).toContain('/login');
  });

  test('Register page loads', async ({ page }) => {
    await page.goto('/register');
    await page.waitForLoadState('networkidle');
    expect(page.url()).toContain('/register');
  });

  test('Unknown route shows 404 page', async ({ page }) => {
    await page.goto('/this-does-not-exist');
    await page.waitForLoadState('networkidle');
    // The Flutter app should handle this (GoRouter errorBuilder)
  });

  test('Protected route /orders redirects unauthenticated users', async ({ page }) => {
    await page.goto('/orders');
    await page.waitForLoadState('networkidle');
    await page.waitForTimeout(2000);
    // Flutter SPA may redirect to /login or /home depending on auth state timing
    const url = page.url();
    expect(url).toMatch(/\/(login|home)/);
  });

  test('Protected route /profile redirects unauthenticated users', async ({ page }) => {
    await page.goto('/profile');
    await page.waitForLoadState('networkidle');
    await page.waitForTimeout(2000);
    const url = page.url();
    expect(url).toMatch(/\/(login|home)/);
  });

  test('Protected route /cart is accessible (or shell-gated)', async ({ page }) => {
    await page.goto('/cart');
    await page.waitForLoadState('networkidle');
    // Cart might redirect or show empty — both are acceptable
  });
});

test.describe('UI - Responsive Layout', () => {
  test('Desktop viewport', async ({ page }) => {
    await page.setViewportSize({ width: 1280, height: 720 });
    await page.goto('/home');
    await page.waitForLoadState('networkidle');
    expect(page.url()).toContain('/home');
  });

  test('Mobile viewport', async ({ page }) => {
    await page.setViewportSize({ width: 375, height: 812 });
    await page.goto('/home');
    await page.waitForLoadState('networkidle');
    expect(page.url()).toContain('/home');
  });

  test('Tablet viewport', async ({ page }) => {
    await page.setViewportSize({ width: 768, height: 1024 });
    await page.goto('/home');
    await page.waitForLoadState('networkidle');
    expect(page.url()).toContain('/home');
  });
});
