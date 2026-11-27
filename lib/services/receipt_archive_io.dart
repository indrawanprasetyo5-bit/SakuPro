import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

Future<Directory> _receiptsDirectory() async {
  final docs = await getApplicationDocumentsDirectory();
  final dir = Directory(p.join(docs.path, 'receipts'));
  if (!dir.existsSync()) {
    await dir.create(recursive: true);
  }
  return dir;
}

Future<String> archiveReceiptImageIfNeeded(String rawPath) async {
  final trimmed = rawPath.trim();
  if (trimmed.isEmpty) {
    return '';
  }
  try {
    final source = File(trimmed);
    if (!source.existsSync()) {
      return '';
    }
    final dir = await _receiptsDirectory();
    if (p.isWithin(dir.path, source.path)) {
      return source.path;
    }
    final rawExt = p.extension(source.path).toLowerCase();
    final safeExt = const <String>['.jpg', '.jpeg', '.png', '.webp'].contains(rawExt)
        ? rawExt
        : '.jpg';
    final fileName = 'receipt_${DateTime.now().millisecondsSinceEpoch}$safeExt';
    final targetPath = p.join(dir.path, fileName);
    await source.copy(targetPath);
    return targetPath;
  } catch (_) {
    return '';
  }
}

bool receiptImageExistsSync(String path) {
  final trimmed = path.trim();
  if (trimmed.isEmpty) {
    return false;
  }
  try {
    return File(trimmed).existsSync();
  } catch (_) {
    return false;
  }
}

Widget buildReceiptImageWidget(
  String path, {
  BoxFit fit = BoxFit.cover,
  double? width,
  double? height,
}) {
  final trimmed = path.trim();
  if (trimmed.isEmpty) {
    return const SizedBox.shrink();
  }
  return Image.file(
    File(trimmed),
    fit: fit,
    width: width,
    height: height,
    errorBuilder: (context, error, stackTrace) {
      return const SizedBox.shrink();
    },
  );
}

Future<void> deleteReceiptImageIfOwned(String path) async {
  final trimmed = path.trim();
  if (trimmed.isEmpty) {
    return;
  }
  try {
    final dir = await _receiptsDirectory();
    final file = File(trimmed);
    if (p.isWithin(dir.path, file.path) && file.existsSync()) {
      await file.delete();
    }
  } catch (_) {
    // Ignore cleanup errors when file is already removed.
  }
}

Future<(int, int)> getReceiptStorageStatsRaw() async {
  try {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'receipts'));
    if (!dir.existsSync()) {
      return (0, 0);
    }
    var count = 0;
    var bytes = 0;
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is File) {
        count++;
        bytes += await entity.length();
      }
    }
    return (count, bytes);
  } catch (_) {
    return (0, 0);
  }
}

Future<int> clearAllArchivedReceipts() async {
  try {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'receipts'));
    if (!dir.existsSync()) {
      return 0;
    }
    var removed = 0;
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is File) {
        await entity.delete();
        removed++;
      }
    }
    return removed;
  } catch (_) {
    return 0;
  }
}
