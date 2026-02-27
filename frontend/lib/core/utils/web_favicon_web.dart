// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:html' as html;

String _lastFaviconUrl = '';

/// Updates the browser tab favicon to the given [url].
/// Fetches the image via XHR (CORS-enabled) to bypass Cross-Origin-Resource-Policy,
/// then creates a same-origin blob URL for the <link> element.
void updateWebFavicon(String url) {
  if (url.isEmpty) return;
  if (url == _lastFaviconUrl) return;
  _lastFaviconUrl = url;

  // Short delay for DOM readiness after Flutter bootstrap
  Timer(const Duration(milliseconds: 500), () {
    try {
      // Fetch the image via XHR — uses CORS mode (allowed by gateway)
      final request = html.HttpRequest()
        ..open('GET', url)
        ..responseType = 'blob';

      request.onLoad.first.then((_) {
        if (request.status == 200 && request.response != null) {
          final blob = request.response as html.Blob;
          final blobUrl = html.Url.createObjectUrlFromBlob(blob);
          _setFaviconHref(blobUrl);
        }
      }).catchError((_) {});

      request.onError.first.then((_) {}).catchError((_) {});
      request.send();
    } catch (_) {}
  });
}

void _setFaviconHref(String href) {
  try {
    // Remove ALL existing favicon links
    html.document.querySelectorAll('link[rel*="icon"]').forEach((el) {
      el.remove();
    });
    // Create fresh <link>
    final link = html.LinkElement()
      ..id = 'dynamic-favicon'
      ..rel = 'icon'
      ..type = 'image/png'
      ..href = href;
    html.document.head?.append(link);
  } catch (_) {}
}

/// Updates the browser tab title.
void updateWebTitle(String title) {
  if (title.isEmpty) return;
  try {
    html.document.title = title;
  } catch (_) {}
}
