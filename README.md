# SakuPro

Aplikasi Android pencatatan keuangan pribadi berbasis Flutter yang berjalan 100% offline-first (SQLite lokal) dengan dukungan Light & Dark Mode.

## Fitur

- **Smart Quick Input**: Catat transaksi dalam hitungan detik cukup dengan mengetik kalimat bebas seperti `kopi 22rb gopay`, `bensin 50k cash`, atau `gaji 5jt bca`. Parser lokal otomatis mendeteksi tipe transaksi, nominal, kategori, dan dompet.
- **Scan Struk Belanja (OCR Offline)**: Foto struk belanja lewat kamera untuk membaca nama toko dan total transaksi secara otomatis menggunakan Google ML Kit di perangkat.
- **Aman Jajan Hari Ini (Safe-to-Spend)**: Menghitung batas pengeluaran harian secara otomatis dari sisa budget bulanan dibagi sisa hari berjalan.
- **Multi-Dompet & Transfer**: Kelola saldo terpisah (Cash, Bank, E-Wallet, Tabungan) dengan fitur transfer antar dompet yang tidak merusak laporan pengeluaran.
- **Perencanaan Keuangan**: Budget per kategori dengan indikator warna, target tabungan (Goals), daftar tagihan rutin bulanan, serta catatan Hutang & Piutang lengkap dengan pengingat WhatsApp.
- **Analitik & Insight**: Grafik pengeluaran per kategori, perbandingan pemasukan vs pengeluaran, serta ringkasan insight bulanan otomatis.
- **Privasi & Backup**: Tombol 1-tap sembunyikan saldo, kunci aplikasi (PIN 4 digit + Biometrik), export laporan ke Excel (`.xlsx`), dan backup/restore data JSON.

## Tech Stack

- **Framework**: Flutter (Dart)
- **Database Lokal**: SQLite (`sqflite`)
- **OCR & Keamanan**: `google_mlkit_text_recognition`, `image_picker`, `local_auth`
- **Export**: `excel`, `share_plus`

## Menjalankan di Lokal

```bash
flutter pub get
flutter run -d chrome
```

Untuk build Android APK:

```bash
flutter build apk --release
```
