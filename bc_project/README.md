# 📱 Family Finance & Zakat Manager
### Offline-First Flutter App | Islamic Finance | Google Drive Backup

---

## 🗂️ Complete File Structure

```
family_finance_zakat/
│
├── lib/
│   ├── main.dart                          ✅ Entry point
│   ├── app.dart                           ✅ Theme + Router + PIN gate
│   │
│   ├── core/
│   │   ├── database/
│   │   │   ├── tables/tables.dart         ✅ All Drift table definitions
│   │   │   ├── app_database.dart          ✅ DB + all DAOs
│   │   │   └── app_database.g.dart        ⚙️  Auto-generated (run build_runner)
│   │   │
│   │   ├── backup/
│   │   │   └── backup_service.dart        ✅ Google Drive OAuth2 + ZIP backup
│   │   │
│   │   ├── security/
│   │   │   └── auth_service.dart          ✅ PIN + biometric auth
│   │   │
│   │   ├── utils/
│   │   │   ├── formatters.dart            ✅ Currency, date, file size
│   │   │   └── constants.dart             ✅ App-wide constants + validators
│   │   │
│   │   └── providers.dart                 ✅ All Riverpod providers + streams
│   │
│   ├── features/
│   │   ├── zakat/data/
│   │   │   └── zakat_engine.dart          ✅ Islamic Zakat calculation engine
│   │   │
│   │   └── reports/data/
│   │       └── pdf_report_service.dart    ✅ Monthly/Yearly/Zakat PDF reports
│   │
│   └── ui/
│       ├── screens/
│       │   ├── main_shell.dart            ✅ Bottom nav shell
│       │   ├── home_screen.dart           ✅ Dashboard with charts
│       │   ├── transactions_screen.dart   ✅ List + filter + search
│       │   ├── add_transaction_screen.dart ✅ Full CRUD form
│       │   ├── assets_screen.dart         ✅ All asset types CRUD
│       │   ├── liabilities_screen.dart    ✅ Loans/committees + payments
│       │   ├── zakat_screen.dart          ✅ Zakat calculator + history
│       │   ├── reports_screen.dart        ✅ Charts + PDF export
│       │   ├── settings_screen.dart       ✅ PIN/biometric/backup/prices
│       │   └── pin_lock_screen.dart       ✅ Numeric PIN lock screen
│       │
│       └── widgets/
│           ├── summary_card.dart          ✅ Metric card widget
│           ├── transaction_tile.dart      ✅ Swipeable transaction row
│           └── loading_widget.dart        ✅ Loading + empty state
│
├── android/
│   ├── app/
│   │   ├── build.gradle                   ✅ App-level Gradle config
│   │   ├── proguard-rules.pro             ✅ Release optimisation rules
│   │   └── src/main/
│   │       ├── AndroidManifest.xml        ✅ Permissions + providers
│   │       └── res/xml/
│   │           ├── network_security_config.xml ✅ HTTPS enforcement
│   │           └── file_paths.xml         ✅ FileProvider paths
│   │
│   └── build.gradle                       ✅ Root Gradle + Google Services
│
├── pubspec.yaml                           ✅ All dependencies declared
├── build.yaml                             ✅ Drift + Riverpod codegen config
├── analysis_options.yaml                  ✅ Dart linting rules
└── README.md                              ✅ This file
```

---

## ⚡ Quick Start

### 1. Prerequisites
```bash
flutter --version   # Requires Flutter 3.16+
dart --version      # Requires Dart 3.2+
```

### 2. Install Dependencies
```bash
cd family_finance_zakat
flutter pub get
```

### 3. Generate Drift Code ⚠️ REQUIRED
```bash
dart run build_runner build --delete-conflicting-outputs
```
> This generates `app_database.g.dart`. Must be run once before building.

### 4. Create Asset Directories
```bash
mkdir -p assets/images assets/icons assets/fonts
```
> Add a placeholder file (e.g. `.gitkeep`) in each if empty, or remove
> the font entry from pubspec.yaml if you don't have the Urdu font.

### 5. Google Drive Setup
1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Create a project → Enable **Google Drive API**
3. Create **OAuth 2.0 credentials** (Android client)
4. Add your app's **SHA-1 fingerprint** (debug + release)
5. Download `google-services.json` → place in `android/app/`

