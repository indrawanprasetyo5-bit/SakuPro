import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

Future<XFile> createShareableTempFile({
  required Uint8List bytes,
  required String fileName,
  required String mimeType,
}) async {
  final tempDir = await getTemporaryDirectory();
  final filePath = p.join(tempDir.path, fileName);
  final file = File(filePath);
  await file.writeAsBytes(bytes, flush: true);
  return XFile(file.path, name: fileName, mimeType: mimeType);
}
