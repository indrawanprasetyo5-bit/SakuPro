import 'package:flutter_test/flutter_test.dart';
import 'package:saku_pro/models/transaction_item.dart';
import 'package:saku_pro/services/receipt_ocr_service.dart';

void main() {
  group('Golden Indonesian OCR regression corpus', () {
    test('Minimarket retail receipt extracts items, discount, cash math, and Belanja category', () {
      const alfamartReceipt = '''
PT SUMBER ALFARIA TRIJAYA TBK
ALFAMART KEMANG SELATAN
27/11/2026 16:40
Indomie Goreng 3x          9.600
Aqua 600ml 2x              7.000
Roti Sari Roti             16.500
Susu Ultra Milk 1L         21.500
Subtotal                   54.600
Diskon                     -3.000
Total Belanja              51.600
Tunai                     100.000
Kembalian                  48.400
''';
      final res = ReceiptOcrService.parseReceiptText(alfamartReceipt);
      expect(res.merchantName, 'Alfamart');
      expect(res.totalAmount, 51600);
      expect(res.suggestedCategory, 'Belanja');
      expect(res.suggestedKind, TransactionKind.expense);
      expect(res.receiptDate, DateTime(2026, 11, 27, 16, 40));
      expect(res.items.length, 4);
      expect(res.items[0].name, 'Indomie Goreng');
      expect(res.items[0].quantity, 3);
      expect(res.items[0].price, 9600);
      expect(res.items[3].name, 'Susu Ultra Milk 1L');
      expect(res.receiptDetailText, contains('Diskon: -Rp 3.000'));
    });

    test('Restaurant POS receipt captures multi-line modifiers, PB1/Service tax, and Makan & Minum category', () {
      const solariaPosReceipt = '''
SOLARIA PLAZA SENAYAN
Meja 12 · Dine In
Kasir: Rina
28/11/2026 12:15
Nasi Goreng Seafood
  Pedas Sedang
  1 x 46.000              46.000
Bihun Siram Ayam
  2 x 42.000              84.000
Es Teh Tawar 2x           14.000
Subtotal                 144.000
Service 5%                 7.200
PB1 10%                   15.120
Grand Total              166.320
QRIS                     166.320
''';
      final res = ReceiptOcrService.parseReceiptText(solariaPosReceipt);
      expect(res.totalAmount, 166320);
      expect(res.suggestedCategory, 'Makan & Minum');
      expect(res.paymentMethod, 'QRIS');
      expect(res.items.length, 3);
      expect(res.items[0].name, 'Nasi Goreng Seafood');
      expect(res.items[0].price, 46000);
      expect(res.items[1].name, 'Bihun Siram Ayam');
      expect(res.items[1].quantity, 2);
      expect(res.items[1].price, 84000);
      expect(res.items[2].name, 'Es Teh Tawar');
      expect(res.items[2].quantity, 2);
      expect(res.receiptDetailText, contains('Pajak & layanan: Rp 22.320'));
    });

    test('Coffee shop QRIS receipt detects Ngopi category and all specialty items', () {
      const coffeeReceipt = '''
FORE COFFEE
Senopati No 45
28/11/2026 09:20
Spanish Latte Iced
  Less Sugar
  2 x 29.000              58.000
Butter Croissant          26.000
Subtotal                  84.000
Total Bayar               84.000
QRIS                      84.000
''';
      final res = ReceiptOcrService.parseReceiptText(coffeeReceipt);
      expect(res.merchantName, 'Fore Coffee');
      expect(res.totalAmount, 84000);
      expect(res.suggestedCategory, 'Ngopi');
      expect(res.paymentMethod, 'QRIS');
      expect(res.items.length, 2);
      expect(res.items[0].name, 'Spanish Latte Iced');
      expect(res.items[0].quantity, 2);
      expect(res.items[1].name, 'Butter Croissant');
    });

    test('Food delivery receipt picks final Total Pembayaran despite delivery fee and voucher discount', () {
      const gofoodReceipt = '''
GoPay
Transaksi Berhasil
GoFood - Bakmi GM
28 Nov 2026, 13:05 WIB
Bakmi Special GM          41.000
Pangsit Goreng 10 Pcs     33.000
Subtotal                  74.000
Biaya Pengiriman          12.000
Biaya Layanan              4.000
Diskon Voucher           -15.000
Total Pembayaran          75.000
Metode Pembayaran GoPay
ID Transaksi GF202611280091
''';
      final res = ReceiptOcrService.parseReceiptText(gofoodReceipt);
      expect(res.detectedWalletName, 'GoPay');
      expect(res.totalAmount, 75000);
      expect(res.suggestedCategory, 'Makan & Minum');
      expect(res.suggestedKind, TransactionKind.expense);
      expect(res.items.length, 2);
      expect(res.items[0].name, 'Bakmi Special GM');
      expect(res.items[1].name, 'Pangsit Goreng');
      expect(res.items[1].quantity, 10);
    });

    test('Digital bank QRIS merchant receipts (Livin Mandiri & OVO) classify health and fuel correctly', () {
      const livinPharmacy = '''
Livin by Mandiri
Pembayaran QRIS Berhasil
28 Nov 2026, 10:12 WIB
-Rp142.500
Nama Merchant: Apotek Kimia Farma
Sumber Dana Mandiri
ID Transaksi LVM2026112800088
''';
      final pharmacyRes = ReceiptOcrService.parseReceiptText(livinPharmacy);
      expect(pharmacyRes.detectedWalletName, 'Mandiri');
      expect(pharmacyRes.paymentMethod, 'QRIS');
      expect(pharmacyRes.merchantName, 'Apotek Kimia Farma');
      expect(pharmacyRes.totalAmount, 142500);
      expect(pharmacyRes.suggestedCategory, 'Kesehatan');

      const ovoFuel = '''
OVO
Pembayaran Berhasil
SPBU Pertamina 34-12902
Bayar Ke
SPBU Pertamina
Total Bayar Rp 100.000
Nomor Referensi 776655443322
''';
      final fuelRes = ReceiptOcrService.parseReceiptText(ovoFuel);
      expect(fuelRes.detectedWalletName, 'OVO');
      expect(fuelRes.merchantName, 'Spbu Pertamina');
      expect(fuelRes.totalAmount, 100000);
      expect(fuelRes.suggestedCategory, 'Transportasi');
    });

    test('Bank transfer receipts (myBCA, BRImo, DANA) separate phone/VA noise, respect transfer notes, and detect income', () {
      const myBcaUtility = '''
myBCA
Transfer Berhasil
28 Nov 2026, 08:05 WIB
Penerima: Ibu Santi Pemilik Kos
VA 88990011223344
Catatan: Bayar listrik kos bulan ini
Nominal Transfer Rp850.000
Biaya Admin Rp2.500
Total Transaksi Rp852.500
''';
      final utilityRes = ReceiptOcrService.parseReceiptText(myBcaUtility);
      expect(utilityRes.detectedWalletName, 'BCA');
      expect(utilityRes.totalAmount, 852500);
      expect(utilityRes.adminFee, 2500);
      expect(utilityRes.transferNote, 'Bayar listrik kos bulan ini');
      expect(utilityRes.suggestedCategory, 'Tagihan & Utilitas');
      expect(utilityRes.suggestedKind, TransactionKind.expense);
      expect(utilityRes.items, isEmpty);

      const brimoEntertainment = '''
BRImo
Transaksi Berhasil
28 Nov 2026, 18:45 WIB
Penerima: Studio Cinema XXI
+62 812-9988-7766
Keterangan: Tiket bioskop XXI malam minggu
Nominal Rp120.000
Biaya Admin Rp0
''';
      final cinemaRes = ReceiptOcrService.parseReceiptText(brimoEntertainment);
      expect(cinemaRes.detectedWalletName, 'BRI');
      expect(cinemaRes.totalAmount, 120000);
      expect(cinemaRes.suggestedCategory, 'Hiburan');
      expect(cinemaRes.items, isEmpty);

      const danaIncome = '''
DANA
Transfer Masuk
28 Nov 2026, 09:00 WIB
+Rp7.500.000
Pengirim: PT Teknologi Nusantara
Catatan: Gaji bulan November
''';
      final salaryRes = ReceiptOcrService.parseReceiptText(danaIncome);
      expect(salaryRes.detectedWalletName, 'DANA');
      expect(salaryRes.suggestedKind, TransactionKind.income);
      expect(salaryRes.totalAmount, 7500000);
      expect(salaryRes.suggestedCategory, 'Gaji');
    });
  });
}
