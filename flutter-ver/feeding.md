# Fitur Feeding — Rekap Implementasi & Panduan Integrasi

Dokumen ini merekap port logika pemberian pakan dari firmware ESP32
(`pakan-sc/pakanAyam_v2/src/main.cpp`) ke aplikasi Flutter, serta cara
menghubungkan aplikasi dengan perangkat feeder melalui MQTT.

---

## 1. Ringkasan

| Bagian | Status |
| --- | --- |
| Port logika feeding, jadwal, dan pengaturan ke Dart | ✅ `lib/data/feeder.dart` |
| Simulasi motor, limit switch, dan conveyor di aplikasi | ✅ `SimulatedFeederHardware` |
| Koneksi MQTT ke ESP32 (kirim perintah pakan & jadwal, terima status) | ✅ `lib/data/feeder_link*.dart` (Auto-connect bootstrap + retry, `publishSchedule`, `reconnect`, logging `[MQTT]`) |
| Tombol **"Beri Pakan Sekarang"** di halaman Feeding | ✅ `lib/screens/feeding_page.dart` |
| Tombol **"Hubungkan ke Hardware"** & kartu **"Status Feeder"** (live) | ✅ `lib/screens/feeding_page.dart` |
| Test unit + widget (83 kasus lulus) | ✅ `test/feeder_test.dart` + `env_config_test.dart` + `suspicion_parser_test.dart` + `widget_test.dart` |
| Kartu jadwal & "Tambah Jadwal" di halaman Feeding | ⏳ UI lokal siap, fungsi `publishSchedule()` MQTT sudah tersedia di `FeederLink` |
| Tampilan TFT, menu keypad, WiFi/NTP, EEPROM | ❌ Tetap di ESP32 (khusus perangkat keras) |

`main.cpp` **tidak diubah**.

---

## 2. Alur tombol "Beri Pakan Sekarang"

```
[Tombol ditekan]
      │
      ├─► FeederController.feedNow()            (simulasi lokal di HP)
      │       ├─ triggerFeed("MANUAL"): buzzer 200 ms → jeda 1000 ms
      │       └─ startSystem(): motor 1 (+ motor 2 jika mode 2) + conveyor
      │
      └─► FeederLink.publishFeedNow()           (perangkat asli)
              └─ publish {"run":1} ke topik client2/set/pakan
                      │
                      ▼
               ESP32: callback() → triggerFeed("MANUAL") + startSystem()
                      │
                      ▼
               ESP32 publish {"pakan":"RUN"/"READY"/"STOP"} ke client2/status
                      │
                      ▼
               Aplikasi: "Status perangkat" di kartu Status Feeder
```

Perilaku tombol:
- Tombol **nonaktif** selama perintah dikirim, saat buzzer berjalan, atau saat sistem masih berjalan.
- Jika broker terhubung → SnackBar: *"Perintah pakan dikirim ke feeder"*.
- Jika broker gagal → simulasi tetap jalan, SnackBar: *"Feeder tidak terhubung, menjalankan simulasi saja"*.

> Simulasi di HP adalah **cerminan** perilaku firmware, bukan sumber kebenaran.
> Status asli perangkat ditampilkan pada baris **"Status perangkat"**.

---

## 3. Struktur file

| File | Isi |
| --- | --- |
| `lib/data/feeder.dart` | Port logika: `FeederController`, `FeederSchedule`, `NextSchedule`, helper (`isValidTime`, `formatTimeDisplay`, dll.), antarmuka `FeederHardware`, dan `SimulatedFeederHardware` |
| `lib/data/feeder_link.dart` | Antarmuka `FeederLink`, `FeederLinkConfig` (baca `.env` + `--dart-define`), instance bersama `sharedFeederLink` |
| `lib/config/env.dart` | Pembaca asset `.env` terpusat (`Env.mqttHost`, `Env.topicFeed`, dst.) |
| `lib/data/feeder_link_mqtt.dart` | Implementasi MQTT (`MqttFeederLink`, paket `mqtt_client`) untuk Android/iOS/desktop |
| `lib/data/feeder_link_stub.dart` | Stub untuk web (MQTT TCP tidak didukung di browser) |
| `lib/screens/feeding_page.dart` | Tombol "Beri Pakan Sekarang" + kartu "Status Feeder" |
| `test/feeder_test.dart` | Test logika, simulasi, MQTT, dan widget feeding |
| `test/env_config_test.dart` | Memastikan asset `.env` benar-benar dimuat dan nilainya mengalir ke `FeederLinkConfig` + `FeederTopics` |

