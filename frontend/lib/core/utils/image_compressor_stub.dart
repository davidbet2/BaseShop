import 'dart:typed_data';

/// Stub implementation for non-web platforms.
/// On native, ImagePicker handles resize, so just return as-is.
Future<Uint8List> compressImageBytesImpl(
  Uint8List bytes, {
  int maxWidth = 1200,
  int maxHeight = 1200,
  int quality = 80,
}) async {
  return bytes;
}
