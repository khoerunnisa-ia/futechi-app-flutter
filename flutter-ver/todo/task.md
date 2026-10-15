# Rewrite Plan: react-js → Flutter (flutter-ver)

Sumber kebenaran: `react-js/` (TanStack Router + React). Target: `flutter-ver/`
(Flutter, Material 3, stateless data + ChangeNotifier, shared_preferences).

## Arsitektur target

```
flutter-ver/
├── pubspec.yaml                 # dependencies & assets
├── analysis_options.yaml        # flutter_lints
├── assets/images/               # foto dari react-js/src/assets
├── todo/task.md                 # file ini
└── lib/
    ├── main.dart                # entry point
    ├── app/
    │   ├── futechi_app.dart     # MaterialApp + theme + navigator shell
    │   ├── theme.dart           # warna (dari styles.css) & tipografi
    │   ├── app_shell.dart       # header, bottom nav, FAB Techi, notification bell
    │   └── router.dart          # pemetaan route (NamaRoute, param) → screen
    ├── data/
    │   ├── health_case.dart     # ← lib/futechi-cases.ts (data + helpers)
    │   ├── treatments.dart      # ← lib/futechi-treatments.ts (data + reminder)
    │   ├── case_state.dart      # ← lib/futechi-case-state.ts (ChangeNotifier + prefs)
    │   └── notifications.dart   # ← useNotifications (futechi-extra-pages.tsx)
    ├── screens/
    │   ├── dashboard_page.dart  # DashboardPage
    │   ├── history_page.dart    # HistoryPage (+ filter tanggal/sesi)
    │   ├── health_alerts_page.dart
    │   ├── consultation_page.dart   # /history/consultation/:alertId (+ feeding-analysis, report)
    │   ├── feeding_page.dart
    │   ├── treatment_page.dart
    │   ├── treatment_detail_page.dart
    │   ├── notifications_page.dart
    │   ├── profile_page.dart
    │   └── techi/
    │       ├── techi_chat_screen.dart   # ← components/techi-chat.tsx
    │       ├── techi_threads.dart       # ← hooks/use-techi-threads.ts (persistence)
    │       └── suspicion_parser.dart    # parse SUSPECTION_RESULT_START/END
    └── widgets/
        ├── page_title.dart
        ├── section.dart
        ├── status_badge.dart
        └── case_card.dart
```

## Pemetaan route (TanStack → Navigator 2.0 sederhana / named routes)

| react-js route                             | Flutter screen                       |
| ------------------------------------------ | ------------------------------------ |
| `/`                                        | DashboardPage                        |
| `/history`                                 | HistoryPage                          |
| `/history/health-alerts`                   | HealthAlertsPage                     |
| `/history/consultation/:alertId`           | ConsultationPage(alertId)            |
| `/history/feeding-analysis/:analysisId`    | ConsultationPage(analysisId)         |
| `/history/report/:reportId`                | ConsultationPage("a24")              |
| `/feeding`                                 | FeedingPage                          |
| `/treatment`                               | TreatmentPage                        |
| `/treatment/:treatmentId`                  | TreatmentDetailPage(treatmentId)     |
| `/notifications`                           | NotificationsPage                    |
| `/profile`                                 | ProfilePage                          |
| `/techi`                                   | TechiChatScreen(threadId: "current") |
| `/techi/:threadId`                         | TechiChatScreen(threadId)            |

## Fase pekerjaan

- [x] **Fase 0 — Scaffold**: pubspec.yaml, analysis_options, .gitignore, lib/main.dart
- [x] **Fase 1 — Data layer** (port lib/*.ts):
      - [x] `data/health_case.dart`
      - [x] `data/treatments.dart`
      - [x] `data/case_state.dart`
      - [x] `data/notifications.dart`
- [x] **Fase 2 — Theme & shell**:
      - [x] `app/theme.dart`
      - [x] `app/app_shell.dart`
      - [x] `app/router.dart` (named routes + onGenerateRoute)
- [x] **Fase 3 — Halaman utama**:
      - [x] DashboardPage (`screens/dashboard_page.dart`)
      - [x] HistoryPage (`screens/history_page.dart`)
      - [x] CaseCard + StatusBadge (`widgets/case_card.dart`)
- [x] **Fase 4 — Halaman detail & lainnya**:
      - [x] ConsultationPage (`screens/consultation_page.dart`)
      - [x] HealthAlertsPage (`screens/health_alerts_page.dart`)
      - [x] FeedingAnalysisPage & ReportPage → ConsultationPage (lihat router.dart)
      - [x] FeedingPage (`screens/feeding_page.dart`)
      - [x] TreatmentPage + TreatmentDetailPage (url_launcher, reminder snooze 1/3/24 jam)
      - [x] NotificationsPage (`screens/notifications_page.dart`)
      - [x] ProfilePage (`screens/profile_page.dart`)
- [x] **Fase 5 — Techi chat**:
      - [x] `techi/suspicion_parser.dart`
      - [x] `techi/techi_threads.dart` (shared_preferences)
      - [x] `techi/chat_client.dart` (streaming POST /api/chat via http)
      - [x] `techi/techi_chat_screen.dart`
- [x] **Fase 6 — Aset (parsial)**:
      - [x] Copy futechi-barn.jpg, sick-chicken-feeding.jpg, techi-mascot.png
      - [ ] 5 aset `.asset.json` Lovable (hero, cctv, feeding pagi/sore, avian) belum
            tersedia sebagai file lokal — placeholder kotak abu-abu dipakai;
            unduh gambar aslinya ke assets/images/ lalu update `caseImage()`
- [ ] **Fase 7 — Verifikasi** (BLOCKED: Flutter SDK belum terpasang):
      - [ ] `flutter create .` untuk platform folders (android/ios/web)
      - [ ] `flutter pub get && flutter analyze`
      - [ ] `flutter test` (test/suspicion_parser_test.dart sudah disiapkan)
      - [ ] Run di emulator/tablet: bottom nav, safe area, layout 2 kolom

## Catatan penting

1. **Data lokal tetap device-specific** (keputusan proyek): status kasus, reminder,
   thread Techi disimpan di shared_preferences, bukan akun/cloud.
2. **AI tetap lewat `/api/chat`** — API key tidak pernah masuk klien; thread id
   berasal dari route (`alert-<caseId>` atau uuid).
3. **Font**: DM Sans (display/judul) & Manrope (body) — tambahkan sebagai font asset
   atau fallback ke default Material.
4. ** Bahasa UI**: seluruh teks Bahasa Indonesia dipertahankan apa adanya.
5. **Stack AI**: model gateway (Lovable) tetap dipanggil via endpoint server yang ada;
   jika aplikasi mobile berdiri sendiri tanpa web host, endpoint `/api/chat` harus
   diberi base URL konfigurasi.
