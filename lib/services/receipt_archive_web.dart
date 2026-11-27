import 'package:material_ui/material_ui.dart';

Future<String> archiveReceiptImageIfNeeded(String rawPath) async => '';

bool receiptImageExistsSync(String path) => false;

Widget buildReceiptImageWidget(
  String path, {
  BoxFit fit = BoxFit.cover,
  double? width,
  double? height,
}) {
  return const SizedBox.shrink();
}

Future<void> deleteReceiptImageIfOwned(String path) async {}

Future<(int, int)> getReceiptStorageStatsRaw() async => (0, 0);

Future<int> clearAllArchivedReceipts() async => 0;
