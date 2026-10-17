# Perubahan — Plan Penyesuaian (flutter-ver)

Catatan setiap langkah dan file yang diubah saat menjalankan Plan Penyesuaian.

## Daftar tugas

- [x] 1. Dashboard — hero jam real-time WIB
- [x] 2. Dashboard — kartu sensor & ringkasan harian lebih pendek
- [x] 3. Dashboard — tombol feeding membuka halaman Feeding
- [x] 4. Halaman Feeding — rombak status
- [x] 5. Perawatan & Kesehatan (dashboard) — tunda/selesai + 2 terdekat
- [x] 6. Techi AI — hasil Form Suspection tidak tampil
- [ ] 7. Icon, typography, font, ukuran font

## Langkah 0 — Pemeriksaan awal

- `flutter analyze`: tidak ada issue.
- `flutter test`: 84 test lulus.
- Belum ada perubahan kode.

## Langkah 1 — Hero jam real-time WIB

File: `lib/screens/dashboard_page.dart`

- Tambah fungsi `formatWibClock(DateTime)`: `now.toUtc() + 7 jam`, format `HH:mm:ss` (`intl`), tidak bergantung zona waktu perangkat.
- Tambah widget `WibClock` (StatefulWidget) dengan `Timer.periodic(1 detik)` di state-nya; timer dihentikan di `dispose()`.
  - Timer ditaruh di widget kecil ini, bukan di state dashboard, supaya hanya teks jam yang di-rebuild tiap detik.
- Teks statis "Update terakhir: Hari ini, 07:41" diganti `WibClock` → tampil `HH:mm:ss · WIB`.

## Langkah 2 — Kartu sensor & ringkasan harian lebih pendek

File: `lib/screens/dashboard_page.dart`

- Grid sensor dan ringkasan harian sekarang memakai `SliverGridDelegateWithFixedCrossAxisCount(mainAxisExtent: ...)`, bukan `childAspectRatio`.
  - Alasan: `childAspectRatio` membuat tinggi kartu berubah mengikuti lebar layar; `mainAxisExtent` menjaga tinggi tetap pendek di semua lebar.
  - Sensor: tinggi 84 px (sebelumnya rasio 2.4 ≈ 146 px di HP). Ringkasan harian: tinggi 72 px (sebelumnya rasio 1.4).
- Tata letak kartu: ikon di kiri, angka di kanan (low-profile), bukan kolom tinggi.
  - Sensor: ikon │ nama + rentang ideal │ nilai + delta.
  - Ringkasan harian: ikon │ nilai + label (rata kanan), nilai memakai `FittedBox` agar tidak overflow.
- Isi teks dan warna tetap sama dengan `react-js/src/components/futechi-pages.tsx`.

## Langkah 3 — Tombol feeding membuka halaman Feeding

File: `lib/screens/dashboard_page.dart`

- Di `_buildFeedingCard`, snackbar "Feeding dimulai" diganti `Navigator.of(context).pushNamed(FutechiRoutes.feeding)`.
- Label tombol diganti dari "Jalankan Feeding Sekarang" menjadi "Jadwal Feeding" (ikon panah), karena tombol ini sekarang membuka halaman, bukan menjalankan feeding.

## Langkah 4 — Halaman Feeding: rombak status

File: `lib/screens/feeding_page.dart`

- Hapus tombol "Beri Pakan Sekarang" dari header `PageTitle`.
- Hapus kartu panjang `_FeederStatusCard` (mode, motor, conveyor, status MQTT, status perangkat).
- Tambah enum `FeederUiStatus { active, running, disconnected }` dan satu baris ringkas `_buildStatusRow`:

| Status | Kondisi | Label | Tombol | Aksi |
| --- | --- | --- | --- | --- |
| running | `feeding` / `systemRunning` / sedang kirim | Running | Stop | `FeederController.stopAllMotor()` |
| active | `FeederLink.state == connected` | Aktif | Start Feeding | `_feedNow()` (publish `{"run":1}` + simulasi, sama seperti sebelumnya) |
| disconnected | selain itu (disconnected/connecting/error/unsupported) | Disconnected | Connect | `FeederLink.connect()` |

- Tombol Stop nonaktif selama fase buzzer (sebelum motor jalan), supaya stop tidak tertimpa `startSystem()`.
- Tombol Connect nonaktif saat sedang menghubungkan (spinner) atau di platform tanpa MQTT (web). Bila gagal, muncul snackbar "Gagal terhubung: <error>".
- **Catatan firmware:** `main.cpp` tidak punya perintah stop lewat MQTT (hanya `{"run":1}`), jadi Stop hanya menghentikan simulasi di aplikasi; feeder fisik tetap berhenti lewat limit switch / tombol STOP fisik.
- **Perubahan perilaku:** saat feeder tidak terhubung, tombol yang tampil adalah Connect, jadi feeding (termasuk simulasi) hanya bisa dimulai setelah terhubung.

Test: `test/feeder_test.dart` — grup `FeedingPage "Beri Pakan Sekarang"` diganti grup `FeedingPage status row` (7 test): header tanpa tombol lama, Aktif + Start, Start → Running → Stop, Stop nonaktif saat buzzer, Disconnected + Connect (gagal lalu berhasil), Connect nonaktif di platform tak didukung, status `client2/status` tetap masuk ke controller.

## Langkah 5 — Perawatan & Kesehatan (dashboard)

File:

