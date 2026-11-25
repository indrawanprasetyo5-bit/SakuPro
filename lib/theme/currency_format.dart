import 'package:intl/intl.dart';

class IdrFormat {
  IdrFormat._();

  static final NumberFormat _currency = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  static final NumberFormat _plain = NumberFormat.decimalPattern('id_ID');

  static String currency(int amount, {bool hidden = false, bool signed = false}) {
    if (hidden) {
      return 'Rp ••••••';
    }
    final absFormatted = _currency.format(amount.abs());
    if (amount < 0) {
      return '-$absFormatted';
    }
    if (signed && amount > 0) {
      return '+$absFormatted';
    }
    return absFormatted;
  }

  static String plain(int amount) => _plain.format(amount);

  static String compact(int amount, {bool hidden = false}) {
    if (hidden) {
      return 'Rp ••••';
    }
    final absVal = amount.abs();
    final prefix = amount < 0 ? '-Rp ' : 'Rp ';
    if (absVal >= 1000000000) {
      final val = absVal / 1000000000;
      return '$prefix${_trimDecimal(val)} M';
    }
    if (absVal >= 1000000) {
      final val = absVal / 1000000;
      return '$prefix${_trimDecimal(val)} jt';
    }
    if (absVal >= 1000) {
      final val = absVal / 1000;
      return '$prefix${_trimDecimal(val)} rb';
    }
    return '$prefix$absVal';
  }

  static String _trimDecimal(double value) {
    final fixed = value.toStringAsFixed(1);
    if (fixed.endsWith('.0')) {
      return fixed.substring(0, fixed.length - 2);
    }
    return fixed.replaceAll('.', ',');
  }
}
