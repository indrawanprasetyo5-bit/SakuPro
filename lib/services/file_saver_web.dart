import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

Future<XFile> createShareableTempFile({
  required Uint8List bytes,
  required String fileName,
  required String mimeType,
}) async {
  return XFile.fromData(bytes, name: fileName, mimeType: mimeType);
}
