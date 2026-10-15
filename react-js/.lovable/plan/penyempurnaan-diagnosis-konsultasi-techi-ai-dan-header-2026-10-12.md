# Penyempurnaan Diagnosis, Konsultasi Techi AI, dan Header

## Tujuan
Memperjelas hasil analisis kesehatan dengan tiga kemungkinan penyakit, membuat konsultasi Techi AI khusus per kasus mengikuti referensi visual, dan menyederhanakan header aplikasi agar berfokus pada pengguna serta notifikasi.

## Perubahan yang akan dibuat

### 1. Tiga kemungkinan penyakit pada detail peringatan
- Pada `/history/consultation/:alertId`, pertahankan susunan foto, ringkasan sangkar, status, dan tombol konfirmasi yang sudah ada.
- Ubah hasil analisis dari satu diagnosis menjadi daftar tiga kemungkinan penyakit untuk setiap kasus.
- Tampilkan nama penyakit, persentase keyakinan, dan indikator visual yang konsisten; kemungkinan utama tetap paling menonjol, dua kemungkinan lain muncul tepat di bawahnya.
- Siapkan data berbeda berdasarkan `alertId`, sehingga setiap kartu peringatan menampilkan kombinasi penyakit dan persentase yang relevan, termasuk saat URL dimuat ulang.
- Gunakan copy yang menegaskan bahwa hasil tersebut adalah kemungkinan dari analisis visual, bukan diagnosis pasti.

### 2. Halaman konsultasi Techi AI khusus per kasus
- Tombol **Lanjutkan dengan Techi AI** tetap membuka URL percakapan per kasus, misalnya `/techi/alert-a24`, dengan konteks kasus berasal dari ID pada URL.
- Untuk percakapan kasus kesehatan, tampilkan desain khusus seperti referensi:
  - header sederhana berisi tombol kembali, judul **Techi AI**, dan maskot,
  - kartu kasus berisi sangkar, kemungkinan utama, tanggal, confidence, status, serta tombol **Konfirmasi Sakit** dan **Tandai Sehat**,
  - respons awal Techi yang merangkum temuan dan langkah pemeriksaan,
  - area composer tetap di bawah layar.
- Ganti daftar panduan bernomor menjadi checklist tindakan. Setiap item memiliki checkbox yang dapat dicentang, status selesai yang jelas, dan copy berupa tindakan pengguna, misalnya:
  - Pisahkan ayam yang menunjukkan gejala ke area observasi.
  - Periksa air minum, suhu, dan ventilasi kandang.
  - Catat perubahan nafsu makan dan hubungi dokter hewan bila kondisi memburuk.
- Checklist bukan resep atau diagnosis; saran obat spesifik tidak akan ditampilkan tanpa arahan dokter hewan.
- Pertahankan percakapan streaming melalui `/api/chat` dan maskot Techi yang sudah ada.

### 3. Percakapan per kasus dengan penyimpanan di perangkat
- Gunakan `threadId` dari route sebagai identitas stabil setiap konsultasi kasus.
- Simpan pesan, status kasus, dan checklist per thread di `localStorage`, sehingga konsultasi kasus tetap tersedia setelah reload pada perangkat yang sama.
- Tampilkan daftar percakapan kasus yang sudah tersimpan dan tombol percakapan baru; memilih percakapan akan berpindah ke URL thread terkait.
- Pastikan data antar kasus tidak tercampur dan pembukaan ulang `/techi/:threadId` memulihkan percakapan yang benar.
- Pesan model dan credential tetap hanya melewati server; browser hanya menyimpan riwayat tampilan percakapan.

### 4. Header utama baru
- Terapkan pada Dashboard, History, detail History, Treatment, Feeding, dan Profile.
- Hilangkan identitas/logo **Futechi Smart Poultry Farm** dan kolom pencarian.
- Pindahkan profil **Anne Fremant — Manajer Kandang** ke sisi kiri sebagai akses ke halaman Profile.
- Tempatkan ikon notifikasi dengan badge di sisi kanan.
- Gunakan ukuran sentuh, jarak aman, dan struktur yang konsisten pada tablet portrait maupun ponsel.
- Halaman Techi AI memakai header konsultasi khusus sesuai referensi, bukan header utama aplikasi.

## Alur halaman
```text
History
└── Detail peringatan
    ├── 3 kemungkinan penyakit + persentase
    ├── Konfirmasi Sakit / Tandai Sehat
    └── Lanjutkan dengan Techi AI
        └── /techi/:threadId
            ├── Ringkasan kasus
            ├── Percakapan per kasus
            ├── Checklist tindakan
            └── Riwayat tersimpan di perangkat
```

## Detail teknis
- Pertahankan route-level view dan shell tablet portrait yang ada.
- Gunakan komponen AI Elements yang sudah terpasang untuk transcript, pesan, status streaming, dan composer.
- Tambahkan lapisan penyimpanan browser terstruktur per thread, dengan pemulihan yang aman saat halaman dimuat dan tanpa membuat thread duplikat.
- Konteks kasus dikirim bersama percakapan melalui route `/api/chat`; model tetap `openai/gpt-6-astra` dengan konfigurasi streaming yang sudah ada.
- Gambar lampiran hanya menjadi referensi desain dan tidak dimasukkan sebagai aset aplikasi.

## Verifikasi
- Uji setiap `alertId` menampilkan tiga penyakit dan persentase yang berbeda serta stabil setelah reload.
- Uji tombol menuju konsultasi membawa kasus yang benar, checklist dapat dicentang, dan status kasus berubah.
- Buat minimal dua percakapan kasus, kirim pesan pada keduanya, reload, lalu pastikan masing-masing riwayat pulih tanpa tercampur.
- Uji streaming, loading, Stop, error, fokus composer, dan pesan optimistis.
- Uji header baru dan area konsultasi pada tablet portrait dan ponsel tanpa tumpang tindih.
- Periksa build, error browser, metadata route, dan alur dari History sampai konsultasi secara menyeluruh.
