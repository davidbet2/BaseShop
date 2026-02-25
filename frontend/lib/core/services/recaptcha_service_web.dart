import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// Web: llama executeRecaptcha(action) definido en index.html
class RecaptchaService {
  static Future<String> execute(String action) async {
    try {
      // Check if function exists
      final hasFunction = globalContext.has('executeRecaptcha');
      if (!hasFunction) return '';

      // Call the function
      final promise = globalContext.callMethod<JSAny?>(
        'executeRecaptcha'.toJS,
        action.toJS,
      );
      if (promise == null) return '';

      // Await the promise
      final result = await (promise as JSPromise).toDart;
      if (result == null || result.isUndefinedOrNull) return '';

      // Convert to string
      final token = result.dartify();
      if (token is String && token.isNotEmpty) return token;

      return '';
    } catch (e) {
      return '';
    }
  }
}
