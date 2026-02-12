import 'dart:io';
import 'dart:typed_data';

Future<Uint8List?> readBackgroundImageBytes(String fullPath) async {
  try {
    final f = File(fullPath);
    if (await f.exists()) return await f.readAsBytes();
  } catch (_) {}
  return null;
}

Future<void> writeBackgroundImageBytes(String fullPath, Uint8List bytes) async {
  await File(fullPath).writeAsBytes(bytes);
}

Future<void> ensureBackgroundImageDir(String fullPath) async {
  await Directory(fullPath).create(recursive: true);
}
