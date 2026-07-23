import 'dart:io';

String inferProfileImageMimeType(String filename) {
  final normalized = filename.toLowerCase();
  if (normalized.endsWith('.png')) return 'image/png';
  return 'image/jpeg';
}

bool isSupportedProfileImageNameAndMime(String filename, String? mimeType) {
  final normalized = filename.toLowerCase();
  final isSupportedName =
      normalized.endsWith('.jpg') ||
      normalized.endsWith('.jpeg') ||
      normalized.endsWith('.png');
  final isSupportedMime = mimeType == 'image/jpeg' || mimeType == 'image/png';
  return isSupportedName && isSupportedMime;
}

Future<bool> hasSupportedProfileImageSignature(String path) async {
  final file = File(path);
  if (!await file.exists()) return false;

  final bytes = await file
      .openRead(0, 12)
      .fold<List<int>>(<int>[], (buffer, chunk) => buffer..addAll(chunk));

  return _hasJpegSignature(bytes) || _hasPngSignature(bytes);
}

bool _hasJpegSignature(List<int> bytes) {
  return bytes.length >= 3 &&
      bytes[0] == 0xFF &&
      bytes[1] == 0xD8 &&
      bytes[2] == 0xFF;
}

bool _hasPngSignature(List<int> bytes) {
  const signature = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
  if (bytes.length < signature.length) return false;

  for (var index = 0; index < signature.length; index += 1) {
    if (bytes[index] != signature[index]) return false;
  }
  return true;
}