Dependensi baru: `mqtt_client: ^10.13.0` dan `flutter_dotenv: ^5.2.1` (di `pubspec.yaml`).

`.env` didaftarkan sebagai asset di `pubspec.yaml` dan dimuat sekali lewat
`Env.load()` di `main.dart` (memakai `WidgetsFlutterBinding.ensureInitialized()`).

---

## 4. Logika yang di-port (pemetaan ke `main.cpp`)

### 4.1 Fungsi

| Firmware (`main.cpp`) | Dart (`FeederController` / helper) |
| --- | --- |
| `triggerFeed(mode)` | `triggerFeed(mode)` |
| callback `client2/set/pakan` (`run == 1`) | `feedNow()` / `handleMqttMessage()` |
| `startSystem()` | `startSystem()` → `bool` |
| `stopAllMotor()` | `stopAllMotor()` |
| `setSystemStatus()` | `setSystemStatus()` + `onPublish` |
| `Motor_1()`, `Motor_2()`, `conveyor()` | `_motor1()`, `_motor2()`, `_conveyor()` |
| `handleButtons()` | `handleButtons()` |
| `readLimit()` | `readLimit()` |
| `handleMotor1()`, `handleMotor2()` | `handleMotor1()`, `handleMotor2()` |
| `handleConveyor()` | `handleConveyor()` |
| `handleMotor1DirTimeout()`, `handleMotor2DirTimeout()` | sama |
| `checkSchedule()` | `checkSchedule()` |
| `getNextSchedule()` / `printNextSchedule()` | `getNextSchedule()` |
| `getTodaySchedules()` | `getTodaySchedules()` |
| `getScheduleSignature()` | `scheduleSignature()` |
| `isValidTime()`, `formatTimeDisplay()` | sama (top-level) |
| `saveScheduleToEEPROM()` (format JSON) | `schedulesToJson()` |
| `loadScheduleFromEEPROM()` (parsing) | `restoreSchedules()` |
| keypad: simpan jadwal (`MENU_ADD_DAY` + `D`) | `addSchedule(inputTime, daySelected)` |
| keypad: hapus jadwal (`MENU_DELETE` + `#`) | `deleteSchedule(index)` |
| keypad: timer (`MENU_TIMER`) | `setConveyorTime()` |
| keypad: mode motor (`MENU_MODE_MOTOR`) | `toggleRunMode()` / `setRunMode()` |
| `loadTimerFromEEPROM()`, `loadRunMode()` | `restoreConveyorTime()`, `restoreRunMode()`, `loadConveyorTime()`, `loadRunMode()` |
| `loop()` (bagian inti) | `tick()` |
| `String.toInt()` | `arduinoToInt()` |

### 4.2 Konstanta

| Nama | Nilai | Keterangan |
| --- | --- | --- |
| `limitIgnoreTimeMs` | 1000 ms | Limit switch diabaikan 1 detik pertama setelah motor mulai |
| `dirTimeoutMs` | 2000 ms | Relay DIR dimatikan setelah motor berhenti **lebih dari** 2 detik |
| `maxSchedule` | 10 | Maksimum jadwal |
| `maxScheduleDays` | 7 | Maksimum hari per jadwal |
| `defaultConveyorTime` | 5 s | Rentang valid 1–120 s |
| `defaultRunMode` | 2 | 1 = Motor 1 saja, 2 = Motor 1 + Motor 2 |
| `daysOfTheWeek` | `Minggu … Sabtu` | Indeks 0 = Minggu (sama dengan RTClib) |

### 4.3 Siklus `tick()` (setara `loop()`)

Urutan per siklus (default tiap 50 ms, hanya berjalan saat sistem aktif):

1. `handleButtons()` — tombol fisik START/STOP (falling edge, STOP diproses dulu).
2. `handleMotor1()` — jalan terus; setelah 1 s, berhenti jika `LIMIT_1` atau `LIMIT_2` aktif.
3. `handleMotor2()` — sama dengan `LIMIT_3`/`LIMIT_4`; di mode 1 motor 2 dimatikan.
4. `handleConveyor()` — berhenti setelah `conveyorTime × 1000` ms (`>=`).
5. `handleMotor1DirTimeout()` / `handleMotor2DirTimeout()`.
6. `checkSchedule()` — memulai sistem sekali per kombinasi hari + jam.

