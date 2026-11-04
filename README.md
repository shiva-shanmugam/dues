# Dues

Dues is a private, Android-first subscription tracker. This repository is currently at **Stage 1: UI shell with fake data**.

## Run

1. Install the latest stable Flutter SDK and Android Studio.
2. Start an Android emulator or connect a device with USB debugging enabled.
3. From this directory, run:

   ```sh
   flutter pub get
   flutter run
   ```

## Current stage

- Nothing OS-inspired, dark-only interface with bundled Doto and Space Mono fonts
- Home dashboard, subscription list, and settings tabs
- Responsive dashboard totals, upcoming renewals, cost ranking, pause, and delete interactions
- Riverpod-backed fake repository and domain model
- Clean `data / domain / presentation` structure ready for real services
- Fully offline UI: no runtime font download, backend, analytics, or network calls

## Planned stages

The fake repository will be replaced by Drift-backed storage. A pure-Dart parser will normalize merchant names and classify realistic Indian bank, UPI, and card SMS messages; recurrence detection will group similar charges and infer weekly, monthly, quarterly, or yearly cycles. Android SMS permission onboarding, background renewal notifications, manual editing, ignored-merchant rules, and CSV export will be added after the UI shell is approved.

No SMS permission is requested in this stage because message access is not yet implemented.
