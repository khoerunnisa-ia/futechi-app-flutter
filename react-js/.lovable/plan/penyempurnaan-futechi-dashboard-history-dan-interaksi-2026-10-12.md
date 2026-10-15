# Penyempurnaan Futechi: Dashboard, History, dan Interaksi

## Tujuan
Menyelaraskan dashboard dengan referensi visual baru, memindahkan Techi AI menjadi tombol mengambang, serta melengkapi alur History dengan dua halaman detail yang interaktif.

## Perubahan yang akan dibuat

### 1. Header dan area awal dashboard
- Ubah header mengikuti referensi pertama: foto profil di sisi identitas, nama **Futechi**, subjudul **Smart Poultry Farm**, pencarian lebar, dan notifikasi yang lebih menonjol.
- Ganti pembuka dashboard menjadi banner foto kandang ayam dengan teks kontras, status **Kondisi Baik**, ringkasan monitoring, dan waktu pembaruan di atas foto.
- Rapikan tiga kartu sensor tepat di bawah banner agar angka, ikon, dan tren harian lebih mudah dipindai pada tablet portrait.
- Pertahankan visual kandang dan bagian operasional berikutnya, tetapi sesuaikan jarak, hierarki, dan proporsinya dengan gaya referensi.

### 2. Navigasi dan Techi AI
- Kurangi navigasi bawah menjadi empat menu: **Dashboard, History, Treatment, Feeding**.
- Hapus Techi AI dari navigasi bawah.
- Tambahkan FAB Techi AI di dashboard, berada di atas navigasi bawah, memakai maskot yang sudah ada dan membuka percakapan AI.
- Pastikan FAB tidak menutup konten atau navigasi pada layar tablet dan ponsel.

### 3. History dan dua halaman mandatory
- Perjelas statistik awal History dengan angka utama, label, status warna, dan ringkasan periode analisis.
- Jadikan seluruh kartu **Peringatan Kesehatan Aktif** dapat disentuh.
- Saat kartu peringatan dipilih, buka halaman konsultasi AI kontekstual yang berisi:
  - foto dummy ayam sakit tampak depan saat makan,
  - ringkasan sangkar, gejala, tanggal, tingkat keyakinan, dan status konfirmasi,
  - tombol **Konfirmasi Sakit** dan **Tandai Sehat** yang langsung memperbarui status,
  - percakapan Techi AI dan panduan penanganan yang mengikuti kasus terpilih.
- Jadikan setiap kartu **Hasil Analisis Kamera** dapat disentuh dan arahkan ke halaman detail riwayat kesehatan per sesi selesai feeding.
- Buat beberapa data dummy yang berbeda per analisis: waktu feeding, jumlah ayam, kondisi, anomali, confidence, rekomendasi, dan foto ayam sedang makan tampak depan.
- Tambahkan aksi konfirmasi/abaikan pada temuan; label, warna, dan tombol berubah setelah tindakan dipilih.

### 4. Visual ayam
- Buat satu foto banner peternakan untuk area awal dashboard.
- Buat rangkaian foto dummy yang konsisten: ayam sakit tampak depan saat makan serta beberapa variasi ayam sedang makan untuk laporan kamera.
- Gunakan gambar baru sebagai konten aplikasi; dua lampiran pengguna tetap menjadi referensi desain, bukan ditempel sebagai tangkapan layar.

### 5. Interaksi operasional
- **Treatment:** tombol *View Details* membuka detail perawatan dengan informasi jadwal, batch, lokasi, instruksi, dan aksi status.
- **Feeding:** tombol feeding manual dan perubahan jadwal memberi feedback sukses yang jelas; pasang pusat notifikasi ringan agar status tidak hanya berubah diam-diam.
- **Profile:** pertahankan akses dari header, rapikan halaman profil, dan buat baris pengaturan memberi respons yang sesuai seperti panel/detail atau feedback.
- Pastikan semua kontrol memakai komponen tombol/dialog yang konsisten, memiliki fokus yang jelas, dan dapat digunakan dengan sentuhan.

## Struktur halaman
```text
Dashboard
├── FAB Techi AI → /techi/:threadId
History
├── Peringatan aktif → /history/consultation/:alertId
└── Analisis kamera → /history/feeding-analysis/:analysisId
Treatment
└── Detail perawatan (dialog/panel)
Feeding
└── Feedback feeding berhasil
Profile
```

## Detail teknis
- Tambahkan route dinamis untuk konsultasi kasus dan detail analisis feeding, masing-masing dengan metadata halaman sendiri.
- Gunakan data dummy terstruktur per ID agar setiap kartu membuka isi yang berbeda dan tetap benar saat halaman dimuat ulang.
- Gunakan state lokal untuk status konfirmasi dan interaksi demo; sambungan Techi AI yang ada tetap melalui endpoint server dan ID percakapan dari route.
- Pasang komponen notifikasi yang sudah tersedia pada shell aplikasi untuk feedback feeding dan pengaturan.
- Pertahankan design tokens warna warm-neutral/amber dan layout bersama tablet portrait; tambahkan token hanya bila peran visual baru membutuhkannya.

## Verifikasi
- Uji tablet portrait dan ponsel: header, banner, kartu sensor, FAB, dan navigasi empat menu tidak bertumpuk.
- Uji setiap kartu History membuka halaman dan data yang tepat, termasuk reload URL detail.
- Uji perubahan status sakit/sehat/diabaikan dan feedback feeding/treatment/profile.
- Uji percakapan Techi AI dari FAB dan dari kasus kesehatan.
- Periksa build, error browser, seluruh tombol utama, dan metadata setiap route baru.