Detail penting:
- Arah motor **berganti setiap start** (`true` = kanan, `false` = kiri). Start pertama → kiri.
- Limit switch **aktif LOW**; dianggap tertekan jika ≥ 3 dari 5 sampel LOW.
- Conveyor berjalan dengan timer sendiri, dan bisa masih berjalan setelah status READY.
- Jadwal otomatis memanggil `startSystem()` **tanpa** buzzer (sesuai firmware, `triggerFeed("AUTO")` dikomentari).

### 4.4 Status sistem

| Status | Kapan |
| --- | --- |
| `READY` | Awal, dan setelah semua motor aktif berhenti di limit |
| `RUN` | Setelah `startSystem()` |
| `STOP` | Setelah emergency stop (`stopAllMotor()` / tombol STOP) |

Status hanya di-publish saat **berubah**.

### 4.5 Perbedaan dengan firmware (perbaikan)

| Firmware | Dart |
| --- | --- |
| Mode 1 selesai dengan status `STOP`; saat idle status langsung berubah READY → STOP | Selalu `READY` setelah feed selesai; idle tetap `READY` |
| Mode 2: hasil akhir tergantung motor mana yang selesai terakhir (motor 2 → STOP, motor 1 → READY) | Selalu `READY` |
| Mode 1 mematikan motor 2 setiap loop sehingga timeout DIR motor 2 tidak pernah jalan | Motor 2 dimatikan sekali; timeout DIR tetap berjalan |
| `triggerFeed` publish `RUN` lalu `STOP` sebelum `startSystem` publish `RUN` (status berkedip) | `triggerFeed` tidak publish; hanya `startSystem` yang publish `RUN` |
| Emergency stop tidak mereset flag `conveyor_running` | Flag conveyor ikut direset |
| Default global `runMode = 1`, tetapi nilai EEPROM tidak valid → 2 | Default selalu 2 |
| Jadwal MQTT dengan > 7 hari menulis melewati array `days[7]` | Dibatasi 7 hari |
| `isValidTime("ab12")` lolos (karena `toInt()` → 0) | Hanya digit yang diterima |

Perilaku yang **dipertahankan** dari firmware:
- Jika tombol START dan STOP ditekan pada siklus yang sama, sistem berhenti lalu langsung jalan lagi.
- Entri jadwal yang bukan objek tetap disimpan sebagai jadwal kosong (diabaikan oleh `getNextSchedule`).
- `set/jadwal` dengan root bukan array diabaikan; data simpanan (EEPROM) dengan root bukan array mengosongkan jadwal.

---

## 5. Integrasi MQTT

### 5.1 Topik & payload

| Topik | Arah | Payload | Keterangan |
| --- | --- | --- | --- |
| `client2/set/pakan` | App → ESP32 | `{"run":1}` | Beri pakan sekarang via `publishFeedNow()`. Nilai lain (`0`, `"1"`, `true`) diabaikan firmware |
| `client2/set/jadwal` | App → ESP32 | `[{"on":"HH:MM","days":["Senin","Rabu"]}, …]` | Ganti seluruh jadwal (maks. 10) via `publishSchedule(schedules)` |
| `client2/status` | ESP32 → App | `{"pakan":"READY"\|"RUN"\|"STOP"}` | Status perangkat, ditampilkan di "Status perangkat" |

Pengaturan koneksi aplikasi:
- QoS 0 (sama dengan firmware), keep-alive 30 s, timeout koneksi 5 s.
- Client ID acak `futechi-app-xxxxxxxx` (atau dibaca dari `MQTT_CLIENT_ID`). **Jangan** gunakan `ESP32_FEEDER`
  (client ID firmware) — broker akan memutus salah satu koneksi.
- Aplikasi hanya subscribe `client2/status`. Status simulasi **tidak** di-publish
  ke broker agar tidak tertukar dengan status perangkat asli.
