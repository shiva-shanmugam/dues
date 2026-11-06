# Dues

Dues is a private Android subscription tracker built with Flutter. It reads transaction SMS messages from Indian banks, cards, and UPI providers, detects recurring charges, and schedules renewal reminders. There is no account, backend, analytics SDK, or network call; application data stays in local SQLite storage.

## Run

Requirements:

- Latest stable Flutter with Dart 3.13 or newer
- Android SDK 36 and Java 17
- Android 7.0 (API 24) or newer
- A physical Android phone for SMS inbox testing

```sh
flutter pub get
dart run build_runner build
flutter run
```

On first launch, Dues explains why SMS access is needed before Android displays the `READ_SMS` permission prompt. Notification permission is requested only after SMS access is granted. If SMS access is declined, every manual feature remains available.

## Architecture

```text
lib/
  core/           theme, formatting, WorkManager entry point
  data/           Drift database, repositories, platform-facing services
  domain/         models, repository contracts, SMS import orchestration
  parser/         pure-Dart parsing, normalization, recurrence detection
  presentation/   Riverpod providers, pages, shell, reusable widgets
```

Drift stores subscriptions, parsed debit transactions, ignored merchants, and local settings in `dues.sqlite`. Riverpod exposes database streams to the dashboard and subscription list. Manual and SMS-detected subscriptions share the same domain model and repository.

## SMS parsing

The native Kotlin channel exposes only three operations: check permission, request permission, and read the inbox. It queries `content://sms/inbox` after permission is granted and returns message ID, sender, body, and timestamp to Dart.

The pure-Dart parser then:

1. Rejects OTPs, balance/limit messages, card statements, promotions, login alerts, credits, refunds, and declined transactions.
2. Recognizes debit language used by HDFC, ICICI, SBI, Axis, Paytm, GPay, PhonePe, and similar providers.
3. Extracts INR amounts, transaction dates, and merchant phrases following `at`, `to`, `towards`, `for`, and mandate/autopay patterns.
4. Normalizes aliases such as `NETFLIX.COM` and `Netflix India` to `Netflix`.
5. Tags free-trial, auto-debit, mandate, and renewal signals.
6. Groups normalized merchants by similar amount (within 5%, with bounded tolerance) and infers weekly, monthly, quarterly, or yearly cycles from median intervals.

Recurring interval detection requires at least two matching occurrences. A single explicit auto-debit, mandate, renewal, or trial signal is retained as a monthly candidate until more history is available. Marking an item “Not a subscription” stores its normalized merchant in the ignored table so future scans skip it.

Parser tests include more than 25 realistic examples covering banks, cards, UPI apps, merchant variants, decimal and comma-separated amounts, OTPs, credits, refunds, one-off purchases, promotions, and irregular recurrence.

## Notifications

`flutter_local_notifications` schedules two local reminders at 09:00 local time: three days and one day before renewal. Inexact idle-safe alarms avoid exact-alarm permission. Scheduled-notification receivers restore alarms after reboot or app replacement. A daily WorkManager task re-reads Drift and reconciles schedules while the app is closed. Editing, pausing, deleting, or importing subscriptions also immediately reschedules reminders.

## Other local features

- Manual add, edit, pause, resume, and delete
- Ignored-merchant learning
- CSV export through Android's share sheet
- Dashboard monthly equivalent, yearly projection, upcoming renewals, and cost ranking

## Verify

```sh
flutter analyze
flutter test
flutter build apk --debug
```

SMS inbox behavior and notification delivery must be verified on a physical Android device because emulators and widget tests do not provide a real inbox or OEM background-power behavior.
