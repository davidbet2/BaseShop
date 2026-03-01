// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

/// Web implementation: uses HTML Canvas to resize and compress images.
Future<Uint8List> compressImageBytesImpl(
  Uint8List bytes, {
  int maxWidth = 1200,
  int maxHeight = 1200,
  int quality = 80,
}) async {
  // Create a blob from the bytes
  final blob = html.Blob([bytes]);
  final blobUrl = html.Url.createObjectUrlFromBlob(blob);

  try {
    // Load image element
    final img = html.ImageElement();
    final completer = Completer<void>();
    img.onLoad.listen((_) => completer.complete());
    img.onError.listen((_) => completer.completeError('Failed to load image'));
    img.src = blobUrl;
    await completer.future;

    // Calculate new dimensions maintaining aspect ratio
    int origWidth = img.naturalWidth;
    int origHeight = img.naturalHeight;

    // If already small enough and likely small file, return as-is
    if (origWidth <= maxWidth && origHeight <= maxHeight && bytes.length < 500 * 1024) {
      return bytes;
    }

    double scale = 1.0;
    if (origWidth > maxWidth || origHeight > maxHeight) {
      final scaleW = maxWidth / origWidth;
      final scaleH = maxHeight / origHeight;
      scale = scaleW < scaleH ? scaleW : scaleH;
    }

    final newWidth = (origWidth * scale).round();
    final newHeight = (origHeight * scale).round();

    // Draw to canvas
    final canvas = html.CanvasElement(width: newWidth, height: newHeight);
    final ctx = canvas.context2D;
    ctx.drawImageScaled(img, 0, 0, newWidth, newHeight);

    // Export as JPEG blob with quality
    final exportCompleter = Completer<html.Blob>();
    canvas.toBlob('image/jpeg', quality / 100.0).then((blob) {
      exportCompleter.complete(blob);
    });

    final jpegBlob = await exportCompleter.future;

    // Read blob as bytes
    final reader = html.FileReader();
    final readerCompleter = Completer<Uint8List>();
    reader.onLoadEnd.listen((_) {
      final result = reader.result;
      if (result is Uint8List) {
        readerCompleter.complete(result);
      } else if (result is List<int>) {
        readerCompleter.complete(Uint8List.fromList(result));
      } else {
        // ByteBuffer case
        readerCompleter.complete(Uint8List.view(result as dynamic));
      }
    });
    reader.onError.listen((_) => readerCompleter.completeError('Failed to read blob'));
    reader.readAsArrayBuffer(jpegBlob);

    return await readerCompleter.future;
  } finally {
    html.Url.revokeObjectUrl(blobUrl);
  }
}
