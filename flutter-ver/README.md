# Futechi (Flutter)

Port Flutter dari aplikasi web Futechi (react-js).

## Status

Struktur kode lengkap sudah ditulis, tetapi **Flutter SDK belum terpasang di
mesin ini**, jadi `flutter create`, `pub get`, `flutter analyze`, dan build
belum pernah dijalankan. Ikuti langkah berikut setelah SDK terpasang:

```powershell
git clone https://github.com/flutter/flutter.git C:\flutter
# lalu tambahkan C:\flutter\bin ke PATH, jalankan:
cd flutter-ver
flutter create --org com.futechi --project-name futechi .   # menambah platform folders (android/ios/web)
flutter pub get
flutter analyze
flutter test
flutter run
```

## Konfigurasi backend AI

Techi chat memanggil `POST /api/chat` dari deployment react-js (API key tidak
pernah dikirim ke klien). Base URL diatur lewat `--dart-define`:

```powershell
flutter run --dart-define=FUTECHI_CHAT_URL=https://<host-react-js-anda>
```

## Struktur

- `lib/data/` — model & store (kasus kesehatan, treatment + reminder, status kasus, notifikasi)
- `lib/app/` — theme, shell (header/bottom-nav), router, MaterialApp
- `lib/screens/` — Dashboard, History, Health Alerts, Consultation, Feeding, Treatment (+detail), Notifications, Profile
- `lib/screens/techi/` — chat screen, parser SUSPECTION_RESULT, thread store, klien streaming /api/chat
- `lib/widgets/` — kartu kasus, badge status, section, page title
- `todo/task.md` — rencana rewrite & checklist fase
