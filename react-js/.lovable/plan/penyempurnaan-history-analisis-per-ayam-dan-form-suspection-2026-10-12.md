# Penyempurnaan History, Analisis per Ayam, dan Form Suspection Techi

## Tujuan

Merapikan prioritas dan isi kartu kesehatan, menambahkan daftar kasus aktif, mengubah analisis kamera menjadi hasil per ayam yang dapat difilter, serta membuat pemeriksaan gejala interaktif di dalam percakapan Techi AI.

## Perubahan yang akan dibuat

### 1. Kartu Peringatan Kesehatan Aktif

- Tambahkan tombol **Lihat selengkapnya** pada judul bagian.
- Tombol membuka halaman baru yang berisi ayam berstatus **Menunggu Konfirmasi** dan **Sakit**; ayam **Sudah Sehat** tidak ditampilkan di daftar aktif.
- Urutkan kartu berdasarkan tingkat urgensi: **Kritis** lebih dahulu, kemudian **Peringatan**.
- Rapikan isi setiap kartu menjadi:
  - foto dan identitas ayam/sangkar,
  - tingkat urgensi,
  - **Terdeteksi pada:** tanggal deteksi,
  - **Status ayam:** Menunggu Konfirmasi, Sakit, atau Sudah Sehat,
  - kemungkinan penyakit utama dan confidence bila masih berupa hasil analisis.
- Hilangkan jumlah ayam dari kartu.
- Pertahankan warna merah untuk **Kritis**; gunakan kuning untuk teks dan border **Peringatan**.
- Klik kartu tetap membuka detail konsultasi ayam yang sesuai.

### 2. Halaman daftar kasus aktif

- Buat halaman khusus dari aksi **Lihat selengkapnya** dengan metadata halaman tersendiri.
- Tampilkan seluruh kasus Sakit dan Menunggu Konfirmasi dengan urutan Kritis lalu Peringatan.
- Sediakan ringkasan jumlah tiap status dan pastikan setiap kartu menuju detail ayam yang benar.

### 3. Filter Hasil Analisis Kamera

- Tambahkan kontrol sesi **Pagi** dan **Sore** di sisi judul bagian.
- Tambahkan pemilih tanggal melalui ikon kalender.
- Gunakan gabungan tanggal + sesi sebagai filter; semua ayam hasil analisis yang cocok akan tampil sekaligus.
- Hilangkan konsep kartu per sesi. Ubah data menjadi kartu **per ayam**, lengkap dengan foto, identitas/sangkar, waktu deteksi, tingkat urgensi, status, indikasi utama, dan confidence.
- Klik hasil analisis kamera membuka halaman konsultasi yang sama dengan alur Peringatan Kesehatan, memakai ID ayam/kasus yang dipilih.
- Gunakan data contoh untuk beberapa tanggal pada dua sesi saja: Pagi dan Sore, termasuk keadaan kosong bila filter tidak memiliki hasil.
- pertahankan desain card saat ini yang menampilkan gambar di atas kemudian detail informasi di card meliputi waktu (tanggal, jam) dan nama penyakit paling atas atau yang terkonfirmasi. 

### 4. Form Suspection di dalam percakapan Techi AI

- Pada percakapan khusus kasus, tampilkan form perbandingan gejala sebagai bagian dari alur chat, bukan menggantikan layar chat.
- Pertahankan gaya kartu dan checkbox saat ini, tetapi susun gejala per tiga kemungkinan penyakit agar peternak dapat membandingkan pola secara visual.
- Setiap gejala memiliki checkbox: dicentang bila ditemukan, dibiarkan kosong bila tidak ditemukan.
- Tambahkan validasi dan tombol **Kirim Hasil Pemeriksaan**; tombol aktif setelah pemeriksaan form layak dikirim.
- Setelah dikirim, Techi menganalisis penyakit dengan kecocokan tertinggi melalui endpoint AI yang sama dan mengembalikan hasil terstruktur:
  - penyakit paling mungkin dan tingkat keyakinan,
  - alasan berdasarkan gejala yang dicentang,
  - langkah mitigasi,
  - saran obat/penanganan yang aman dan catatan konsultasi dokter hewan.
- Render hasil tersebut sebagai kartu khusus di dalam pesan Techi, lalu simpan form dan hasilnya bersama riwayat percakapan pada perangkat agar tetap ada setelah reload.
- Cegah klaim diagnosis pasti dan resep dosis mandiri; saran obat selalu diberi batasan keselamatan serta arahan dokter hewan.

### 5. Perubahan detail setelah pemeriksaan

- Sebelum form selesai, detail konsultasi tetap menampilkan urutan tiga kemungkinan penyakit dan probabilitasnya.
- Setelah hasil Suspection diterima, ganti bagian probabilitas pada kasus tersebut menjadi:
  - penyakit hasil pemeriksaan,
  - status hasil pemeriksaan,
  - cara mitigasi,
  - saran obat/penanganan.
- Sinkronkan perubahan status Menunggu Konfirmasi/Sakit/Sudah Sehat antara kartu History, daftar aktif, detail konsultasi, dan percakapan Techi pada perangkat yang sama.

## Struktur alur

```text
History
├── Peringatan Kesehatan Aktif
│   ├── Lihat selengkapnya → /history/health-alerts
│   └── Kartu ayam → /history/consultation/:caseId
└── Hasil Analisis Kamera
    ├── Filter tanggal + Pagi/Sore
    └── Kartu per ayam → /history/consultation/:caseId

Konsultasi kasus
└── Lanjutkan dengan Techi AI
    └── Chat kasus
        ├── Form Suspection per penyakit
        ├── Submit gejala
        └── Hasil AI + mitigasi + saran obat
```

## Detail teknis

- Pusatkan data kasus, status, tanggal deteksi, sesi feeding, gejala per penyakit, dan hasil pemeriksaan agar kedua bagian History memakai sumber data yang konsisten.
- Pertahankan panggilan AI di `/api/chat`, model dan streaming yang sudah ada; tambahkan mode pemeriksaan terstruktur tanpa memindahkan kredensial ke browser.
- Gunakan komponen AI Elements untuk pesan/form hasil dan komponen desain yang sudah tersedia untuk tombol, checkbox, kalender, serta status.
- Pertahankan penyimpanan lokal per thread/kasus yang sudah digunakan; tambahkan versi data yang aman agar riwayat lama tetap dapat dibaca.
- Tambahkan route baru beserta metadata unik tanpa mengubah route hasil konsultasi yang sudah ada.

## Verifikasi

- Pastikan urutan Kritis lalu Peringatan, warna/border, tanggal deteksi, status, dan penghapusan jumlah ayam tampil benar.
- Uji **Lihat selengkapnya** hanya menampilkan Sakit dan Menunggu Konfirmasi.
- Uji kombinasi beberapa tanggal dengan Pagi/Sore, termasuk hasil kosong dan banyak ayam dalam satu filter.
- Uji setiap kartu dari kedua bagian membuka kasus yang tepat.
- Uji form Suspection, validasi, streaming hasil AI, perubahan detail probabilitas menjadi mitigasi, serta persistensi setelah reload.
- Uji sinkronisasi status pada seluruh tampilan, layar tablet portrait dan ponsel, build, serta error browser.