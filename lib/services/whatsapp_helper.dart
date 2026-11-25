import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/roadmap_models.dart';
import '../theme/currency_format.dart';

class WhatsAppHelper {
  WhatsAppHelper._();

  static String normalizePhone(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      return '';
    }
    if (digits.startsWith('0')) {
      return '62${digits.substring(1)}';
    }
    if (digits.startsWith('8')) {
      return '62$digits';
    }
    return digits;
  }

  static String buildReminderMessage(DebtModel debt) {
    final amountText = IdrFormat.currency(debt.remainingAmount);
    final duePart = debt.dueDate != null
        ? ' dengan jadwal jatuh tempo ${DateFormat('dd MMM yyyy').format(debt.dueDate!)}'
        : '';
    final notePart = debt.note.trim().isNotEmpty
        ? ' (${debt.note.trim()})'
        : '';

    return 'Halo ${debt.personName}, semoga sehat dan lancar aktivitasnya. '
        'Izin mengingatkan dengan sopan terkait pinjaman sebesar $amountText'
        '$notePart$duePart. '
        'Kabari saja jika sudah berkenan menyelesaikan ya. Terima kasih banyak sebelumnya.';
  }

  static Uri buildReminderUri(DebtModel debt) {
    final normalizedPhone = normalizePhone(debt.phone);
    final message = buildReminderMessage(debt);
    final path = normalizedPhone.isNotEmpty ? '/$normalizedPhone' : '/';
    return Uri(
      scheme: 'https',
      host: 'wa.me',
      path: path,
      queryParameters: <String, String>{'text': message},
    );
  }

  static Future<bool> launchDebtReminder(DebtModel debt) async {
    final uri = buildReminderUri(debt);
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