- `lib/data/treatments.dart`
  - `Treatment`: tambah `dueInDays`, `dueHour`, `dueMinute` dan `dueAt(now)` untuk mengurutkan jadwal (vaksin-nd: hari ini 08:00, vitamin-a: +3 hari 07:30, sanitasi: +5 hari 09:00, sesuai teks `schedule`).
  - `TreatmentStore`: tambah status selesai yang tersimpan di shared_preferences (`futechi-treatment-done-v1`): `isDone()`, `markDone()`.
  - `TreatmentStore.nextReminderAt()`: waktu tunda bila ada, selain itu jadwal.
  - `TreatmentStore.upcoming({now, limit})`: perawatan yang belum selesai, diurutkan dari waktu terdekat.
- `lib/data/notifications.dart`: perawatan yang sudah selesai tidak lagi muncul sebagai notifikasi pengingat.
- `lib/screens/dashboard_page.dart`
  - Kartu hardcode "Vaksinasi Newcastle Disease" + tombol "Konfirmasi Selesai" (state lokal `_treatmentDone`) dihapus.
  - Section membaca `TreatmentStore.upcoming(limit: 2)` dan mendengarkan perubahan store.
  - Tiap baris: ikon, nama, jadwal (atau "Ditunda hingga …"), badge Mendesak/Terjadwal, tombol "Tunda Reminder" (menu 1 jam / 3 jam / Besok → `store.snooze`) dan "Tandai Selesai" (`store.markDone`).
  - Tombol "Lihat semua" ke halaman Treatment; bila semua selesai tampil "Semua perawatan sudah selesai."
  - Widget baru `TreatmentSnoozeButton`.
- `lib/screens/treatment_detail_page.dart`: tambah tombol "Tandai Selesai" (berubah jadi "Sudah Selesai" dan nonaktif setelah ditekan); label "Tunda:" menjadi "Tunda Reminder:" (tombol 1 jam/3 jam/Besok sudah ada).
- `lib/screens/treatment_page.dart`: tambah fungsi `treatmentIcon()` (dipakai juga di dashboard).

## Langkah 6 — Techi AI: hasil Form Suspection tidak tampil

### Temuan saat verifikasi

1. **Mode proxy tidak pernah menampilkan teks apa pun.** Server `react-js/src/routes/api/chat.ts` memakai AI SDK 7 (`toUIMessageStreamResponse`) yang mengirim SSE `data: {"type":"text-delta","delta":"..."}`. Parser Flutter hanya membaca format lama `0:"text"`, jadi bubble jawaban selalu kosong dan blok tidak pernah bisa diparse. Ini penyebab utama di mode proxy.
2. **Parser format lama `0:"text"` juga salah:** `substring(1)` masih menyisakan `:` sehingga `jsonDecode` selalu gagal.
3. **Server proxy sebenarnya sudah mengirim instruksi SUSPECTION_RESULT** lewat opsi `system` di `chat.ts`.
4. **System message tidak boleh ditaruh di `messages`:** AI SDK 7 melempar error "System messages are not allowed in the prompt or messages fields" bila ada `role: system` di `messages` (`allowSystemInMessages` default `false`). Jadi rencana "prepend sebagai system message pertama" akan membuat `/api/chat` gagal. Sebagai gantinya instruksi ditempel di pesan `[FORM SUSPECTION]`.
5. `stop()` hanya mengubah status; stream tetap berjalan karena loop `await for` tidak memakai `_subscription`.
6. Bila model membungkus JSON dengan ```` ```json ````, atau stream dihentikan sebelum `SUSPECTION_RESULT_END`, parser mengembalikan `null` dan bubble tampil kosong (teks blok disembunyikan, kartu hasil tidak muncul).

### Perubahan

- `lib/screens/techi/chat_client.dart`
  - Mode proxy membaca SSE UI message stream (`text-delta` → teks, `error` → pesan error, `[DONE]` diabaikan). Format lama `0:"text"` tetap didukung dan sudah diperbaiki (`substring(2)`).
  - Tambah `suspicionFormatInstruction` dan `proxyTurnText()`: pesan user yang diawali `[FORM SUSPECTION]` dikirim dengan instruksi blok `SUSPECTION_RESULT_START/END` di belakangnya. Hanya di payload; teks yang disimpan di thread tidak berubah. Tidak ada `role: system` di `messages`.
  - `stop()` sekarang benar-benar menghentikan loop stream (flag `_stopRequested`) di mode direct dan proxy, lalu status menjadi `done` → layar memparse blok.
  - Status `error` dari respons non-200 tidak lagi tertimpa menjadi `done`.
- `lib/screens/techi/suspicion_parser.dart`
  - `parseSuspicionResult` toleran: END boleh hilang (stream dihentikan), dan JSON diambil dari `{` pertama sampai `}` terakhir (code fence diabaikan).
  - Tambah `stripSuspicionBlock()` untuk menampilkan teks di luar blok.
- `lib/screens/techi/techi_chat_screen.dart` (`_buildMessage`)
  - Bila blok valid: teks di luar blok + kartu hasil (penyakit, kecocokan, alasan, mitigasi, saran obat).
  - Saat masih streaming: "Techi sedang menyusun hasil pemeriksaan...".
  - Bila blok tidak valid setelah selesai: teks asli ditampilkan, tidak lagi bubble kosong.
  - Teks "Form Suspection dikirim" diberi warna putih (sebelumnya gelap di atas bubble hijau).
  - Parsing saat `ChatStatus.done` (termasuk setelah `stop()`) tetap di `_onChatChanged` → `CaseStateStore.setSuspicionResult` → `_buildCaseCard` menampilkan `suspicion.disease`.

Test: `test/suspicion_parser_test.dart` — tambah 11 test: code fence, END hilang, JSON terpotong, `stripSuspicionBlock`, proxy SSE → hasil terparse, payload tanpa system message + instruksi di pesan `[FORM SUSPECTION]`, pesan biasa tidak diubah, format lama `0:"text"`, event error SSE, `stop()` di tengah stream, status error non-200.
