/// Updates the browser tab favicon and title dynamically.
/// Uses conditional imports — noop on mobile/desktop.
export 'web_favicon_stub.dart'
    if (dart.library.html) 'web_favicon_web.dart';