- Koneksi diinisiasi otomatis:
  1. **Saat app start** (`main.dart`): bootstrap background via `sharedFeederLink.autoConnect()`.
  2. **Saat membuka FeedingPage**: auto-connect bila link dalam status `disconnected`.
  3. **Secara manual**: tombol **"Hubungkan ke Hardware"** pada kartu Status Feeder bila koneksi sempat gagal atau terputus.
  4. **Metode `reconnect()`**: memutus koneksi lama dan menyambung kembali secara bersih.

### 5.2 Konfigurasi broker (`.env`)

Kredensial **tidak** disimpan di kode. Semuanya dibaca dari asset `.env` lewat
`lib/config/env.dart`. File `.env` tidak ikut ter-commit (lihat `.gitignore`),
template tersedia di `.env.example`.

```powershell
cd flutter-ver
Copy-Item .env.example .env
# lalu isi MQTT_PASS di .env
```

| Variabel | Default | Keterangan |
| --- | --- | --- |
| `MQTT_HOST` | `mqtt.stiatech.my.id` | Sama dengan firmware |
| `MQTT_PORT` | `1883` | TCP tanpa TLS |
| `MQTT_USER` | `mqttuser` | Kosong = koneksi tanpa autentikasi |
| `MQTT_PASS` | — | **Wajib diisi** |
| `MQTT_TOPIC_STATUS` | `client2/status` | ESP32 → App |
| `MQTT_TOPIC_FEED` | `client2/set/pakan` | App → ESP32 |
| `MQTT_TOPIC_SCHEDULE` | `client2/set/jadwal` | App → ESP32 |
| `MQTT_CLIENT_ID` | `flutter-feeder-unique-01` | Harus ≠ `ESP32_FEEDER` |
| `FUTECHI_CHAT_URL` | `http://localhost:3000` | Base URL `POST /api/chat` |

Urutan prioritas pembacaan: nilai eksplisit di kode → `--dart-define` → `.env`
→ default di `Env`. Jadi nilai bisa ditimpa tanpa mengubah file:

```powershell
flutter run --dart-define=MQTT_HOST=192.168.1.10 --dart-define=MQTT_PASS=<password>
```

`.env` wajib ada saat build karena terdaftar sebagai asset di `pubspec.yaml`.
Jika lupa, `flutter build` akan gagal dengan pesan asset tidak ditemukan —
salin dari `.env.example`. Saat runtime, kegagalan memuat `.env` tidak fatal:
[Env] mencatatnya dan memakai seluruh nilai default (mode simulasi tanpa broker).

> Catatan keamanan: nilai `.env` tertanam di berkas aplikasi hasil build dan bisa
> diekstrak. Untuk produksi, pertimbangkan akun broker khusus aplikasi
> dengan ACL terbatas (hanya publish `client2/set/pakan`, subscribe
> `client2/status`) dan TLS (port 8883).

### 5.3 Platform

| Platform | Status |
| --- | --- |
| Android | ✅ — **wajib** tambah izin internet untuk build release (lihat bawah) |
| iOS / Windows / macOS / Linux | ✅ (`MqttServerClient`) |
| Web | ❌ Stub — kartu menampilkan "Tidak didukung", simulasi tetap jalan |

**Android release:** izin `INTERNET` saat ini hanya ada di manifest `debug` dan
`profile`. Tambahkan ke `android/app/src/main/AndroidManifest.xml`:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.INTERNET"/>
    ...
