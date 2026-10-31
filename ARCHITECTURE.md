# ExpenCircle Architecture & Engineering Guide

## 1. System Overview & Principles

ExpenCircle is an offline-first, real-time personal expense manager and collaborative group bill-splitting application built on Flutter 3.29+ / Dart 3.7+.

The architecture adheres to Clean Architecture principles:
- **Separation of Concerns:** UI widgets represent declarative rendering state, delegating business rules, algorithms, and network operations to Providers and Services.
- **Offline-First Resilience:** All essential functionality (expense tracking, category management, budgets, and split debts) functions smoothly offline using SQLite. Mutations made while offline are queued in `split_sync_queue` and drained to Supabase upon reconnection.
- **Privacy & Security Invariant:** Cloud data isolation uses Supabase Row-Level Security (RLS) linked to `auth.uid()`. Third-party vendor identities (Supabase, Cloudflare R2, Pixabay) are sanitized by `ErrorHandler` and never leaked into user-facing UI messages.
- **Config Decoupling:** Credentials, endpoints, and OAuth client IDs are compiled via `--dart-define` using `AppConfig`, avoiding hardcoded secrets in version control.

---

## 2. Directory Structure

```text
lib/
├── core/
│   ├── config/
│   │   ├── app_config.dart          # Compile-time environment configuration via --dart-define
│   │   └── api_keys.dart            # Backwards-compatibility configuration bridge
│   ├── constants/
│   │   ├── app_constants.dart       # SharedPreferences keys, route constants, layout metrics
│   │   └── app_assets.dart          # Asset paths (logos, illustrations)
│   ├── errors/
│   │   ├── app_exception.dart       # Strongly typed exception hierarchy (Network, Api, Auth, etc.)
│   │   └── error_handler.dart       # Sanitizer preventing technical leaks in UI & structured logging
│   ├── network/
│   │   ├── api_client.dart          # Resilient HTTP client with timeouts & status mapping
│   │   └── api_response.dart        # Generic typed API response wrapper
│   ├── theme/
│   │   ├── app_colors.dart          # Central brand palette (Pine Green, Indigo, Ocean Teal)
│   │   └── app_theme.dart           # Material 3 ThemeData with typography and card styling
│   ├── utils/
│   │   ├── currency_formatter.dart  # Central INR currency & compact number formatting
│   │   ├── date_formatter.dart      # Relative and formatted date helpers
│   │   ├── validators.dart          # Email, password, positive amount form validators
│   │   ├── invite_code_parser.dart  # URL query, fragment, and path split invite code extractor
│   │   └── category_icons.dart      # Category icon mapping and persistence
│   └── core.dart                    # Barrel file for clean imports
├── models/
│   ├── expense.dart                 # Personal expense entity with JSON/SQLite serialization
│   ├── budget.dart                  # Category monthly spending threshold entity
│   ├── search_filter.dart           # Immutable filter & search criteria state
│   └── split_models.dart            # Group, Member, SplitExpense, Settlement, and Debt algorithms
├── providers/
│   ├── expense_provider.dart        # Personal expense state, ordering, category usage, and sync
│   ├── budget_provider.dart         # Budget thresholds, real-time overspend calculations & alerts
│   └── split_provider.dart          # Collaborative split groups, settlements, and member caching
├── services/
│   ├── auth_service.dart            # Supabase auth, Google In-App & Web OAuth, guest mode
│   ├── database_service.dart        # SQLite and Supabase data access layer
│   ├── split_service.dart           # Group collaboration, debt simplification, offline sync queue
│   ├── cloudflare_r2_service.dart   # AWS SigV4 image/receipt upload & deletion pipeline
│   ├── pixabay_service.dart         # Contextual group cover search with curated fallbacks
│   ├── google_sheets_service.dart   # Webhook background export to Google Sheets
│   ├── data_export_service.dart     # CSV/JSON formula-injection-safe export service
│   ├── storage_preference_service.dart # Local vs Cloud storage toggle
│   ├── transaction_detection_service.dart # Background SMS transaction detector
│   └── sms_parser.dart              # Multi-bank SMS regex & balance extraction engine
├── screens/
│   ├── main_screen.dart             # Shell layout with top app bar, bottom nav, and deep link router
│   ├── dashboard_screen.dart        # Monthly budget snapshot, donut charts, and recent activity
│   ├── analytics_screen.dart        # Interactive trends, burn rate, and date-filtered charts
│   ├── budget_screen.dart           # Budget management, progress bars, and safeguards
│   ├── history_screen.dart          # Transaction ledger and quick filtering
│   ├── search_screen.dart           # Multi-parameter faceted expense search
│   ├── category_detail_screen.dart  # Category deep dive and spending distribution
│   ├── settings_screen.dart         # User profile, Google Sheets sync, storage mode, and legal
│   ├── auth/                        # Onboarding, Login, and Registration flows
│   └── split/                       # Split groups, group details, add split expense, settlements
├── widgets/
│   ├── common/                      # Reusable modular UI components (AppCard, AppEmptyState, etc.)
│   ├── add_expense_sheet.dart       # Slide-up modal for recording personal spend with receipts
│   ├── budget_alert_banner.dart     # Actionable overspend alert banner
│   ├── receipt_attachment_sheet.dart# Bill receipt camera/upload modal
│   └── ...                          # Feature-specific dialogs, pickers, and sheets
└── main.dart                        # Application bootstrap, DI multi-provider, and root routes
```

