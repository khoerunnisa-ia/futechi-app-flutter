# Futechi (Flutter)
TODO : di hero banner seharusnya jam dan waktu nya real time

Port Flutter dari aplikasi web Futechi (Smart Poultry Farm) yang mencakup integrasi IoT Feeder (MQTT ESP32), Live Streaming CCTV Kamera Tapo (RTSP media_kit), dan Chat AI Konsultasi Penyakit Techi (Direct Cloud LLM via OpenRouter/Groq).

## Status Implementasi

- **Flutter SDK**: 3.44.8 / Dart 3.12+ (Channel stable).
- **Analisis Statis**: `flutter analyze` bersih (0 issues/warnings).
- **Pengujian**: Seluruh unit test & widget test lulus.
- **Tahap 1 — Koneksi MQTT ESP32 (Selesai)**:
  - Auto-connect aktif saat aplikasi start (bootstrap di background + retry otomatis).
  - Halaman Feeding dilengkapi kartu status live, auto-connect, dan tombol **"Hubungkan ke Hardware"**.
  - `publishFeedNow()` (topik `client2/set/pakan`) dan `publishSchedule()` (topik `client2/set/jadwal`) didukung penuh dengan log `[MQTT]`.
- **Tahap 2 — CCTV Tapo RTSP Live Stream (Selesai)**:
  - Menggunakan **Opsi A (media_kit + libmpv backend)**: hardware-accelerated playback, native RTSP TCP low-latency.
  - Penataan layout DashboardPage 100% identik dengan React (`futechi-pages.tsx`):
    - Row 1: Jadwal Feeding berdampingan dengan CCTV Pemantauan Kandang (Frame 16:9, badge ● LIVE, mode expand fullscreen dialog, tombol refresh/reconnect).
    - Row 2: Perawatan & Kesehatan berdampingan dengan Ringkasan Harian (4 kartu 2×2).
    - Barn Overview Card tetap utuh sebagai peta isometrik kandang.
- **Tahap 3 — Direct Cloud LLM Techi AI (Selesai)**:
  - `ChatClient` mendukung direct call ke cloud provider LLM (OpenRouter, Groq, atau OpenAI-compatible) via HTTP SSE streaming.
  - Dilengkapi system prompt operasional Futechi dan parsing otomatis tag `SUSPECTION_RESULT_START ... SUSPECTION_RESULT_END` untuk diagnosis penyakit ayam.
  - Otomatis fallback ke backend proxy legacy (`POST /api/chat`) jika `LLM_API_KEY` tidak diisi.

---

## Konfigurasi (`.env`)

Semua nilai yang bergantung pada lingkungan dibaca dari asset `.env` melalui
`lib/config/env.dart`. File `.env` **tidak** di-commit — template tersedia di
`.env.example`:

```powershell
Copy-Item .env.example .env
```

| Variabel | Default | Keterangan |
| --- | --- | --- |
| `MQTT_HOST` | `mqtt.stiatech.my.id` | Host broker, sama dengan firmware |
| `MQTT_PORT` | `1883` | 1883 = TCP polos, 8883 = TLS |
| `MQTT_USER` | `mqttuser` | Username autentikasi broker MQTT |
| `MQTT_PASS` | — | **Password broker**, jangan di-commit |
| `MQTT_TOPIC_STATUS` | `client2/status` | Status dari perangkat ESP32 |
| `MQTT_TOPIC_FEED` | `client2/set/pakan` | Perintah beri pakan |
| `MQTT_TOPIC_SCHEDULE` | `client2/set/jadwal` | Perintah sinkronisasi jadwal |
| `MQTT_CLIENT_ID` | `flutter-feeder-unique-01` | Harus ≠ `ESP32_FEEDER` |
| `FUTECHI_CHAT_URL` | `http://localhost:3000` | Host react-js backend proxy (Mode B) |
| `LLM_API_KEY` | — | **API Key Cloud LLM** (OpenRouter / Groq / OpenAI) (Mode A) |
| `LLM_BASE_URL` | `https://openrouter.ai/api/v1/chat/completions` | Endpoint chat completions SSE |
| `LLM_MODEL` | `google/gemini-2.0-flash-001` | Model AI untuk konsultasi Techi |
| `CCTV_RTSP_URL` | — | URL RTSP Tapo (Stream 1: `rtsp://user:pass@IP:554/stream1`) |
| `CCTV_RTSP_SUBSTREAM_URL`| — | URL RTSP Sub-stream Tapo (Stream 2: 360p/720p) |
| `CCTV_AUTO_PLAY` | `false` | Otomatis putar stream video saat kartu CCTV tampil |

---

## Panduan Penggunaan & Setup

### 1. Setup Kamera CCTV TP-Link Tapo (C200 / C210 / TC70)

1. Buka aplikasi **TP-Link Tapo** di smartphone Anda.
2. Pilih kamera kandang -> masuk ke **Device Settings (Ikon Gear)** -> **Advanced Settings** -> **Camera Account**.
3. Buat username dan password akun kamera lokal (misal: user: `kandang`, pass: `rahasia123`).
4. Cari IP lokal kamera di router atau menu Device Info (misal: `192.168.1.100`).
5. Masukkan URL ke file `.env`:
   ```env
   CCTV_RTSP_URL=rtsp://kandang:rahasia123@192.168.1.100:554/stream1
   CCTV_AUTO_PLAY=true
   ```
6. Bila `CCTV_RTSP_URL` dikosongkan, widget otomatis beralih ke thumbnail simulasi statis (mode demo).

### 2. Setup AI Techi Chat (Direct Cloud LLM)

1. Dapatkan API Key dari [OpenRouter](https://openrouter.ai/) atau [Groq](https://console.groq.com/).
2. Masukkan ke file `.env`:
   ```env
   LLM_API_KEY=sk-or-v1-xxxxxx...
   LLM_MODEL=google/gemini-2.0-flash-001
   ```
3. Buka tab **Techi AI** di aplikasi untuk berkonsultasi seputar kesehatan unggas, diagnosis penyakit, dan penanganan gejala abnormal.

### 3. Prosedur Debug MQTT & Feeder Hardware

Jalankan aplikasi dengan opsi `--verbose` untuk melihat seluruh alur koneksi:

```powershell
flutter run -d windows --verbose
```

Pesan konsol penting:
- `[FeederLink] autoConnect() dipanggil`: Indikasi bootstrap koneksi otomatis.
- `[MQTT] Callback onConnected`: Terhubung ke broker.
- `[MQTT] Pesan diterima [client2/status]`: Status live dari ESP32.
- `[MQTT] publish client2/set/pakan`: Perintah feeding terkirim.
- `[MQTT] publish client2/set/jadwal`: Jadwal terkirim.

---

## Struktur Direktori

- `lib/config/` — pembaca `.env` (`Env`)
- `lib/data/` — model & store (kasus kesehatan, treatment + reminder, notifikasi, feeder + link MQTT)
- `lib/app/` — theme, shell (header/bottom-nav), router, MaterialApp
- `lib/screens/` — Dashboard, History, Health Alerts, Consultation, Feeding, Treatment (+detail), Notifications, Profile
- `lib/screens/techi/` — chat screen, parser SUSPECTION_RESULT, thread store, klien direct LLM / proxy
- `lib/widgets/` — cctv_player, kartu kasus, badge status, section, page title