```

Tanpa ini, MQTT berfungsi di `flutter run` (debug) tetapi gagal di APK release.

### 5.4 Uji koneksi tanpa aplikasi (Mosquitto CLI)

Sebelum menyentuh aplikasi, pastikan broker + perangkat sudah benar.

**Terminal 1 — pantau semua trafik feeder:**

```powershell
mosquitto_sub -h mqtt.stiatech.my.id -p 1883 -u mqttuser -P <password> -t "client2/#" -v
```

Biarkan terminal ini terbuka. Ia akan menampilkan:
- `client2/status {...}` → perangkat hidup dan melaporkan status
- `client2/set/pakan ...` → ada yang mengirim perintah pakan

**Terminal 2 — kirim perintah pakan manual:**

```powershell
mosquitto_pub -h mqtt.stiatech.my.id -p 1883 -u mqttuser -P <password> -t client2/set/pakan -m "{\"run\":1}"
```

Yang harus terlihat: buzzer ESP32 berbunyi, motor berputar, dan Terminal 1
menampilkan `client2/status {"pakan":"RUN"}` lalu `READY`/`STOP`.

**Kirim jadwal:**

```powershell
mosquitto_pub -h mqtt.stiatech.my.id -p 1883 -u mqttuser -P <password> -t client2/set/jadwal -m "[{\"on\":\"07:00\",\"days\":[\"Senin\",\"Rabu\"]}]"
```

Jadwal akan tampil di layar TFT ESP32 (kolom "Jadwal:") dan tersimpan di EEPROM.

Jika ESP32 merespons perintah dari CLI, berarti sisi perangkat dan broker sudah
benar, dan sisa masalah pasti ada di aplikasi.

---

## 7. Prosedur pengujian aplikasi (end-to-end)

### 7.1 Persiapan

```powershell
cd flutter-ver
Copy-Item .env.example .env
# edit .env → isi MQTT_PASS dengan password broker yang valid
flutter pub get
```

Pastikan `.env` sudah benar:

```powershell
Get-Content .env
```

### 7.2 Uji statis (tanpa perangkat)

```powershell
flutter analyze                 # harus 0 error
flutter test                    # seluruh test
flutter test test/feeder_test.dart   # khusus fitur feeding
```

Test yang relevan dengan konfigurasi baru:

| Test | Yang diverifikasi |
| --- | --- |
| `helpers › topik MQTT default sama dengan firmware` | `FeederTopics` jatuh ke `client2/*` saat `.env` tidak dimuat |
| `FeederLinkConfig › memakai nilai default .env saat tanpa --dart-define` | Host/port/user/pass/clientId default |
| `FeederLinkConfig › description ... tanpa membocorkan password` | Diagnostik tidak memuat password |
| `Env › belum dimuat → seluruh getter memakai default` | Semua getter `Env` aman sebelum `load()` |
| `env_config_test › asset .env dimuat dan mengisi konfigurasi MQTT` | `.env` asli terbaca dan nilainya sampai ke config + topik |
| `env_config_test › MQTT_CLIENT_ID dari .env tidak bentrok dengan firmware` | Client ID ≠ `ESP32_FEEDER` |

### 7.3 Uji koneksi dari aplikasi (tanpa perangkat)

1. Jalankan di desktop (paling cepat untuk melihat log):

   ```powershell
   flutter run -d windows --verbose
   ```

   atau di tablet/HP Android:

   ```powershell
   flutter run -d <device-id> --verbose
   ```

2. Saat aplikasi start atau saat membuka halaman **Feeding**, pada konsol akan terlihat alur log debug terperinci:

   ```
   [FeederLink] autoConnect() dipanggil (maxRetries=3)
   [FeederLink] autoConnect mencoba koneksi (percobaan 1/3)...
   [MQTT] Menghubungkan ke broker: mqtt.stiatech.my.id:1883 user=mqttuser clientId=flutter-feeder-unique-01
   [MQTT] Callback onConnected: terhubung ke broker mqtt.stiatech.my.id:1883
   [MQTT] Berhasil terhubung! Mendaftarkan subscription ke: client2/status
   [MQTT] Callback onSubscribed: berhasil subscribe topik "client2/status"
   [MQTT] State changed: connected
   [FeederLink] autoConnect berhasil pada percobaan 1
   ```

3. Baris **"Feeder (MQTT)"** pada kartu Status Feeder harus berubah menjadi **"Terhubung"**.

Jika broker/jaringan belum siap:
- Konsol mencatat retry:
  ```
  [FeederLink] autoConnect gagal, menunggu jeda sebelum percobaan berikutnya...
  [FeederLink] autoConnect mencoba koneksi (percobaan 2/3)...
  ```
- Jika seluruh retry gagal, state menjadi `error` dengan pesan spesifik (`[MQTT] State changed: error (error: ...)`).
- Kartu **Status Feeder** di UI menampilkan label merah **"Gagal terhubung"**, pesan error, dan tombol **"Hubungkan ke Hardware"**.
- Setelah jaringan/broker siap, user cukup menekan tombol **"Hubungkan ke Hardware"** untuk memicu koneksi ulang secara instan.

> `debugPrint` hanya aktif di build debug. Di release, baris log ini tidak membebani sistem.

### 7.4 Uji perintah pakan (aplikasi + perangkat)

1. Buka Terminal 1 (`mosquitto_sub -t "client2/#" -v`) dan biarkan terbuka.
2. Nyalakan ESP32, pastikan layar TFT menunjukkan `WiFi: OK` dan `MQTT: OK`.
3. Di aplikasi, tekan **"Beri Pakan Sekarang"**.
4. Verifikasi berurutan:

| Cek | Hasil yang diharapkan |
| --- | --- |
| Terminal 1 | `client2/set/pakan {"run":1}` lalu `client2/status {"pakan":"RUN"}` |
| Perangkat | buzzer berbunyi, motor + conveyor bergerak |
| Perangkat | setelah motor menyentuh limit, `client2/status {"pakan":"READY"}` |
| Aplikasi | SnackBar *"Perintah pakan dikirim ke feeder"* |
| Aplikasi | baris **"Status perangkat"** berubah `RUN` → `READY` |
| Aplikasi | tombol kembali aktif setelah sistem selesai |

Kalau Terminal 1 menampilkan `set/pakan` tetapi perangkat tidak bergerak,
masalahnya di firmware/perangkat (bukan aplikasi). Kalau Terminal 1 **tidak**
menampilkan apa pun, masalahnya di konfigurasi `.env` aplikasi.

### 7.5 Uji status masuk ke aplikasi

Dari Terminal 2, kirim status palsu dan lihat apakah UI menangkapnya:

```powershell
mosquitto_pub -h mqtt.stiatech.my.id -p 1883 -u mqttuser -P <password> -t client2/status -m "{\"pakan\":\"STOP\"}"
```

Baris **"Status perangkat"** harus berubah menjadi `STOP` **tanpa** menekan
tombol apa pun — ini membuktikan jalur ESP32 → App bekerja.

> Catatan: aplikasi **tidak** publish status simulasi ke broker, jadi angka
> simulasi di kartu (Motor 1/2, Conveyor) berasal dari HP, sedangkan baris
> "Status perangkat" berasal dari perangkat asli. Lihat bagian 4.5.

### 7.6 Uji mode gagal (kontrol negatif)

| Skenario | Cara | Hasil yang diharapkan |
| --- | --- | --- |
| Password salah | Ubah `MQTT_PASS` di `.env`, `flutter run` | `[MQTT] ditolak: ...` + kartu "Gagal terhubung" |
| Broker tidak bisa dijangkau | Ubah `MQTT_HOST` ke host palsu | `[MQTT] gagal: SocketException ...` |
| Perangkat mati | Matikan ESP32, tekan tombol pakan | Publish tetap "berhasil", tetapi **tidak ada** `client2/status` di Terminal 1 |
| Port diblokir jaringan | Pakai jaringan berbeda (mis. hotspot HP) | Koneksi gagal — cek firewall/ISP |

### 7.7 Uji di perangkat Android fisik (release)

Izin `INTERNET` sudah ada di `android/app/src/main/AndroidManifest.xml`, jadi:

```powershell
flutter build apk --release
flutter install
```

Uji ulang 7.3–7.5 di APK release. Jika MQTT jalan di debug tetapi tidak di
release, periksa kembali izin `INTERNET` di manifest `main` (bukan hanya
`debug`/`profile`).

### 7.8 Checklist verifikasi cepat

- [ ] `flutter analyze` bersih
- [ ] `flutter test` hijau (termasuk grup `Env` dan `FeederLinkConfig`)
- [ ] `[MQTT] terhubung, subscribe client2/status` muncul di konsol
- [ ] `mosquitto_sub` melihat `client2/set/pakan` saat tombol ditekan
- [ ] ESP32 berbunyi + motor bergerak saat tombol ditekan
- [ ] `client2/status` dari CLI langsung muncul di baris "Status perangkat"
- [ ] Password salah → pesan error jelas, tidak crash

---

## 6. Hardware (referensi dari firmware)

Logika Dart mengakses pin melalui antarmuka `FeederHardware`
(`millis`, `digitalWrite`, `digitalRead`, `delay`). Konstanta pin ada di `FeederPins`.

| Pin | GPIO | Fungsi |
| --- | --- | --- |
| `buzzer` | 17 | Buzzer |
| `buttonStart` | 13 | Tombol START (INPUT_PULLUP, aktif LOW) |
| `buttonStop` | 14 | Tombol STOP / emergency (INPUT_PULLUP, aktif LOW) |
| `limit1`, `limit2` | 35, 34 | Limit switch motor 1 (aktif LOW) |
| `limit3`, `limit4` | 39, 36 | Limit switch motor 2 (aktif LOW) |
| `relay1` | 32 | EN conveyor |
| `relay2` | 33 | EN motor 1 |
| `relay3` | 25 | DIR motor 1 (HIGH = kanan) |
| `relay4` | 26 | EN motor 2 |
| `relay5` | 27 | DIR motor 2 (HIGH = kanan) |

Perangkat lain di firmware (tidak di-port): RTC DS3231, TFT (TFT_eSPI),
keypad I2C `0x27`, WiFiManager (hotspot `FEEDER_AP`), NTP WIB (UTC+7), EEPROM.

### 6.1 Simulasi (`SimulatedFeederHardware`)

- Setiap motor bergerak di antara dua limit switch. Waktu tempuh default:
  motor 1 = 4000 ms, motor 2 = 5000 ms.
- DIR HIGH bergerak ke limit kedua (`limit2`/`limit4`), DIR LOW ke limit pertama.
- Posisi awal di limit kedua, karena start pertama membalik arah ke kiri (LOW).
- Tombol fisik selalu HIGH (tidak ditekan).

### 6.2 Menghubungkan logika Dart ke hardware lain

Untuk menjalankan logika yang sama di hardware lain (misalnya board serial/USB
atau GPIO Raspberry Pi), buat implementasi `FeederHardware`:

```dart
class MyBoardHardware implements FeederHardware {
  @override
  int millis() => /* waktu sejak start, ms */;
  @override
  void digitalWrite(int pin, bool high) => /* tulis relay/buzzer */;
  @override
  bool digitalRead(int pin) => /* baca tombol/limit; true = HIGH */;
  @override
  Future<void> delay(int ms) => Future.delayed(Duration(milliseconds: ms));
}

