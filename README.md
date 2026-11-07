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

## Receipt design system

Dues uses one flat, monochrome receipt language in light and dark modes. The
bundled `IBM Plex Mono` font is loaded from `assets/fonts`; the app never fetches
fonts at runtime. The color tokens live in `lib/core/theme/app_theme.dart`:

| Token | Light / paper | Dark / night receipt |
| --- | --- | --- |
| Background | `#FBFAF6` | `#121212` |
| Ink | `#111111` | `#F2EFE6` |
| Muted | `#555555` | `#A09B8F` |
| Divider | `#111111` | `#F2EFE6` |

System, Light, and Dark modes are available in Config. The choice is saved in
the existing local settings table and restored before the first app frame;
System mode continues to follow Android appearance changes live.
Tap the theme button beside CONFIG to cycle Dark → Light → System → Dark.

On a fresh launch, a brief receipt-printing intro types DUES and moves the title
into the statement header. It respects the system's reduced-motion setting and
does not replay when the app resumes. Subscription details keep headings and
actions fixed while only the saved SMS history scrolls. Add/edit sheets can be
dragged down to dismiss without saving.

Ignored merchants open a read-only summary of saved payment history when
tapped. The separate RESTORE action asks for confirmation before allowing the
merchant in future scans. If Android blocks renewal notifications, Config offers
a link to the app's notification settings; re-enable alerts after granting access.

When adding a presentation screen, use `ReceiptTokens` through
`context.receipt`, apply uppercase headings with `receiptHeading` or
`receiptLabel`, and compose the primitives in
`presentation/widgets/receipt_widgets.dart`: `DashedDivider`, `LeaderLine`,
`Stamp`, `ReceiptButton`, and `SectionHeader`. Keep corners at 4 px, borders at
1–2 px, touch targets at least 44 px, and use inversion—not another color—for
emphasis. Long merchant names must use a bounded line count and ellipsis.

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

Tap a subscription on Home or Subscriptions to inspect its latest 10 matching saved SMS messages, including sender, date, amount, and full original text. Manually entered items have no linked SMS; manually adjusted detected items keep their original merchant link and history. A rescan refreshes message history without overwriting manually adjusted subscription fields.

**Delete** removes the saved subscription; a later SMS scan can detect it again. **Not a subscription** removes the item and ignores the merchant in future scans. Settings → Ignored merchants lists these rules and lets you restore a merchant for the next scan. Neither action cancels a membership with the provider or deletes SMS from the phone.

Parser tests include more than 25 realistic examples covering banks, cards, UPI apps, merchant variants, decimal and comma-separated amounts, OTPs, credits, refunds, one-off purchases, promotions, and irregular recurrence.

## Notifications

`flutter_local_notifications` schedules two local reminders at 09:00 local time: three days and one day before renewal. Inexact idle-safe alarms avoid exact-alarm permission. Scheduled-notification receivers restore alarms after reboot or app replacement. A daily WorkManager task re-reads Drift and reconciles schedules while the app is closed. Editing, pausing, deleting, or importing subscriptions also immediately reschedules reminders.

Saving a subscription completes as soon as the database write succeeds. Reminder refresh runs separately, reports failures, and cannot leave the editor stuck loading. Turning renewal alerts off cancels scheduled reminders; background reconciliation respects the saved preference.

## Other local features

- Manual add, edit, pause, resume, and delete
- Ignored-merchant learning
- CSV export through Android's share sheet
- Dashboard monthly equivalent, yearly projection, upcoming renewals, and cost ranking
- Persistent currency selection (INR/USD/EUR/GBP) for new manual entries and dashboard totals. Existing transaction currencies remain unchanged; totals and rankings are filtered by currency with no exchange-rate conversion.
- Persistent haptic toggle respected by key interactions
- Editable India plan suggestions for Netflix, Amazon Prime, and Spotify, bundled offline with source links and a check date. Suggestions populate amount and billing cycle; the user can change either or enter any service manually.

Plan reference sources (checked 6 November 2026): [Netflix India](https://qr.netflix.com/in/title/80178726), [Amazon Prime India](https://www.aboutamazon.in/news/retail/how-to-sign-up-for-a-prime-membership), and [Spotify India](https://www.spotify.com/in-en/premium/). Promotions, student eligibility, and account-specific charges can differ; the actual bill takes precedence. These pages are not fetched by the app at runtime.

## Verify

```sh
flutter analyze
flutter test
flutter build apk --debug
```

SMS inbox behavior and notification delivery must be verified on a physical Android device because emulators and widget tests do not provide a real inbox or OEM background-power behavior.
