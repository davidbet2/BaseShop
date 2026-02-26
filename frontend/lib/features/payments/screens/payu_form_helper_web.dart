// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Submit PayU checkout form on Flutter Web.
/// Creates a hidden HTML form and submits it to PayU's checkout gateway.
void submitPayUForm(Map<String, dynamic> formData) {
  final checkoutUrl = formData['checkoutUrl']?.toString() ?? '';
  if (checkoutUrl.isEmpty) return;

  // Create form element
  final form = html.FormElement()
    ..method = 'POST'
    ..action = checkoutUrl
    ..target = '_self'; // Submit in same window

  // Map of PayU form field names to our data keys
  final fields = <String, String>{
    'merchantId': formData['merchantId']?.toString() ?? '',
    'accountId': formData['accountId']?.toString() ?? '',
    'description': formData['description']?.toString() ?? '',
    'referenceCode': formData['referenceCode']?.toString() ?? '',
    'amount': formData['amount']?.toString() ?? '',
    'tax': formData['tax']?.toString() ?? '0',
    'taxReturnBase': formData['taxReturnBase']?.toString() ?? '0',
    'currency': formData['currency']?.toString() ?? 'COP',
    'signature': formData['signature']?.toString() ?? '',
    'test': formData['test']?.toString() ?? '1',
    'buyerEmail': formData['buyerEmail']?.toString() ?? '',
    'buyerFullName': formData['buyerFullName']?.toString() ?? '',
    'responseUrl': formData['responseUrl']?.toString() ?? '',
    'confirmationUrl': formData['confirmationUrl']?.toString() ?? '',
  };

  // Add hidden inputs for each field
  for (final entry in fields.entries) {
    final input = html.InputElement()
      ..type = 'hidden'
      ..name = entry.key
      ..value = entry.value;
    form.append(input);
  }

  // Append form to body, submit, then remove
  html.document.body?.append(form);
  form.submit();
}
