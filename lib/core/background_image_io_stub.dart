// Stub for web (no file system access).
Future<Uint8List?> readBackgroundImageBytes(String fullPath) async => null;
Future<void> writeBackgroundImageBytes(String fullPath, Uint8List bytes) async {}
Future<void> ensureBackgroundImageDir(String fullPath) async {}
