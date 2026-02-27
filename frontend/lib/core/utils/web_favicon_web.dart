// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:html' as html;

String _lastFaviconUrl = '';

/// Updates the browser tab favicon to the given [url].
/// Directly sets the <link> href — no preload to avoid CanvasKit timing issues.
void updateWebFavicon(String url) {
  if (url.isEmpty) return;
  if (url == _lastFaviconUrl) return;
  _lastFaviconUrl = url;

  // Use a short delay to ensure the DOM is ready after Flutter bootstraps
  Timer(const Duration(milliseconds: 300), () {
    try {
      final cacheBust = DateTime.now().millisecondsSinceEpoch;
      final separator = url.contains('?') ? '&' : '?';
      final faviconUrl = '$url${separator}v=$cacheBust';

      // Remove ALL existing favicon links to prevent browser caching old one
      html.document.querySelectorAll('link[rel*="icon"]').forEach((el) {
        el.remove();
      });

      // Create a fresh <link> element
      final link = html.LinkElement()
        ..id = 'dynamic-favicon'
        ..rel = 'icon'
        ..type = 'image/png'
        ..href = faviconUrl;
      html.document.head?.append(link);
    } catch (_) {}
  });
}

/// Updates the browser tab title.
void updateWebTitle(String title) {
  if (title.isEmpty) return;
  try {
    html.document.title = title;
  } catch (_) {}
}
