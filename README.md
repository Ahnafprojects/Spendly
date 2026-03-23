# Spendly

A Flutter personal finance app for Indonesian users, with Supabase backend and offline-first behavior for core data.

## Current Status

- Platform: Flutter (Android/iOS)
- Backend: Supabase (Auth + Postgres)
- State management: Riverpod
- Routing: GoRouter
- Locale: Indonesian (`id_ID`) enabled
- Theme: Light/Dark mode available

## Core Features

- Authentication (register/login) with Supabase Auth
- Dashboard with:
  - total balance
  - income vs expense summary
  - recent transactions
  - quick actions
  - top savings goal summary card
- Transaction management:
  - add, edit, delete
  - detailed history page
  - search and date filter
  - amount formatting (`Rp 25.000` style)
- Analytics page (charts and spending insights)
- Budget tracker:
  - set monthly budget per category
  - usage tracking based on expense transactions
  - edit/delete budget entries
- Goals page (replaces old Transfer concept):
  - create savings goals
  - set target, current amount, optional deadline
  - add deposit, edit, delete goals
  - stored locally for fast access
- Settings:
  - theme mode
  - notification toggles
  - export data to CSV / JSON / PDF
  - clear local/user data

## Offline and Online Behavior

Spendly now supports offline-first for transaction and budget flows:

- Transactions and budgets are cached locally (`SharedPreferences`).
- Add/edit/delete while offline is allowed.
- Offline operations are queued as pending ops.
- When online again, pending ops are synced to Supabase automatically on fetch/refresh.

Note:
- Goals are local-first (`SharedPreferences`, key: `savings_goals_v1`).
- If a screen still depends on direct online fetch, ensure repository usage is wired to offline store.

## Tech Stack

- Flutter, Dart
- flutter_riverpod
- go_router
- supabase_flutter
- shared_preferences
- intl + flutter_localizations
- fl_chart
- flutter_local_notifications
- shimmer
- pdf

## Project Structure

```text
lib/
  core/
    router/
    theme/
  features/
    analytics/
    auth/
    budget/
    dashboard/
    settings/
    transaction/
    transfer/   # now used as Goals screen route
  shared/
    constants/
    models/
    services/
    widgets/
  main.dart
```

## Routes

Defined in `lib/core/router/app_router.dart`:

- `/splash`
- `/auth`
- `/dashboard`
- `/add-transaction`
- `/transactions`
- `/transfer` (Goals / Target Nabung)
- `/analytics`
- `/budget`
- `/settings`

## Getting Started

### 1. Prerequisites

- Flutter SDK (3.x)
- Dart SDK (3.x)
- Android Studio or VS Code

### 2. Install dependencies

```bash
flutter pub get
```

### 3. Run app

```bash
flutter run
```

## Supabase Configuration

Current project initializes Supabase directly in `lib/main.dart`.
For production, move URL and anon key to secure runtime config (`--dart-define` or env management) before release.

## Build Notes

If Android build reports desugaring requirement (from `flutter_local_notifications`), ensure `android/app/build.gradle` has core library desugaring enabled and proper dependency configured.

## Troubleshooting

- `pubspec.yaml has no lower-bound SDK constraint`
  - Ensure:
    ```yaml
    environment:
      sdk: '^3.10.0'
    ```

- `No MaterialLocalizations found` on DatePicker
  - Ensure `MaterialApp` includes `flutter_localizations` delegates and supported locales.

- `INSTALL_FAILED_INSUFFICIENT_STORAGE`
  - Free device/emulator storage, uninstall old app build, then run again.

## License

MIT
