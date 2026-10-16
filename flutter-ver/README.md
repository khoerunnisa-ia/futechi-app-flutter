# Futechi (Flutter)

# TODO 
KONEKSIKAN API CHAT KE OPENROUTER MODEL AgaR BENAR-BENAR INTERAKTIF

Port Flutter dari aplikasi web Futechi (react-js).

## Status

- **Flutter SDK**: 3.44.8 (Channel stable) terpasang.
- **Analisis Statis**: `flutter analyze` bersih (0 issues).
- **Pengujian**: `flutter test` 83/83 tes berhasil (unit, widget, & MQTT link).
- **Koneksi MQTT ESP32**:
  - Auto-connect aktif saat aplikasi start (bootstrap di background + retry otomatis).
  - Halaman Feeding dilengkapi pemantauan live, auto-connect, dan tombol **"Hubungkan ke Hardware"**.
  - `publishFeedNow()` (topik `client2/set/pakan`) dan `publishSchedule()` (topik `client2/set/jadwal`) didukung penuh dengan log `[MQTT]`.

## Konfigurasi (`.env`)

Semua nilai yang bergantung pada lingkungan dibaca dari asset `.env` melalui
`lib/config/env.dart`. File `.env` **tidak** di-commit — template tersedia di
`.env.example`:

```powershell
Copy-Item .env.example .env
# lalu edit .env dan isi MQTT_PASS
```

| Variabel | Default | Keterangan |
| --- | --- | --- |
| `MQTT_HOST` | `mqtt.stiatech.my.id` | Host broker, sama dengan firmware |
| `MQTT_PORT` | `1883` | 1883 = TCP polos, 8883 = TLS (belum didukung) |
| `MQTT_USER` | `mqttuser` | Kosong = tanpa autentikasi |
| `MQTT_PASS` | — | **Wajib diisi**, jangan commit |
| `MQTT_TOPIC_STATUS` | `client2/status` | Status dari perangkat |
| `MQTT_TOPIC_FEED` | `client2/set/pakan` | Perintah pakan |
| `MQTT_TOPIC_SCHEDULE` | `client2/set/jadwal` | Perintah jadwal |
| `MQTT_CLIENT_ID` | `flutter-feeder-unique-01` | Harus ≠ `ESP32_FEEDER` |
| `FUTECHI_CHAT_URL` | `http://localhost:3000` | Host react-js untuk `POST /api/chat` |

Setiap nilai masih bisa ditimpa saat menjalankan aplikasi tanpa mengubah file:

```powershell
flutter run --dart-define=MQTT_HOST=192.168.1.10 --dart-define=MQTT_PASS=<password>
```

Urutan prioritas: nilai eksplisit di kode → `--dart-define` → `.env` → default.

## Prosedur Debug MQTT

### 1. Memantau Log di Konsol (`flutter run`)

Jalankan aplikasi dengan opsi `--verbose` untuk melihat seluruh alur koneksi:

```powershell
flutter run -d windows --verbose
```

Filter pesan log dengan kata kunci `[MQTT]` dan `[FeederLink]`:

- `[FeederLink] autoConnect() dipanggil (maxRetries=3)`: Indikasi bootstrap koneksi otomatis.
- `[MQTT] Menghubungkan ke broker: mqtt.stiatech.my.id:1883 ...`: Upaya koneksi awal.
- `[MQTT] Callback onConnected: terhubung ke broker ...`: Socket TCP dan handshake MQTT sukses.
- `[MQTT] Berhasil terhubung! Mendaftarkan subscription ke: client2/status`: Listener topik status aktif.
- `[MQTT] Pesan diterima [client2/status]: {"pakan":"READY"}`: Status live dari hardware.
- `[MQTT] publish client2/set/pakan {"run":1} berhasil dikirim`: Perintah pakan berhasil diteruskan ke broker.
- `[MQTT] publish client2/set/jadwal [...] berhasil dikirim`: Sinkronisasi jadwal berhasil diteruskan.

### 2. Diagnosis Error Broker

Bila koneksi gagal, periksa pesan spesifik:
- `Username atau password broker MQTT salah` (ReturnCode: `badUsernameOrPassword`): Cek nilai `MQTT_PASS` di `.env`.
- `Client ID ditolak oleh broker MQTT` (ReturnCode: `identifierRejected`): Pastikan `MQTT_CLIENT_ID` bukan `ESP32_FEEDER`.
- `Server broker MQTT tidak tersedia` (ReturnCode: `brokerUnavailable`): Cek koneksi internet dan status server broker.

### 3. Tombol "Hubungkan ke Hardware" di UI

Jika aplikasi dimulai saat broker/hardware sedang offline, kartu **Status Feeder** di halaman Feeding akan menampilkan status **Gagal terhubung** beserta tombol **"Hubungkan ke Hardware"**. Menekan tombol ini akan memicu `link.connect()` secara instan.

### 4. Menjalankan & Menguji Kode

```powershell
flutter analyze                 # Harus 0 issues
flutter test                    # Seluruh test unit & widget
flutter test test/feeder_test.dart   # Khusus logika feeding & MQTT
```

## Struktur

- `lib/config/` — pembaca `.env` (`Env`)
- `lib/data/` — model & store (kasus kesehatan, treatment + reminder, status kasus, notifikasi, feeder + link MQTT)
- `lib/app/` — theme, shell (header/bottom-nav), router, MaterialApp
- `lib/screens/` — Dashboard, History, Health Alerts, Consultation, Feeding, Treatment (+detail), Notifications, Profile
- `lib/screens/techi/` — chat screen, parser SUSPECTION_RESULT, thread store, klien streaming /api/chat
- `lib/widgets/` — kartu kasus, badge status, section, page title
- `todo/task.md` — rencana rewrite & checklist fase
