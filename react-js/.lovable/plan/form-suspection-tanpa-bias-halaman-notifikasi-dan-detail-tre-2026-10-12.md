# Form Suspection Tanpa Bias, Halaman Notifikasi, dan Detail Treatment

## 1. Form Suspection hanya menampilkan gejala

- Hapus nama penyakit dan persentase "Analisis awal" dari form di chat Techi.
- Gabungkan gejala dari tiga kemungkinan penyakit menjadi satu daftar checkbox (gejala yang sama hanya muncul sekali), urutan diacak tetap per kasus agar tidak memberi petunjuk kelompok penyakit
- checkbox nya kotak bukan radio.
- Desain kartu, checkbox, validasi, dan tombol **Kirim Hasil Pemeriksaan** tetap sama.
- Pesan sambutan Techi di percakapan kasus juga tidak lagi menyebut nama penyakit/persentase sebelum form dikirim.
- Di belakang layar, setiap gejala tetap dipetakan ke penyakitnya sehingga AI tetap bisa menentukan kecocokan tertinggi. Hasil setelah submit (penyakit, alasan, mitigasi, saran penanganan) tidak berubah.

## 2. Halaman Notifikasi (baru)

- Ikon lonceng di header membuka halaman **Notifikasi**; titik merah menunjukkan jumlah belum dibaca.
- Dua jenis notifikasi dummy dengan tab filter **Semua / Kesehatan / Treatment**:
  - **Hasil analisis video feeding**: dibuat otomatis untuk setiap ayam yang terdeteksi sakit (dari data kasus yang sudah ada), berisi foto kecil, sangkar, sesi Pagi/Sore, waktu, dan tingkat urgensi. Klik membuka detail konsultasi ayam tersebut.
  - **Treatment**: pengingat jadwal (mis. Vaksinasi ND-Gumboro hari ini, Vitamin A dalam 3 hari, reminder yang ditunda). Klik membuka halaman detail treatment.
- Tanda sudah/belum dibaca dan tombol **Tandai semua dibaca**, disimpan di perangkat.

## 3. Halaman Detail Treatment (baru)

- Tombol **Lihat Detail** pada jadwal di Treatment di dashboar membuka halaman detail sendiri (menggantikan pop-up). begitu juga di semua data card treatment ketika di klik akan membuka halaman sendiri (bukan pop up).
- Isi halaman:
  - ringkasan treatment: nama, jadwal, status;
  - **Informasi obat**: nama produk, kandungan, bentuk sediaan;
  - **Dosis** sesuai label/anjuran dokter hewan dengan catatan keselamatan;
  - **Panduan pemberian step by step** (checklist bernomor);
  - tombol **Beli Produk** (link toko) dan **Tonton Tutorial** (link video), dibuka di tab baru;
  - kartu **Reminder**: saklar aktif/nonaktif, pilihan tunda (1 jam, 3 jam, besok), menampilkan waktu pengingat berikutnya. Status reminder disimpan di perangkat dan tampil sinkron di halaman Notifikasi.
- Data obat, dosis, dan link adalah contoh; perlu diganti dengan produk dan dosis resmi dari Anda/dokter hewan.

## Struktur alur

```text
Header lonceng -> /notifications
  ├── Notif kesehatan -> /history/consultation/:caseId
  └── Notif treatment -> /treatment/:treatmentId
Treatment -> Lihat Detail -> /treatment/:treatmentId
  ├── Obat, dosis, langkah pemberian
  ├── Beli Produk / Tonton Tutorial
  └── Reminder: aktif / tunda
```

## Detail teknis

- Pusatkan data treatment dummy (obat, dosis, langkah, link) di satu modul data, dipakai Treatment, detail, dan Notifikasi.
- Route baru: `notifications.tsx`, `treatment.$treatmentId.tsx` (`treatment.tsx` menjadi layout Outlet + `treatment.index.tsx`), masing-masing dengan metadata unik.
- Notifikasi kesehatan diturunkan dari data kasus + status bersama (ayam yang sudah sehat tidak dibuat notifikasi baru).
- Reminder & status baca disimpan di localStorage dengan pola event yang sama seperti status kasus.
- Form: kirim ke `/api/chat` tetap menyertakan pemetaan gejala-penyakit; tampilan saja yang disembunyikan.

## Verifikasi

- Form tidak memuat teks nama penyakit atau persen; submit tetap menghasilkan kartu hasil.
- Lonceng membuka Notifikasi, filter tab, klik menuju halaman benar, tandai dibaca bertahan setelah reload.
- Detail treatment menampilkan semua bagian; link terbuka; reminder aktif/tunda bertahan setelah reload.
- Build dan tampilan tablet portrait tanpa error.