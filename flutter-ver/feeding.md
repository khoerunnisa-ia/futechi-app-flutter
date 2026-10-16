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
| Koneksi MQTT ke ESP32 (kirim perintah pakan, terima status) | ✅ `lib/data/feeder_link*.dart` |
| Tombol **"Beri Pakan Sekarang"** di halaman Feeding | ✅ `lib/screens/feeding_page.dart` |
| Kartu **"Status Feeder"** (live) | ✅ `lib/screens/feeding_page.dart` |
| Test unit + widget (60 kasus) | ✅ `test/feeder_test.dart` |
| Kartu jadwal & "Tambah Jadwal" di halaman Feeding | ❌ Masih data contoh, belum terhubung ke logika jadwal / MQTT |
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
| `lib/data/feeder_link.dart` | Antarmuka `FeederLink`, `FeederLinkConfig` (baca `--dart-define`), instance bersama `sharedFeederLink` |
| `lib/data/feeder_link_mqtt.dart` | Implementasi MQTT (`MqttFeederLink`, paket `mqtt_client`) untuk Android/iOS/desktop |
| `lib/data/feeder_link_stub.dart` | Stub untuk web (MQTT TCP tidak didukung di browser) |
| `lib/screens/feeding_page.dart` | Tombol "Beri Pakan Sekarang" + kartu "Status Feeder" |
| `test/feeder_test.dart` | 60 test (logika, simulasi, MQTT, widget) |

Dependensi baru: `mqtt_client: ^10.13.0` (di `pubspec.yaml`).

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
| `client2/set/pakan` | App → ESP32 | `{"run":1}` | Beri pakan sekarang. Nilai lain (`0`, `"1"`, `true`) diabaikan |
| `client2/set/jadwal` | → ESP32 | `[{"on":"HH:MM","days":["Senin","Rabu"]}, …]` | Ganti seluruh jadwal (maks. 10). **Belum dikirim oleh aplikasi** |
| `client2/status` | ESP32 → App | `{"pakan":"READY"\|"RUN"\|"STOP"}` | Status perangkat, ditampilkan di "Status perangkat" |

Pengaturan koneksi aplikasi:
- QoS 0 (sama dengan firmware), keep-alive 30 s, timeout koneksi 5 s.
- Client ID acak `futechi-app-xxxxxxxx`. **Jangan** gunakan `ESP32_FEEDER`
  (client ID firmware) — broker akan memutus salah satu koneksi.
- Aplikasi hanya subscribe `client2/status`. Status simulasi **tidak** di-publish
  ke broker agar tidak tertukar dengan status perangkat asli.
- Koneksi dibuka saat tombol pertama kali ditekan, lalu dipakai ulang.

### 5.2 Konfigurasi broker

Kredensial **tidak** disimpan di kode. Nilai dibaca dari `--dart-define`:

| Variabel | Default | Keterangan |
| --- | --- | --- |
| `MQTT_HOST` | `mqtt.stiatech.my.id` | Sama dengan firmware |
| `MQTT_PORT` | `1883` | TCP tanpa TLS |
| `MQTT_USER` | kosong | Kosong = koneksi tanpa autentikasi |
| `MQTT_PASS` | kosong | |

Menjalankan aplikasi:

```powershell
flutter run --dart-define=MQTT_USER=<user> --dart-define=MQTT_PASS=<password>
```

Atau simpan di file lokal (jangan di-commit, tambahkan ke `.gitignore`):

```json
// mqtt.local.json
{ "MQTT_USER": "<user>", "MQTT_PASS": "<password>" }
```

```powershell
flutter run --dart-define-from-file=mqtt.local.json
```

> Catatan keamanan: nilai `--dart-define` tertanam di file aplikasi hasil build
> dan bisa diekstrak. Untuk produksi, pertimbangkan akun broker khusus aplikasi
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

Pantau status perangkat:

```powershell
mosquitto_sub -h mqtt.stiatech.my.id -p 1883 -u <user> -P <password> -t "client2/#" -v
```

Kirim perintah pakan manual:

```powershell
mosquitto_pub -h mqtt.stiatech.my.id -p 1883 -u <user> -P <password> -t client2/set/pakan -m "{\"run\":1}"
```

Kirim jadwal:

```powershell
mosquitto_pub -h mqtt.stiatech.my.id -p 1883 -u <user> -P <password> -t client2/set/jadwal -m "[{\"on\":\"07:00\",\"days\":[\"Senin\",\"Rabu\"]}]"
```

Jika ESP32 merespons perintah dari CLI, berarti sisi perangkat dan broker sudah benar.

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

## 7. Testing

```powershell
flutter test test/feeder_test.dart   # 60 test fitur feeding
flutter test                         # seluruh test
```

Cakupan `test/feeder_test.dart`:

| Grup | Yang diuji |
| --- | --- |
| helpers | `isValidTime`, `formatTimeDisplay`, `arduinoToInt`, `restoreConveyorTime`, `restoreRunMode`, `dayOfTheWeek` |
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
| FeedingPage | Tombol mengirim MQTT + menjalankan logika, mode offline, status perangkat |

---

## 8. Troubleshooting

| Gejala | Kemungkinan penyebab |
| --- | --- |
| Kartu menampilkan "Gagal terhubung" | Host/port salah, kredensial salah/kosong, tidak ada internet, port 1883 diblokir jaringan |
| Berfungsi di debug tetapi tidak di APK release | Izin `INTERNET` belum ada di manifest `main` (lihat 5.3) |
| Aplikasi terhubung, tetapi feeder tidak bergerak | ESP32 offline/belum terhubung ke broker; cek dengan `mosquitto_sub` |
| ESP32 sering terputus dari broker | Ada client lain memakai client ID `ESP32_FEEDER` |
| "Status perangkat" tetap `-` | ESP32 hanya publish saat status berubah; tunggu sampai feed berjalan |
| Status simulasi berbeda dengan perangkat | Firmware masih memakai logika status lama (lihat 4.5) |
| Web: "Tidak didukung" | MQTT TCP tidak tersedia di browser; perlu MQTT over WebSocket |

---

## 9. Pekerjaan lanjutan (belum dikerjakan)

- Hubungkan kartu jadwal & "Tambah Jadwal" ke `FeederController` dan kirim ke `client2/set/jadwal`.
- Simpan jadwal/pengaturan di perangkat (misalnya `shared_preferences`) memakai `schedulesToJson()` / `restoreSchedules()`.
- Terapkan perbaikan status (bagian 4.5) di firmware agar status simulasi dan perangkat konsisten.
- Tambah topik stop jarak jauh di firmware (saat ini tidak ada perintah STOP via MQTT).
- Dukungan web melalui `MqttBrowserClient` (WebSocket), jika broker menyediakannya.
- TLS (port 8883) dan akun broker khusus aplikasi.
