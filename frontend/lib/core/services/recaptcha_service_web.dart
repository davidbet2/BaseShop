import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// Web: llama executeRecaptcha(action) definido en index.html
class RecaptchaService {
  static Future<String> execute(String action) async {
    try {
      final result = globalContext.callMethod<JSPromise<JSString>>(
        'executeRecaptcha'.toJS,
        action.toJS,
      );
      final jsString = await result.toDart;
      return jsString.toDart;
    } catch (e) {
      return '';
    }
  }
}
