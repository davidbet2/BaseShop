import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;

// Conditional imports for web
import 'image_compressor_stub.dart'
    if (dart.library.html) 'image_compressor_web.dart' as platform;

/// Compress image bytes to a target max dimension and quality.
/// On web: uses HTML Canvas API for efficient compression.
/// On native: returns bytes as-is (ImagePicker handles resize natively).
Future<Uint8List> compressImageBytes(
  Uint8List bytes, {
  int maxWidth = 1200,
  int maxHeight = 1200,
  int quality = 80,
}) async {
  if (!kIsWeb) return bytes; // Native platforms use ImagePicker resize
  if (bytes.isEmpty) return bytes;
  return platform.compressImageBytesImpl(
    bytes,
    maxWidth: maxWidth,
    maxHeight: maxHeight,
    quality: quality,
  );
}
