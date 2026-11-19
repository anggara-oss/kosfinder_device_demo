# KosFinder Device Demo (Worksheet 10 — Standalone)

Aplikasi latihan Flutter **Pemrograman Mobile — Worksheet 10 (Advanced Mobile Features & Device Integration)**.
Project ini dibuat secara mandiri (*standalone*) tanpa ketergantungan pada backend/Worksheet 9.

## Fitur Utama (Mode Lokal / Wajib)
- **Kamera & Galeri (`image_picker`)**: Mengambil foto dari kamera atau memilih dari galeri dengan validasi format (`JPG`/`JPEG`/`PNG`) serta batas ukuran maksimal 5 MB, lengkap dengan pemulihan `retrieveLostData()` pada Android.
- **Penyimpanan Permanen & Draft Lokal (`path_provider` + `shared_preferences`)**: Foto disalin ke *Application Documents Directory* (`kosfinder_photos/`) dan metadata draft (nama kos, path foto, koordinat GPS) disimpan dalam format JSON agar tetap tersedia setelah aplikasi ditutup dan dibuka kembali.
- **GPS & Runtime Permissions (`geolocator`)**: Mengambil koordinat lokasi secara sadar izin dengan penanganan kondisi GPS nonaktif, izin ditolak, izin ditolak permanen (*deniedForever*), dan *timeout*.
- **Demo Sensor Accelerometer (`sensors_plus`, Pengayaan)**: Pembacaan percepatan gerak perangkat (`x`, `y`, `z`) dilengkapi **grafik real-time X/Y/Z**, status *Perangkat Diam / Bergerak*, total percepatan, gerakan puncak, serta tombol *Jeda/Lanjutkan* dan *Reset*.
- **Hapus Foto Lokal Aman (Pengayaan)**: Pembersihan otomatis foto lokal lama saat mengganti foto serta tombol **Hapus Foto** dengan dialog konfirmasi dan validasi path direktori (`kosfinder_photos/`) agar hanya file milik aplikasi yang dapat dihapus.
- **Upload Supabase Storage (`supabase_flutter`, Opsional)**: Nonaktif secara default pada mode lokal; dapat diaktifkan lewat `--dart-define`.

## Struktur Folder `lib/`
```text
lib/
├── main.dart
├── cloud_config.dart
├── pages/
│   ├── device_demo_page.dart
│   └── sensor_demo_page.dart
└── services/
    ├── device_location_service.dart
    ├── draft_repository.dart
    └── photo_upload_service.dart
```

## Cara Menjalankan

### 1. Mode Lokal (Wajib — Tanpa Supabase)
```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

### 2. Mode Cloud (Opsional — Supabase Storage)
```bash
flutter run \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY
```

> **Catatan:** Aplikasi menggunakan `dart:io` sehingga ditujukan untuk perangkat **Android/iOS** (bukan Flutter Web).

## Checklist Pengujian Lokal
- [ ] Foto via kamera (pratinjau tampil & tersalin permanen)
- [ ] Foto via galeri (pratinjau tampil)
- [ ] Batalkan galeri (aplikasi stabil, foto sebelumnya tetap)
- [ ] Izin kamera/galeri ditolak (pesan tampil, aplikasi tidak crash)
- [ ] GPS diberikan (koordinat tampil)
- [ ] GPS ditolak (pesan tampil, simpan draft lokal tetap berjalan)
- [ ] GPS nonaktif (tombol menuju pengaturan lokasi tampil)
- [ ] Tutup dan buka ulang aplikasi (draft nama, foto, dan koordinat pulih)
- [ ] Tanpa internet / mode pesawat (simpan draft lokal tetap berfungsi)
