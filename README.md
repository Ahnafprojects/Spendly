# Spendly

Spendly is a Flutter personal finance app with Supabase backend support, offline-first data handling for core flows, and real-time language and currency preferences.

## Highlights

- Authentication with Supabase Auth (sign up, sign in, sign out)
- Dashboard with balance summary, income vs expense, quick actions, and recent transactions
- Transaction management: add, edit, delete, history, search, and date filter
- Analytics with charts and category breakdown
- Budget tracker by category with monthly usage monitoring
- Savings goals with progress tracking and deposit updates
- Settings for theme, language, currency, notifications, and data export
- Offline-first behavior for transactions and budgets

## Tech Stack

- Flutter and Dart
- Riverpod
- GoRouter
- Supabase Flutter
- Shared Preferences
- Intl and flutter_localizations
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
    transfer/
  shared/
    constants/
    models/
    services/
    widgets/
  main.dart
```

## Main Routes

- /splash
- /auth
- /dashboard
- /add-transaction
- /transactions
- /transfer
- /analytics
- /budget
- /settings

Routing config is defined in lib/core/router/app_router.dart.

## Getting Started

### Prerequisites

- Flutter SDK 3.x
- Dart SDK 3.x
- Android Studio or VS Code

### Install Dependencies

```bash
flutter pub get
```

### Run the App

```bash
flutter run
```

### Analyze

```bash
flutter analyze --fatal-infos --fatal-warnings
```

## Supabase Configuration

Supabase is initialized in lib/main.dart.

For production:

- move Supabase URL and anon key to secure runtime config
- use dart-define or CI secret injection

## Offline Behavior

- Transactions and budgets are cached locally
- Offline create and update operations are queued
- Pending operations sync to Supabase when network is available again
- Savings goals are stored locally with key savings_goals_v1

## Troubleshooting

### Missing SDK Constraint

If pubspec warns about lower-bound SDK, ensure:

```yaml
environment:
  sdk: "^3.10.0"
```

### Missing Localization Delegates

If DatePicker or localization fails, ensure MaterialApp has flutter_localizations delegates and supported locales.

### Android Storage Installation Error

If you see INSTALL_FAILED_INSUFFICIENT_STORAGE:

- free emulator/device storage
- uninstall old app build
- run flutter run again

## License

MIT
