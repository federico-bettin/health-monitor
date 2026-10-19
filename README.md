# Health Monitor

A personal health-tracking app built with **Flutter** (Android first, Windows supported).
It keeps lab results, specialist visits, medications and appointments in one place,
reads wearable data through **Health Connect**, and uses the **Claude API** to
analyse medical documents and produce an explainable health score.

> **Disclaimer:** this is a personal project, not a medical device. Nothing in the
> app is medical advice. Always consult a qualified healthcare professional.

The user interface is available in **Italian 🇮🇹 and English 🇬🇧**, selectable at any time in Settings.

## Screenshots

All screenshots use fictional demo data (see [Demo data](#demo-data)).

| Dashboard | Lab results | Calendar |
|:--:|:--:|:--:|
| <img src="docs/screenshots/dashboard.png" width="240"> | <img src="docs/screenshots/esami.png" width="240"> | <img src="docs/screenshots/calendario.png" width="240"> |
| Health score, wearable data and exam trends | Lab results, newest first, with out-of-range flags | Appointments with costs and reminders |

| Statistics | Settings |
|:--:|:--:|
| <img src="docs/screenshots/statistiche.png" width="240"> | <img src="docs/screenshots/impostazioni.png" width="240"> |
| Visits, exams and spending per year | Language, security, reminders, storage and backup |

## Features

### Dashboard
- **Health score (1–10)** with a short title, shown on a colour-coded card. Tap it for the full analysis: summary, benchmark against the Italian average for the patient's age group, up to three strengths, up to three areas of attention (with % deviation), three concrete improvements and up to five suggested exams.
- **Quick counters** for exams, visits, active medications and scheduled appointments.
- **Wearable summary:** steps today, heart rate and sleep, with a detail page for each metric.
- **Exam trends:** pick a medical category (blood sugar, lipids, vitamins, blood count, …) and a value to see its history over time. Categories with out-of-range values come first.

### Lab results
- Exams with any number of values, unit and reference range, laboratory, doctor and notes.
- **Colour-coded ranges** in the charts: green = in range, orange = out of range by up to 20 %, red = out of range by more than 20 %.
- **Normalised exam names** (for example "LDL", "ldl cholesterol" and "colesterolo LDL" are the same value), so trends stay continuous even when different labs name things differently.
- The original **PDF or image** of the report can be attached and reopened from the exam detail.
- Lists are always sorted from the most recent to the oldest.

### Visits
- Specialty, doctor, facility, diagnosis, therapy, prescribed drugs, notes and the original report document.
- The most recent visit per specialty feeds the health score.

### Medications
- Active and past medications with dosage, frequency, active ingredient, prescribing doctor and notes.
- Daily **intake times** for each medication.

### AI document import
- Import one or **several PDFs at once** (or an image) of a lab report or visit report.
- Claude reads the document and fills in the exam or visit form: type, date, values with units and reference ranges, diagnosis, therapy, laboratory and an interpretation. You review and confirm before saving.

### Health score
- Computed from age, BMI, lifestyle (smoking, alcohol, daily steps), the **latest result per exam type**, the **latest visit per specialty**, chronic conditions and sleep.
- Uses a **fixed scoring rubric** (the score starts at 10 and fixed penalties apply), so the same data gives the same score.
- Refreshed **automatically** when an exam or a visit is saved, **manually** with the refresh button, and never just because wearable data changed.
- When you switch language, the existing score is **translated**, not recalculated.

### Wearables (Health Connect)
- Reads weight, body fat, lean mass, body water, heart rate, steps, sleep (deep / REM) and active calories.
- Tested with a smart scale and a smart ring through Amazfit / Zepp, and works with any app that writes to Health Connect.
- Handles the quirks of real data: incremental step records are summed per day, sources are never mixed, and sleep total is derived from deep + REM when the app does not write it.
- Detail pages with charts and reference ranges (BMI, body fat, heart rate, steps, sleep, …) and a built-in diagnostics view that lists what Health Connect actually returned.

### Calendar, costs and statistics
- Appointments for visits and exams with date, time, doctor, facility and an optional **cost in euros**.
- **Statistics per year:** number of visits and exams, total spending and the list of every item with its cost.
- **Reminders:** one notification rule for all visits and exams (default: 3 days before, at 09:00), configurable in Settings. Notifications are delivered even when the app is closed.

### Patient profile
- Personal data, height and weight, medical history and chronic conditions.
- **Lifestyle:** smoking (cigarettes per day), alcohol (glasses of wine per day) and manual daily steps (used only when no wearable is connected).
- **Multiple patient profiles** on the same device.

### Data, storage and backup
- **Storage modes:** device only, Google Drive, or device + Drive.
- **Automatic Google Drive sync (Android):** the phone is the source of truth; every change is uploaded to your own Drive in the background, and PDF reports go to a `referti` subfolder. If you are offline, changes are queued and uploaded when the connection returns. Restoring on a new phone also downloads the PDFs.
- **Manual backup and restore** to a JSON file, with a list of previous backups. A backup is made automatically before switching storage mode.
- A "delete all data" option.

### Security and privacy
- **Biometric lock** (fingerprint / face).
- Data stays on the device unless you enable Google Drive.

### AI model and usage
- Choose the Claude model in Settings: **Haiku 4.5** (default, cheapest), **Sonnet 4.6** or **Opus 4.6**, with a cost badge on each.
- **Token usage** screen: input and output tokens and estimated cost, for every AI operation.

### Languages
- Full **Italian / English** interface with flags in Settings.
- The health score, the calendar and the medical terms are translated. Texts you saved yourself (exam names, notes, diagnosis, therapy) can be translated for display with one tap; **the original data is never modified**.

## Tech stack

| Area | Choice |
|---|---|
| UI / state / routing | Flutter, Riverpod, GoRouter |
| Local storage | Hive |
| Cloud | Google Sign-In, Google Drive API |
| Charts | fl_chart |
| Wearables | `health` package (Health Connect) |
| AI | Anthropic Claude API (Haiku / Sonnet / Opus selectable) |
| Notifications | flutter_local_notifications |

## Architecture

All data access goes through a single `IDataRepository` interface, resolved at runtime
by a Riverpod provider based on the storage mode chosen in Settings:

```
UI (pages)  ->  repositoryProvider  ->  IDataRepository
                                          |- LocalRepository  (Hive)
                                          |- DriveRepository  (JSON on the user's Drive)
                                          |- SyncRepository   (local + Drive)
```

With Drive sync on Android, the local Hive database stays the single source of truth: every save
schedules a debounced upload of a full backup (and of the attached PDFs) through `DriveSyncService`,
retried automatically when the connection returns.

Pages never instantiate a concrete repository, so storage can be changed without touching the UI.
Models are Hive objects with JSON (de)serialisation for backup and Drive. Data written by
earlier versions stays readable because new fields are nullable.

## Getting started

Requirements: Flutter SDK, Android SDK (minSdk 26), an Android device or emulator.

1. Clone the repository and install dependencies:
   ```bash
   flutter pub get
   ```
2. Create your local configuration (this file is git-ignored):
   ```bash
   cp lib/core/constants.template.dart lib/core/constants.dart
   ```
   Open `lib/core/constants.dart` and set your own Anthropic API key
   (<https://console.anthropic.com>). **Never commit this file.**
3. *(Only for Google Drive features)* create a Google Cloud / Firebase project, enable the
   Drive API, register an Android OAuth client for the package name and your debug SHA-1, and
   place `google-services.json` in `android/app/` (also git-ignored). If you fork the project,
   change the application id in `android/app/build.gradle.kts`.
4. Generate the Hive adapters if you change a model:
   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```
5. Run it:
   ```bash
   flutter run
   ```

Release build: `flutter build apk --release`.

### A note on the API key

The key lives in `constants.dart` and is compiled into the app, so it can be extracted from
an APK. This is fine for personal use. A public distribution should have each user enter
their own key, or route calls through a backend that holds it.

## Demo data

`docs/health_monitor_demo_backup.json` contains a fictional patient (John Smith) with 20 lab
results over two and a half years, four visits, two medications and appointments with costs,
useful for trying the app or taking screenshots. Copy it to the device's Documents folder and use
**Settings -> Backup and restore -> Restore**.
Restoring **replaces** the data currently in the app, so use a test device or make a backup first.

## Privacy

- Data stays on the device unless you enable Google Drive.
- When you use AI features, the text or image of the document you submit is sent to the Anthropic API.
- The repository contains no personal data, keys or credentials.

## Roadmap

- Per-user API key entry in Settings
- Per-record merge for multi-device sync
- Export of yearly statistics
- More languages

## License

MIT - see [LICENSE](LICENSE).

## Author

Federico Bettin - software engineer (embedded, industrial automation, safety-critical systems).
