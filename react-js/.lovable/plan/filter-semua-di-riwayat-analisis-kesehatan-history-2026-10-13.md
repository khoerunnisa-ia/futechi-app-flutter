# Filter "Semua" di Riwayat Analisis Kesehatan (History)

Hanya bagian filter riwayat analisis yang diubah; tampilan lain tetap sama.

## Perubahan
1. **Tombol "Semua"** ditambahkan di sebelah kiri tombol Pagi dan Sore, dengan gaya yang sama. Jadi pilihannya Semua / Pagi / Sore. Default: Semua.
2. **Filter tanggal default "Semua tanggal"**: saat halaman dibuka, semua hasil analisis dari semua tanggal tampil.
3. **Pop-up kalender** diberi dua tombol:
   - **Reset**: kembali ke semua tanggal.
   - **Terapkan**: memakai tanggal yang dipilih di kalender.
   Tanggal yang dipilih di kalender baru dipakai setelah menekan Terapkan.
4. **Teks keterangan di bawah judul** mengikuti pilihan, misalnya "Semua sesi · Semua tanggal" atau "Feeding pagi · 12 Oktober 2026".
5. Ikon kalender diberi penanda kecil saat ada tanggal tertentu yang dipakai.

## Detail teknis
- Di `HistoryPage` (`src/components/futechi-pages.tsx`): `session` menjadi `"all" | FeedingSession`, defaultnya `"all"`; `date` menjadi `string | null` (null = semua tanggal), ditambah state `draftDate` untuk kalender.
- Filter: `(date === null || caseDateKey(item) === date) && (session === "all" || item.session === session)`; urutan yang ada tetap dipertahankan.
- Pesan saat hasil kosong tetap dipakai.
