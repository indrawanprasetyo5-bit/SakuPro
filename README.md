# SakuProWann

Aplikasi Android pencatatan keuangan pribadi berbasis Flutter yang berjalan 100% offline-first (SQLite lokal) dengan dukungan Light & Dark Mode.

## Fitur

- **Auto-Catat QRIS & Bank (Offline)**: Membaca notifikasi transaksi lokal dari SeaBank, DANA, GoPay/Gojek, Bank Jago, BCA, Mandiri, BRI, OVO, ShopeePay, dan blu tanpa perlu login bank. Dilengkapi filter promo/OTP, anti-duplikat, Auto-Pairing Transfer antar dompet sendiri, Auto-Lunas Tagihan, Auto-Potong Hutang/Piutang, dan Kamus Belajar Merchant pribadi.
- **Smart Quick Input**: Catat transaksi dalam hitungan detik cukup dengan mengetik kalimat bebas seperti `kopi 22rb gopay`, `bensin 50k cash`, atau `gaji 5jt bca`.
- **Scan Struk & Share Bukti QRIS (OCR Offline)**: Foto struk belanja atau tekan Bagikan (Share) dari bukti bayar aplikasi bank ke SakuProWann untuk membaca nama toko dan total transaksi secara otomatis menggunakan Google ML Kit di perangkat.
- **Otomatisasi Rutin & Pengingat Lokal**: Jadwal Gaji rutin, Auto-Catat Tagihan saat jatuh tempo, Auto-Alokasi Tabungan saat gaji masuk, alert budget real-time, pengingat tagihan H-2, Rekap Tutup Bulan, dan Auto-Backup JSON mingguan ke `Download/SakuProWann/`.
- **Widget Layar Utama & Quick Settings Tile**: Pantau batas Aman Jajan Hari Ini dan saldo bersih langsung dari Home Screen Android, plus tombol cepat `Catat SakuPro` di panel tarik-atas HP.
- **Perencanaan & Analitik**: Multi-dompet, Budget per kategori, Target Tabungan (Goals), Tagihan Rutin, Hutang & Piutang (+ pengingat WhatsApp), grafik pengeluaran, dan Insight otomatis.
- **Laporan Excel 5-Sheet & Privasi**: Export laporan bulanan ke `.xlsx` (Ringkasan Eksekutif, Buku Transaksi, Analisa Kategori & Budget, Dompet & Aset, Rencana & Kewajiban dengan rumus Excel dinamis), 1-tap sembunyikan saldo, kunci PIN 4 digit + Biometrik, dan Backup/Restore JSON.

## Tech Stack

- **Framework**: Flutter (Dart) + Kotlin (Android Native Services & AppWidget)
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