final controller = FeederController(hardware: MyBoardHardware());
```

`tick()` otomatis berjalan tiap 50 ms selama sistem aktif (`autoTick: true`).
Untuk menjalankan `checkSchedule()` terus-menerus, panggil `tick()` secara
berkala dari luar.

---

## 8. Testing otomatis

```powershell
flutter test test/feeder_test.dart   # seluruh test fitur feeding
flutter test                         # seluruh test
```

Cakupan `test/feeder_test.dart`:

| Grup | Yang diuji |
| --- | --- |
| helpers | `isValidTime`, `formatTimeDisplay`, `arduinoToInt`, `restoreConveyorTime`, `restoreRunMode`, `dayOfTheWeek`, topik MQTT default |
| FeederLinkConfig / Env | Default `.env`, nilai eksplisit, `description` tanpa password |
| settings | Default, batas timer 1–120, toggle/validasi mode |
| triggerFeed / feedNow | Urutan buzzer & jeda, penolakan saat sibuk, publish RUN sekali |
| startSystem | Mode 1 vs 2, arah bergantian, start ganda diabaikan |
| limits and completion | Abaikan 1 s, mayoritas 3/5 sampel, status READY di semua urutan & mode |
| conveyor | Timer `>=`, tetap jalan setelah motor selesai |
| DIR relay timeout | `> 2000 ms`, termasuk setelah pindah ke mode 1 |
| buttons | STOP, START falling edge, start setelah STOP |
| status publish | Hanya saat berubah |
| MQTT messages | `set/pakan`, `client2/status`, `set/jadwal` (valid, invalid, batas 10 jadwal / 7 hari) |
| schedules | Tambah, hapus, format JSON, restore |
| getNextSchedule / getTodaySchedules / checkSchedule | Hari ini, minggu depan, hari lain, trigger sekali |
| simulated hardware | Siklus penuh dua arah sampai READY dan semua relay mati |
| FeedingPage | Tombol mengirim MQTT + simulasi, mode offline, status perangkat, tombol "Hubungkan ke Hardware", auto-connect |
| FeederLink operations | `publishSchedule` (kirim JSON jadwal), `reconnect` (putus & sambung ulang), `autoConnect` (skips jika connected, retry jika offline) |

---

## 9. Troubleshooting

| Gejala | Kemungkinan penyebab & Solusi |
| --- | --- |
| Kartu menampilkan "Gagal terhubung" | Host/port salah, kredensial salah/kosong, tidak ada internet, port 1883 diblokir jaringan. Baca baris `[MQTT] Koneksi ditolak:` / `[MQTT] Gagal koneksi:` di konsol, lalu tekan tombol **"Hubungkan ke Hardware"** setelah memperbaiki koneksi |
| `[MQTT] gagal: ... fileName = ".env"` | `.env` belum dibuat / belum didaftarkan sebagai asset. Jalankan `Copy-Item .env.example .env` |
| Password terisi tapi ditolak | Cek `Get-Content .env` — nilai tidak boleh dibungkus tanda kutip |
| Berfungsi di debug tetapi tidak di APK release | Izin `INTERNET` belum ada di manifest `main` (lihat 5.3) |
| Aplikasi terhubung, tetapi feeder tidak bergerak | ESP32 offline/belum terhubung ke broker; cek dengan `mosquitto_sub` |
| ESP32 sering terputus dari broker | Ada client lain memakai client ID `ESP32_FEEDER` (pastikan app memakai `flutter-feeder-unique-01` atau random ID) |
| "Status perangkat" tetap `-` | ESP32 hanya publish saat status berubah; tunggu sampai feed berjalan |
| Status simulasi berbeda dengan perangkat | Firmware masih memakai logika status lama (lihat 4.5) |
| Web: "Tidak didukung" | MQTT TCP tidak tersedia di browser; perlu MQTT over WebSocket |

---

## 10. Pekerjaan lanjutan

- ✅ Implementasi `publishSchedule()` di `FeederLink` dan `MqttFeederLink`.
- Hubungkan kartu jadwal & "Tambah Jadwal" di UI `FeedingPage` ke `FeederController` dan kirim otomatis via `FeederLink.publishSchedule()`.
- Simpan jadwal/pengaturan di perangkat (misalnya `shared_preferences`) memakai `schedulesToJson()` / `restoreSchedules()`.
- Terapkan perbaikan status (bagian 4.5) di firmware agar status simulasi dan perangkat konsisten.
- Tambah topik stop jarak jauh di firmware (saat ini tidak ada perintah STOP via MQTT).
- Dukungan web melalui `MqttBrowserClient` (WebSocket), jika broker menyediakannya.
- TLS (port 8883) dan akun broker khusus aplikasi.

---

## 11. Integrasi CCTV Tapo RTSP Live Stream (Tahap 2)

- Backend player menggunakan **`media_kit` (Opsi A)** dengan decode video hardware-accelerated berbasis libmpv.
- Widget `CctvCard` (`lib/widgets/cctv_player.dart`) menampilkan frame 16:9, label judul "CCTV Pemantauan Kandang", "Kualitas HD", badge merah "● LIVE", indikator status streaming, tombol stop/pause, reconnect, serta modal fullscreen dialog.
- Layout `DashboardPage` ditata persis dengan React (`futechi-pages.tsx`): Barn Overview Card tetap utuh sebagai denah kandang, Row 1 berisi Jadwal Feeding + CCTV Kandang, dan Row 2 berisi Perawatan & Kesehatan + Ringkasan Harian (4 kartu 2×2).
- URL RTSP kamera Tapo dikonfigurasikan di `.env` (`CCTV_RTSP_URL=rtsp://user:pass@ip:554/stream1`). Bila kosong, aplikasi beralih ke simulasi thumbnail statis `assets/images/cctv-kandang.jpg`.

---

## 12. Integrasi Direct Cloud LLM Techi AI (Tahap 3)

- `ChatClient` (`lib/screens/techi/chat_client.dart`) mendukung koneksi langsung ke provider LLM OpenAI-compatible (OpenRouter, Groq, dll.) menggunakan Server-Sent Events (SSE) HTTP streaming tanpa bergantung pada proxy localhost backend.
- Konfigurasi via `.env`: `LLM_API_KEY`, `LLM_BASE_URL`, `LLM_MODEL`. Otomatis fallback ke proxy legacy `FUTECHI_CHAT_URL` bila API key kosong.
- Dilengkapi system prompt peternakan Futechi serta dukungan blok rekomendasi penyakit `SUSPECTION_RESULT_START ... SUSPECTION_RESULT_END` yang diparsing oleh `suspicion_parser.dart`.

