import 'package:material_ui/material_ui.dart';

import 'receipt_archive_io.dart'
    if (dart.library.js_interop) 'receipt_archive_web.dart' as impl;

class ReceiptArchive {
  ReceiptArchive._();

  static Future<String> archiveIfNeeded(String rawPath) {
    return impl.archiveReceiptImageIfNeeded(rawPath);
  }

  static bool existsSync(String path) {
    return impl.receiptImageExistsSync(path);
  }

  static Widget buildImage(
    String path, {
    BoxFit fit = BoxFit.cover,
    double? width,
    double? height,
  }) {
    return impl.buildReceiptImageWidget(
      path,
      fit: fit,
      width: width,
      height: height,
    );
  }

  static Future<void> deleteIfOwned(String path) {
    return impl.deleteReceiptImageIfOwned(path);
  }
}
