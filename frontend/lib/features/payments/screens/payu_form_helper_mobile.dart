// Submit PayU checkout form — platform stub (mobile).
// On mobile, this opens the PayU checkout URL via url_launcher.
import 'package:url_launcher/url_launcher.dart';

void submitPayUForm(Map<String, dynamic> formData) {
  // On mobile, we fall back to url_launcher.
  // PayU requires POST, so we build a GET approximation or use a data URI.
  // For full mobile support, consider webview_flutter.
  final checkoutUrl = formData['checkoutUrl']?.toString() ?? '';
  if (checkoutUrl.isNotEmpty) {
    launchUrl(Uri.parse(checkoutUrl), mode: LaunchMode.externalApplication);
  }
}