### 6. Run the App
```bash
flutter run --debug
# or
flutter run --release
```

---

## 🏗️ Architecture

```
Presentation Layer  →  Riverpod Providers  →  DAO Layer  →  Drift SQLite
     (UI)                 (State)              (Data)        (Storage)
```

- **Riverpod** manages all state via `StreamProvider` (live DB streams)
- **Drift** handles all SQLite with type-safe generated code
- **Clean separation**: UI never touches DB directly — always through providers
- **Offline-first**: 100% functional without internet

---

## 🗄️ Database Tables

| Table               | Purpose                                |
|---------------------|----------------------------------------|
| `transactions`      | Income & expense entries               |
| `categories`        | Predefined + custom categories         |
| `assets`            | Gold, silver, cash, land, business...  |
| `liabilities`       | Loans, committees, debts               |
| `liability_payments`| Payment history per liability          |
| `zakat_snapshots`   | Yearly Zakat calculation history       |
| `app_settings`      | Key-value settings store               |

---

## 🤲 Zakat Engine Formula

```
Zakatable Wealth = Gold + Silver + Cash + Business Assets + Other Zakatable
                 − Total Liabilities

Nisab (Silver) = 612.36g × Silver price/gram
Nisab (Gold)   = 87.48g  × Gold price/gram

Zakat = 2.5% × Zakatable Wealth   (if Zakatable Wealth ≥ Nisab)
```

> Set gold and silver prices in **Settings → Zakat Settings**

---

## ☁️ Backup Flow

**Backup:**
1. All DB tables → exported to JSON
2. JSON → compressed to ZIP
3. ZIP → uploaded to Google Drive (`FamilyFinanceBackup/` folder)

**Restore:**
1. List backups from Drive
2. Download selected ZIP
3. Extract → parse JSON
4. Import all records into local DB

---

## 🔐 Security Layers

| Layer              | Implementation                          |
|--------------------|-----------------------------------------|
| PIN Lock           | SHA-256 hashed, 5-attempt lockout       |
| Biometric          | `local_auth` (fingerprint / face ID)    |
| Secure Storage     | `flutter_secure_storage` (AES encrypted)|
| Auto-lock          | Re-locks after 5 min background         |
| HTTPS only         | `network_security_config.xml`           |
| No plain-text DB   | SQLite (binary, not human-readable)     |

---

## 📊 Report Types

| Report      | Format  | Contents                                  |
|-------------|---------|-------------------------------------------|
| Monthly     | PDF     | Summary, category breakdown, all transactions |
| Yearly      | PDF     | Month-by-month chart, assets, liabilities |
| Zakat       | PDF     | Wealth breakdown, Nisab comparison, amount due |
| In-app      | Charts  | Bar charts, pie charts, progress bars     |

---

## 🐛 Troubleshooting

### `app_database.g.dart` not found
```bash
dart run build_runner build --delete-conflicting-outputs
```

### Google Sign-In fails
- Verify SHA-1 fingerprint in Google Cloud Console matches your keystore
- Confirm `google-services.json` is in `android/app/`
- Enable Drive API in Google Cloud Console

### Biometric not working
- Minimum Android API 23 (minSdk is set to 23 in build.gradle)
- Enroll fingerprint in device Settings before testing

### PDF generation error
- `printing` package requires a physical device or emulator with PDF support
- Use `Printing.layoutPdf()` for print dialog, or save bytes to file directly

---

## 🏷️ Package Versions (key)

| Package                | Version  | Purpose              |
|------------------------|----------|----------------------|
| `drift`                | ^2.14.1  | SQLite ORM           |
| `drift_flutter`        | ^0.1.0   | Flutter DB adapter   |
| `flutter_riverpod`     | ^2.4.9   | State management     |
| `google_sign_in`       | ^6.2.1   | Google OAuth2        |
| `googleapis`           | ^12.0.0  | Drive API client     |
| `local_auth`           | ^2.1.8   | Biometric auth       |
| `flutter_secure_storage`| ^9.0.0  | Encrypted storage    |
| `pdf` + `printing`     | ^3/^5    | PDF generation       |
| `fl_chart`             | ^0.67.0  | Charts               |
| `archive`              | ^3.4.10  | ZIP compression      |

---

## 👨‍💻 Developer

**dev:tahirbuneri**  
Family Finance & Zakat Manager — Offline-First, Production-Ready
