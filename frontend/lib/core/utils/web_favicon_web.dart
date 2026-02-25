// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Updates the browser tab favicon to the given [url].
void updateWebFavicon(String url) {
  if (url.isEmpty) return;
  try {
    var link = html.document.getElementById('dynamic-favicon') as html.LinkElement?;
    if (link == null) {
      link = html.LinkElement()
        ..id = 'dynamic-favicon'
        ..rel = 'icon';
      html.document.head?.append(link);
    }
    link.type = 'image/png';
    link.href = url;
  } catch (_) {}
}

/// Updates the browser tab title.
void updateWebTitle(String title) {
  if (title.isEmpty) return;
  try {
    html.document.title = title;
  } catch (_) {}
}
