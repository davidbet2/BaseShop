/// Stub para Android/iOS — reCAPTCHA v3 es solo browser.
/// El backend acepta token vacío para clientes mobile (X-Platform: mobile).
class RecaptchaService {
  static Future<String> execute(String action) async => '';
}
