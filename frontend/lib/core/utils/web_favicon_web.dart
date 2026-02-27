// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;

String _lastFaviconUrl = '';

/// Updates the browser tab favicon to the given [url].
/// Uses an Image element to preload — only applies if the image loads successfully.
void updateWebFavicon(String url) {
  if (url.isEmpty) return;
  if (url == _lastFaviconUrl) return;
  _lastFaviconUrl = url;
  try {
    // Preload the image first — only update the favicon if it loads correctly
    final testImg = html.ImageElement()..src = url;
    testImg.onLoad.first.then((_) {
      _applyFavicon(url);
    }).catchError((_) {
      // Image failed to load — keep the default favicon.png
    });
  } catch (_) {}
}

void _applyFavicon(String url) {
  try {
    var link = html.document.getElementById('dynamic-favicon') as html.LinkElement?;
    if (link == null) {
      link = html.LinkElement()
        ..id = 'dynamic-favicon'
        ..rel = 'icon';
      html.document.head?.append(link);
    }
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
