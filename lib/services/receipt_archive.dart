import 'package:material_ui/material_ui.dart';

import 'receipt_archive_io.dart'
    if (dart.library.js_interop) 'receipt_archive_web.dart' as impl;

class ReceiptStorageStats {
  const ReceiptStorageStats({
    required this.fileCount,
    required this.totalBytes,
  });

  final int fileCount;
  final int totalBytes;

  String get formattedSize {
    if (totalBytes <= 0) {
      return '0 KB';
    }
    if (totalBytes < 1024 * 1024) {
      final kb = (totalBytes / 1024).ceil();
      return '$kb KB';
    }
    final mb = totalBytes / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }
}

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

  static Future<ReceiptStorageStats> getStorageStats() async {
    final raw = await impl.getReceiptStorageStatsRaw();
    return ReceiptStorageStats(fileCount: raw.$1, totalBytes: raw.$2);
  }

  static Future<int> clearAll() {
    return impl.clearAllArchivedReceipts();
  }
}
