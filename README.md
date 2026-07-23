# LifeHub

A native iOS personal life-management app — money, salary, rent, debts, loans, calendar, reminders, work tasks, and notes — built with SwiftUI, SwiftData, WidgetKit, ActivityKit, and App Intents. Single-user, offline-first, PIN-protected, no server.

Built from `LifeHub_Requirements.pdf` (v1.0). The requirements document specified a PWA in §2; per the project owner's instruction, this is the fully native iOS implementation instead (the "later phase" pulled forward). Everything else follows the document, including Phase 2 (budgets, charts, monthly review, Amharic, richer recurring rules) and the Phase 3 receipt-photos feature. Cloud sync and bank integration remain out of scope.

## Requirements

- macOS with **Xcode 26** or newer
- **iOS 26** device or simulator (deployment target; lower it in `project.yml` if needed — the code uses iOS 17-era APIs)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`

## Getting started

```bash
cd LifeHub
xcodegen generate      # produces LifeHub.xcodeproj
open LifeHub.xcodeproj
```

Then in Xcode:

1. Select the **LifeHub** target → Signing & Capabilities → choose your **Team** (or set `DEVELOPMENT_TEAM` in `project.yml`). Do the same for **LifeHubWidgets**.
2. If your team can't use the default bundle IDs, change `app.startupagile.lifehub` (and the widget/app-group IDs) consistently in `project.yml`, `Shared/AppGroup.swift`, and `LifeHub/Services/PINService.swift`, then re-run `xcodegen generate`.
3. Build & run on your iPhone.

First launch walks through choosing a 4–6 digit PIN and granting notification permission.

## Project layout

```
project.yml            XcodeGen manifest (app + widget extension, app group)
LifeHub/               App target
  App/                 Entry point, root tab view, app delegate
  Models/              SwiftData models (+ shared enums/value types)
  Views/               SwiftUI screens, grouped by feature
  Components/          Reusable UI (AmountText, StatCard, AgendaRow, …)
  Services/            Business logic: schedulers, notifications, backup,
                       PIN/Keychain, haptics, stats, Live Activities
  Intents/             App Intents + Siri Shortcuts
  Utilities/           Small extensions and helpers
  Resources/           Assets, string catalog (English + Amharic)
Shared/                Code compiled into both targets (app group, widget
                       snapshot, Live Activity attributes, money formatting)
Widgets/               Widget extension: Today, Money, Payday widgets +
                       the countdown Live Activity / Dynamic Island
```

## Architecture notes

- **MVVM-ish, SwiftData-native.** Views observe `@Model` objects directly (SwiftData models are observable view models in the modern stack); cross-cutting logic lives in stateless services (`StatsService`, `AgendaService`, `NotificationScheduler`, `BackupService`, `PaydayCalculator`, `BillScheduler`). No business logic in view bodies.
- **Reminders** are recomputed wholesale from the database on every change and capped under iOS's 64-pending-notification budget, nearest-first. Notification actions (Money Arrived / Mark Paid / Mark Done / Snooze) mutate the store without opening the app.
- **Widgets** read a precomputed `WidgetSnapshot` JSON from the app group — no database access in the extension, instant timelines.
- **Live Activity** counts down to the next payday / rent / loan installment, started from the relevant detail screen; confirming receipt flips it to a "done" state in the Dynamic Island.
- **Backup** is a single versioned JSON file (export/restore in Settings), covering every record including receipt photos.
- **Privacy:** all data on-device; PIN in the Keychain (never in the database); optional Face ID.

## Acceptance criteria mapping (MVP §8)

| Criterion | Where |
|---|---|
| Opens offline with a PIN | `LockView`, `PINService` (Keychain), no networking anywhere |
| Monthly salary + weekly side income, each with next payday + notification | `IncomeSource` schedules, `PaydayCalculator`, `NotificationScheduler` |
| Tenure at current company + past jobs with salary history | `IncomeSource.tenureDescription`, `SalaryChange`, detail view chart |
| Rent reminder 3 days before + mark paid history | `RecurringBill` (isRent, remindBeforeDays=3), `BillDetailView` |
| Debt partial repayment → correct remaining balance | `Debt.remaining`, `RepaymentSheet` |
| Expense in ≤3 taps, totals update immediately | Dashboard quick-add → `ExpenseFormView` (amount focused on open) |
| Export backup + restore on fresh install | Settings → `BackupService` |

## Known deviations / notes

- Widget-extension strings are English-only for now; the app itself localizes to Amharic (Settings → Language).
- "Native Android build" from Phase 3 doesn't apply to an iOS project.
- The app icon is a placeholder — drop a 1024×1024 PNG into `Assets.xcassets/AppIcon.appiconset`.