---

## 3. Environment & Secrets Management

Environment configurations are managed through compile-time environment defines in `AppConfig` (`lib/core/config/app_config.dart`).

To compile or test with specific custom keys:
```bash
flutter run \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your_key \
  --dart-define=PIXABAY_API_KEY=your_pixabay_key \
  --dart-define=R2_ACCOUNT_ID=your_r2_id \
  --dart-define=R2_BUCKET_NAME=your_r2_bucket \
  --dart-define=R2_ACCESS_KEY_ID=your_r2_access_key \
  --dart-define=R2_SECRET_ACCESS_KEY=your_r2_secret \
  --dart-define=R2_PUBLIC_BASE_URL=https://your-cdn.r2.dev
```

In development, default values configured in `AppConfig` provide out-of-the-box operation.

---

## 4. State Management Architecture

State is managed using `Provider` with `ChangeNotifier`:
1. **`ExpenseProvider`**:
   - Manages personal expense records sorted by date descending.
   - Calculates real-time metrics: today spend, weekly spend, monthly spend, category totals.
   - Tracks category and payment method usage frequency to automatically sort user options.
   - Exposes `isLoading`, `errorMessage`, and error clearing helpers.
2. **`BudgetProvider`**:
   - Monitors monthly category thresholds against actual expenditures.
   - Computes `BudgetProgress` (spent, remaining, percentage, isOverspent, isNearLimit).
   - Generates and manages the recent overspend warning banner.
3. **`SplitProvider`**:
   - Manages collaborative split groups, group members, expenses, and settlements.
   - Enforces strict `user_id` mapped membership (`auth.uid()`) to eliminate duplicate user records.
   - Runs debt simplification via `simplifyDebts(balances)` to minimize transactions.
   - Handles offline pending sync indicator (`hasPendingSync`).

---

## 5. Data Persistence & Offline-First Strategy

1. **Local Mode:**
   - Expenses and budgets are stored locally in SQLite (`DatabaseService`).
2. **Cloud Mode:**
   - Synchronizes bidirectionally with Supabase PostgreSQL tables: `expenses`, `budgets`, `categories`, `payment_methods`.
3. **Split Collaboration:**
   - Shared groups use tables `split_groups`, `split_members`, `split_expenses`, `split_shares`, `split_settlements`.
   - SQLite table `split_sync_queue` records offline mutations and replays them automatically upon network reconnection.
   - Member lists fetched from the cloud purge stale local SQLite cache to ensure deleted members are not resurrected.

---

## 6. Cloudflare R2 Media & Receipt Pipeline

Receipts and group cover photos are stored in Cloudflare R2 object storage:
- Direct upload using AWS Signature Version 4 HMAC-SHA256 authenticated `PUT` requests (`CloudflareR2Service`).
- Returns public CDN URLs (`https://pub-*.r2.dev/...`).
- If an expense creation fails, uploaded receipt files are cleaned up via `deleteByUrl` to avoid orphaned objects.

---

## 7. Error Handling & Privacy

All uncaught exceptions and network failures are funneled through `ErrorHandler`:
- Maps socket errors and timeouts to user-friendly connectivity messages.
- Sanitizes error strings to prevent leaking database table names, SQL constraints, or third-party service names to users.
- Safely logs technical context to debug output without disclosing sensitive authorization headers or tokens.

---

## 8. Verification & Test Suite

The test suite consists of 71 unit and widget tests covering:
- **Regression Suite (`test/all_bugfixes_regression_test.dart`)**: Safe number parsing, exact cent split remainder distribution, strict negative share rejection, SMS balance extraction, and Excel injection safety.
- **Algorithm Suite (`test/splitwise_test.dart`, `test/combined_settlement_test.dart`)**: Circular debt simplification and multi-payer split calculations.
- **Provider Suites (`test/budget_provider_test.dart`, `test/category_sorting_and_icons_test.dart`)**: Real-time progress computation and usage-based reordering.
- **UI & Widget Suites (`test/widget_test.dart`, `test/analytics_screen_test.dart`, `test/budget_screen_test.dart`)**: Component rendering, date picker modals, and interaction flows.

Run the test suite:
```bash
flutter test
```
