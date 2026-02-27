// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;

String _lastFaviconUrl = '';

/// Updates the browser tab favicon to the given [url].
/// Adds a cache-busting query param to force the browser to reload the icon.
void updateWebFavicon(String url) {
  if (url.isEmpty) return;
  if (url == _lastFaviconUrl) return;
  _lastFaviconUrl = url;
  try {
    var link = html.document.getElementById('dynamic-favicon') as html.LinkElement?;
    if (link == null) {
      link = html.LinkElement()
        ..id = 'dynamic-favicon'
        ..rel = 'icon';
      html.document.head?.append(link);
    }
    // Cache-busting: append timestamp so the browser fetches the new image
    final cacheBust = DateTime.now().millisecondsSinceEpoch;
    final separator = url.contains('?') ? '&' : '?';
    link.type = 'image/png';
    link.href = '$url${separator}v=$cacheBust';
  } catch (_) {}
}

/// Updates the browser tab title.
void updateWebTitle(String title) {
  if (title.isEmpty) return;
  try {
    html.document.title = title;
  } catch (_) {}
}
