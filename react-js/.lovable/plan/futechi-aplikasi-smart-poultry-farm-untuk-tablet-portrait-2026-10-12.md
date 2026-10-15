# Futechi — aplikasi smart poultry farm untuk tablet portrait

## Ringkasan

Membangun pengalaman operasional kandang yang lengkap di `/`, berfokus pada tablet vertikal dan mengikuti referensi visual yang diunggah tanpa menanam screenshot tersebut sebagai isi aplikasi. Desain memakai warm neutral, golden amber/terracotta, kartu putih membulat, elevasi lembut, ikon yang jelas, serta navigasi atas dan bawah yang tetap terlihat.

## Halaman dan alur

- **Dashboard:** header identitas Futechi, sub-kandang, pencarian global, notifikasi, profil Anne Fremant, status kondisi kandang, waktu pembaruan, tiga metrik sensor beserta tren, visual kandang isometrik interaktif, jadwal feeding, CCTV live, perawatan mendesak, dan ringkasan harian.
- **History:** ringkasan kesehatan, peringatan aktif, status kandang, hasil analisis kamera, filter tanggal, serta halaman detail laporan dengan anomali, tingkat keyakinan, tindakan konfirmasi/abaikan, dan rekomendasi AI.
- **Treatment:** manajemen batch, tambah batch, daftar perawatan hari ini/mendatang, detail jadwal, pengaturan pembersihan, dan konfirmasi selesai.
- **Feeding:** jadwal otomatis dengan toggle aktif/nonaktif, tambah jadwal, dan aksi “Jalankan Feeding Sekarang”.
- **Techi AI:** daftar banyak percakapan, pembuatan percakapan baru, URL khusus untuk tiap percakapan, riwayat tersimpan di Lovable Cloud, respons streaming berformat markdown, indikator mengetik, dan konteks konsultasi kesehatan/operasional kandang.
- **Profil & pengaturan:** data Anne Fremant, edit profil, kata sandi, notifikasi, bahasa, bantuan, privasi, tentang Futechi, dan keluar akun.

## Interaksi utama

- Bottom navigation tetap berada dalam jangkauan ibu jari dan menandai halaman aktif.
- Header tetap terlihat; pencarian menampilkan hasil cepat lintas sensor, kandang, jadwal, dan laporan.
- Toggle jadwal, konfirmasi perawatan, filter, detail kandang, ekspansi CCTV, notifikasi, dan menu profil memiliki state yang nyata dan feedback visual.
- Dashboard menyesuaikan dari susunan tablet dua kolom ke satu kolom pada layar lebih sempit tanpa tumpang tindih.

## Visual dan aset

- Menetapkan token desain semantik untuk latar warm neutral, amber/terracotta, status sukses/peringatan/kritis, border, shadow, dan tipografi kontras tinggi.
- Membuat aset visual kandang isometrik yang koheren untuk pusat dashboard; screenshot unggahan dipakai sebagai acuan desain saja.
- Menggunakan identitas visual Techi AI yang khas dan konsisten pada daftar percakapan serta ruang chat.
- Menghormati reduced motion dan menjaga ukuran kontrol sentuh nyaman untuk tablet.
- jangan gunakan icon ataupun emot secara berlebihan, buat tampilannya clean. 

## Data, AI, dan keamanan

- Mengaktifkan Lovable Cloud untuk akun, penyimpanan thread/pesan, dan data operasional yang perlu bertahan.
- Menyimpan thread dan pesan per pengguna; setiap thread memiliki ID stabil, URL sendiri, urutan pesan, judul, serta waktu pembaruan.
- Menjalankan Techi AI melalui server dan Lovable AI Gateway dengan model default yang tersedia; kunci dan instruksi tetap di server.
- Menyimpan pesan pengguna dan jawaban selesai pada thread yang sama, menangani kegagalan penyimpanan/streaming, dan tidak memberi diagnosis pasti tanpa peringatan konsultasi profesional.
- Menyediakan data contoh Futechi yang konsisten dengan brief agar semua modul langsung terisi saat pertama dibuka.

## Struktur teknis

- Membuat route terpisah untuk Dashboard, History, detail laporan, Treatment, Feeding, daftar Techi AI, thread Techi AI, dan Profil; setiap route memiliki metadata unik.
- Membuat shell aplikasi bersama untuk top header dan bottom navigation, serta komponen reusable untuk kartu sensor, status, jadwal, dan item tindakan.
- Menggunakan AI Elements/AI SDK untuk transcript, composer, markdown, status streaming, dan persistence; textarea tetap fokus setelah kirim, selesai, atau pindah thread.
- Mencatat keputusan arsitektur baru dan menjaga implementasi sesuai pola TanStack Start/Tailwind v4 proyek.

## Verifikasi

- Memeriksa tampilan pada tablet portrait sebagai target utama, lalu desktop dan mobile untuk memastikan tidak ada clipping atau overlap.
- Menguji navigasi, pencarian, toggle feeding, konfirmasi perawatan, detail laporan, profil, dan kontrol CCTV (pastikan kodenya bisa menerima assets video karena ini akan berupa video)
- Menguji sedikitnya dua thread AI: kirim pesan pada masing-masing, pindah thread, muat ulang URL, dan pastikan riwayat yang benar kembali.
- Memvalidasi respons AI nyata, state error/kredit/rate limit, metadata setiap halaman, serta hasil build dan pemeriksaan browser tanpa error.