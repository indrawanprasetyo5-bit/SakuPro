# SakuProWann

Aplikasi Android pencatatan keuangan pribadi berbasis Flutter yang berjalan 100% offline-first (SQLite lokal) dengan tema Obsidian Dark & Light Mode.

## Fitur Utama

- **Beranda Bento & Aman Dipakai Hari Ini**: Menampilkan jatah pengeluaran harian yang aman berdasarkan sisa budget dan sisa hari di bulan berjalan, total saldo bersih, arus kas bulanan, dan daftar transaksi terbaru dengan swipe-to-delete + `Urungkan`.
- **Quick-Add Bar & Preset 1-Ketuk Dinamis**: Catat transaksi langsung dari bar bawah seperti mengirim chat (misalnya `kopi 25rb gopay`, `bensin 50k cash`, atau `gaji 8jt bca`), lengkap dengan 4 chip preset yang otomatis menyesuaikan kebiasaan 30 hari terakhir.
- **Split Bill / Patungan**: Hitung patungan bagi rata atau nominal khusus per orang. Porsi pribadi langsung masuk pengeluaran, sedangkan porsi teman otomatis tercatat ke daftar Piutang dan siap ditagih lewat WhatsApp.
- **Scan Struk & Share Resi Bank (OCR Offline)**: Foto struk belanja atau kirim gambar lewat tombol Bagikan (Share) dari bukti transfer Bank Jago, SeaBank, DANA, GoPay, dan BCA untuk membaca nominal serta nama penerima langsung di perangkat menggunakan Google ML Kit.
- **Otomatisasi Lokal**: Jadwal pemasukan rutin (Auto-Gaji), Auto-Pay tagihan saat jatuh tempo, sisihkan persentase pemasukan otomatis ke target tabungan (Auto-Save Goal), pengingat lokal budget & tagihan, Rekap Tutup Bulan, dan Auto-Backup JSON mingguan ke `Download/SakuProWann/`.
- **Analitik & Laporan Excel 5-Sheet**: Grafik Tren 6 Bulan, Pola Pengeluaran Harian, Donut Distribusi Kategori, Insight otomatis, dan export laporan bulanan `.xlsx` berformula dinamis (Ringkasan Eksekutif, Buku Transaksi, Analisa Kategori & Budget, Dompet & Aset, Rencana & Kewajiban).
- **Multi-Dompet, Rencana & Privasi**: Logo dompet lokal (BCA, DANA, SeaBank, GoPay, Bank Jago, Mandiri, BRI, OVO, ShopeePay, blu), Budget, Goals, Tagihan, Hutang & Piutang, sembunyikan saldo 1-ketuk, kunci PIN 4 digit + Biometrik, Widget Home Screen, serta Quick Settings Tile.

## Tech Stack

- **Framework**: Flutter (Dart) + Kotlin (Android Native AppWidget, Quick Settings Tile, MediaStore & Local Reminders)
- **Database Lokal**: SQLite (`sqflite`)
- **OCR & Keamanan**: `google_mlkit_text_recognition`, `image_picker`, `local_auth`
- **Export**: `excel`, `share_plus`

## Menjalankan di Lokal

```bash
flutter pub get
flutter run -d chrome
```

Untuk build Android APK per arsitektur (`arm64-v8a` / `armeabi-v7a`):

```bash
flutter build apk --release --split-per-abi
```
