# ExpenCircle — Master Knowledge Bank & Developer Reference

> **Authoritative Product Catalog, Architecture Guide, & Engineering Onboarding Manual**  
> **App Name:** ExpenCircle (`expense_tracker`) • **Version:** `1.0.3+4` (`AppConfig.appVersion`)  
> **Tech Stack:** Flutter (Dart `^3.7.0`) • Provider • SQLite (`sqflite`) • Supabase (PostgreSQL + Auth + Edge Functions) • Firebase Cloud Messaging (`firebase_messaging`) • Cloudflare R2 • Kotlin (Android Native)  
> **Platforms:** Android (`com.manav.expense.expense_tracker`), Web (PWA / Vercel), iOS (`ios/Runner`)  
> **Verification Baseline:** `flutter analyze --no-pub` (0 issues) • `flutter test --no-pub` (189 tests across 28 test suites)

---

## Table of Contents

1. [What Was Built — Complete Feature Catalog](#1-what-was-built--complete-feature-catalog)
2. [New Developer Quick-Start & Environment Setup](#2-new-developer-quick-start--environment-setup)
3. [System Architecture & State Management](#3-system-architecture--state-management)
4. [Feature Modules & Core Business Logic](#4-feature-modules--core-business-logic)
   - [4.1 Onboarding, Authentication & Session Lifecycle](#41-onboarding-authentication--session-lifecycle)
   - [4.2 Hybrid Storage Mode (Local SQLite vs Supabase Cloud)](#42-hybrid-storage-mode-local-sqlite-vs-supabase-cloud)
   - [4.3 Personal Income & Expense Tracking Engine](#43-personal-income--expense-tracking-engine)
   - [4.4 Home Dashboard & Spend Trajectory](#44-home-dashboard--spend-trajectory)
   - [4.5 Analytics & Financial Ledger](#45-analytics--financial-ledger)
   - [4.6 Category Budgets & Guardrail Alerts](#46-category-budgets--guardrail-alerts)
   - [4.7 Payment Reminders & Cycle Roll-Forward Engine](#47-payment-reminders--cycle-roll-forward-engine)
   - [4.8 Splitwise-Style Group Expense Engine & Combined Settlements](#48-splitwise-style-group-expense-engine--combined-settlements)
   - [4.9 Trip Mode (Direct Expense Routing)](#49-trip-mode-direct-expense-routing)
   - [4.10 48-Hour Ephemeral Trip Photo Vault](#410-48-hour-ephemeral-trip-photo-vault)
   - [4.11 On-Device Bank SMS Auto-Detection](#411-on-device-bank-sms-auto-detection)
   - [4.12 Push Notifications (FCM + Supabase Edge Function)](#412-push-notifications-fcm--supabase-edge-function)
   - [4.13 Media Pipeline (Cloudflare R2 & Pixabay)](#413-media-pipeline-cloudflare-r2--pixabay)
   - [4.14 Data Export (CSV, JSON & Google Sheets Sync)](#414-data-export-csv-json--google-sheets-sync)
5. [Native Android Architecture (Kotlin Modules & Platform Channels)](#5-native-android-architecture-kotlin-modules--platform-channels)
6. [iOS & Web Platform Specifics](#6-ios--web-platform-specifics)
7. [Database Architecture & Schemas](#7-database-architecture--schemas)
   - [7.1 Local SQLite Schema (`expenses.db`)](#71-local-sqlite-schema-expensesdb)
   - [7.2 Cloud PostgreSQL Schema (`supabase_schema.sql`)](#72-cloud-postgresql-schema-supabase_schemasql)
   - [7.3 Ephemeral Photo Vault Schema (`supabase_trip_photo_vault.sql`)](#73-ephemeral-photo-vault-schema-supabase_trip_photo_vaultsql)
   - [7.4 Row-Level Security (RLS) & Security Definer RPCs](#74-row-level-security-rls--security-definer-rpcs)
8. [Security, Error Handling & Store Compliance](#8-security-error-handling--store-compliance)
9. [Design System & Visual Tokens](#9-design-system--visual-tokens)
10. [Complete Codebase Directory Inventory](#10-complete-codebase-directory-inventory)
11. [Testing & Quality Assurance Guide](#11-testing--quality-assurance-guide)
12. [CI/CD, OTA Updates & Release Runbook](#12-cicd-ota-updates--release-runbook)

---

## 1. What Was Built — Complete Feature Catalog

This section serves as a permanent capability index of everything built in ExpenCircle:

| Domain | Key Capabilities Implemented | Primary Files |
|---|---|---|
| **Auth & Entry** | 3-step onboarding carousel, Email/Password sign-in & sign-up with 4-segment password strength meter, Native Mobile & Web Google Sign-In (`GoogleLogoIcon`), password reset, Terms/Privacy modals | `lib/screens/auth/*`, `lib/services/auth_service.dart`, `lib/main.dart` |
| **Hybrid Storage** | User-selectable Local-Only SQLite (`expenses.db`) or Supabase Cloud (`user_expenses`) personal ledger with 1-click Local→Cloud and Cloud→Local migration tools | `lib/services/storage_preference_service.dart`, `lib/widgets/storage_choice_dialog.dart`, `lib/services/database_service.dart` |
| **Personal Finance (Dual Flow)** | Expense (`debit`) & Income (`credit`) tracking, frequency-sorted expense categories, income categories, payment methods, customizable icons (`CategoryIcons`), receipt photo uploads (`CloudflareR2Service`) | `lib/models/expense.dart`, `lib/providers/expense_provider.dart`, `lib/widgets/add_expense_sheet.dart`, `lib/widgets/category_payment_manager_sheet.dart` |
| **Home Dashboard** | Clean time-of-day greeting row (`Nov 1 – Nov 30` date pill), Active Trip Mode quick-open banner, minimal Reminder Carousel Banner (`Mark Paid` & `Snooze`), Monthly Budget Snapshot, Category Donut Card, Cumulative Spend Trajectory Curve, Recent Verified Ledger | `lib/screens/dashboard_screen.dart`, `lib/widgets/reminder_carousel_banner.dart`, `lib/widgets/dashboard_shimmer.dart` |
| **Analytics & Search** | Timeframe presets (`This Month`, `Last Month`, `Last 30 Days`, `This Year`, `Custom`), 3 view modes (`List`, `Calendar` heatmap, `Chart` breakdown), separate Expense & Income breakdown accordions, tap-to-filter category chips, multi-facet `SearchScreen` & `SearchFilter` | `lib/screens/analytics_screen.dart`, `lib/screens/search_screen.dart`, `lib/models/search_filter.dart`, `lib/screens/category_detail_screen.dart` |
| **Budgets & Guardrails** | Category monthly spend ceilings, progress indicators (`80%` near-limit warning, `100%+` overspend alert), global persistent top `BudgetAlertBanner` across tabs | `lib/screens/budget_screen.dart`, `lib/providers/budget_provider.dart`, `lib/widgets/budget_alert_banner.dart`, `lib/widgets/set_budget_sheet.dart` |
| **Payment Reminders** | One-Time, Weekly, Monthly, Quarterly, Yearly, & Custom Interval bills; 1-tap `Mark Paid` (logs personal expense + optional split entry/settlement + rolls cycle forward); Dashboard carousel with `Snooze`; Day -1 & Day 0 alert tracking; app-bar notification badge | `lib/models/payment_reminder.dart`, `lib/providers/reminder_provider.dart`, `lib/screens/payment_reminders_screen.dart`, `lib/widgets/add_edit_reminder_sheet.dart` |
| **Split Engine (Splitwise)** | Cloud-synced shared groups, 8-char invite codes, QR modal & OS share sheet (`SharePlus`), Web URL deep linking (`?code=XYZ`), Equal/Unequal/Percentage splitting with remainder-cent allocation, Module A participant shortcuts (`SplitExpenseGroup`), Module B combined settlement groups (`SplitSettlementGroup`), Greedy Debt Simplification (`simplifyDebtsWithGroups`), Direct Pairwise Debts + DFS Cycle Elimination (`eliminateDebtCycles`), Draggable `SlideToPayTrack`, `SettlementCelebrationModal`, Custom cover banners (Pixabay + R2), Offline mutation queue (`split_sync_queue`) | `lib/screens/split/*`, `lib/models/split_models.dart`, `lib/providers/split_provider.dart`, `lib/services/split_service.dart` |
| **Trip Mode** | Activate an ongoing trip group so dashboard shows Trip Mode banner and `AddExpenseSheet` offers direct routing into that split group | `lib/providers/split_provider.dart`, `lib/screens/dashboard_screen.dart`, `lib/widgets/add_expense_sheet.dart` |
| **48h Trip Photo Vault** | Ephemeral trip photo album inside every split group (`split_group_photos`), R2 primary + Supabase Storage fallback, multi-photo upload, remaining TTL urgency tags, 100% private local likes (`SharedPreferences`), full-screen viewer, multi-photo download/save, owner-only deletion | `lib/models/trip_photo.dart`, `lib/providers/trip_photo_provider.dart`, `lib/services/trip_photo_service.dart`, `lib/services/trip_photo_local_likes_service.dart`, `lib/screens/split/trip_photo_vault_*` |
| **On-Device SMS Auto-Log** | Native Android `BroadcastReceiver` + Flutter `SmsParser` extracting Indian bank debit/credit alerts while filtering OTP/2FA & promos and avoiding available-balance collisions; interactive approval flow + `SmsTesterSheet` | `lib/services/sms_parser.dart`, `lib/services/transaction_detection_service.dart`, `android/.../SmsReceiver.kt`, `lib/widgets/sms_tester_sheet.dart` |
| **Android Native Extras** | Transparent lock-screen/quick `QuickAddActivity`, Quick Settings Tile (`QuickAddTileService`), Home-screen Glance AppWidget (`ExpenseWidgetProvider`), shared SQLite `DatabaseHelper` | `android/app/src/main/kotlin/com/manav/expense/expense_tracker/*.kt` |
| **Push Notifications** | FCM HTTP v1 settlement reminders via Supabase Edge Function (`send-settlement-reminder`), token registry (`user_device_tokens`), foreground Android notification channel, tap deep-link into group Settle tab | `lib/services/push_notification_service.dart`, `supabase/functions/send-settlement-reminder/index.ts`, `MainActivity.kt` |
| **Export & Portability** | OWASP CWE-1236 formula-injection-safe CSV export, structured JSON backup, cross-platform Web/IO file save/share, Google Apps Script webhook auto-sync & batch sync | `lib/services/data_export_service.dart`, `lib/services/google_sheets_service.dart`, `lib/widgets/export_data_sheet.dart`, `lib/widgets/google_sheets_sync_sheet.dart` |
| **Operations & CI/CD** | GitHub Actions Web deploy to Vercel on `main` push, Shorebird OTA configuration, store-compliant permission disclosures (`AppPermissionService`) | `.github/workflows/deploy.yml`, `vercel.json`, `shorebird.yaml`, `lib/services/app_permission_service.dart` |

---

## 2. New Developer Quick-Start & Environment Setup

### 2.1 Prerequisites
- **Flutter SDK:** Stable channel compatible with Dart `^3.7.0`
- **Android Studio / Android SDK:** NDK `27.0.12077973`, Java 11 (`JavaVersion.VERSION_11`)
- **Node.js & Deno / Supabase CLI** *(only needed if modifying or deploying Supabase Edge Functions)*
- **macOS + Xcode + Apple Developer Account** *(only required when building or configuring APNs push for iOS)*

### 2.2 Install Dependencies & Run Locally
```powershell
# 1. Install Dart/Flutter dependencies
flutter pub get

# 2. Verify code analysis and all 189 tests
flutter analyze --no-pub
flutter test --no-pub

# 3. Run on connected Android device/emulator
flutter run

# 4. Run on Chrome Web (SPA routing works with base href)
flutter run -d chrome
```

### 2.3 Environment & Secret Configuration
Compile-time config lives in `lib/core/config/app_config.dart` (read via `String.fromEnvironment`). Refer to `.env.example` for all supported `--dart-define` keys:

| Variable (`--dart-define`) | Purpose | Required For |
|---|---|---|
| `SUPABASE_URL` | Supabase project REST/Auth base URL | Cloud sync, Auth, Split, Photo Vault |
| `SUPABASE_ANON_KEY` | Supabase public publishable key | Client requests respecting RLS |
| `GOOGLE_WEB_CLIENT_ID` | OAuth 2.0 Web Client ID (also in `web/index.html` `<meta name="google-signin-client_id">`) | Web & Mobile ID-token Google Sign-In |
| `GOOGLE_ANDROID_CLIENT_ID` | Google Android OAuth Client ID | Android Google Sign-In |
| `GOOGLE_IOS_CLIENT_ID` | Google iOS OAuth Client ID | iOS Google Sign-In |
| `PIXABAY_API_KEY` | Pixabay image search key | Dynamic group banner search (`PixabayService`) |
| `R2_ACCOUNT_ID` | Cloudflare account ID | R2 S3-compatible endpoint |
| `R2_BUCKET_NAME` | Cloudflare R2 bucket name | Receipt, avatar & trip photo storage |
| `R2_ACCESS_KEY_ID` | R2 S3 access key ID | AWS SigV4 signed `PUT`/`DELETE` requests |
| `R2_SECRET_ACCESS_KEY` | R2 S3 secret key | HMAC-SHA256 SigV4 signing (keep secret!) |
| `R2_PUBLIC_BASE_URL` | Public CDN base URL (`https://pub-*.r2.dev`) | Public image URLs stored in DB |

Example parameterized run:
```bash
flutter run \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your_publishable_key \
  --dart-define=R2_ACCOUNT_ID=your_r2_account \
  --dart-define=R2_BUCKET_NAME=your_bucket \
  --dart-define=R2_ACCESS_KEY_ID=your_r2_key \
  --dart-define=R2_SECRET_ACCESS_KEY=your_r2_secret \
  --dart-define=R2_PUBLIC_BASE_URL=https://pub-your-cdn.r2.dev \
  --dart-define=PIXABAY_API_KEY=your_pixabay_key
```

### 2.4 Backend Setup Checklist (Fresh Project Clone)
1. **Supabase SQL Schema:** Run `supabase_schema.sql` first, then run `supabase_trip_photo_vault.sql` in Supabase Dashboard -> **SQL Editor**.
2. **Firebase Android Client:** Place your `google-services.json` (package `com.manav.expense.expense_tracker`) at `android/app/google-services.json` (used by `com.google.gms.google-services` in `android/app/build.gradle.kts`).
3. **Edge Function Deployment & Secret:**
   - Deploy `supabase/functions/send-settlement-reminder/index.ts`.
   - In Supabase Dashboard -> **Edge Functions -> Secrets**, add `FIREBASE_SERVICE_ACCOUNT_JSON` containing the full Firebase Service Account JSON (`project_id`, `client_email`, `private_key`).
4. **Google OAuth:** Enable Google provider in Supabase Auth, configure Web/Android/iOS client IDs, and ensure Android redirect intent filter (`io.supabase.expensetracker://login-callback`) matches.

---

## 3. System Architecture & State Management

ExpenCircle uses a **layered MVVM + Provider** architecture designed for offline resilience and platform abstraction (`Mobile` vs `Web`).

```
┌───────────────────────────────────────────────────────────────────────────┐
│                         PRESENTATION LAYER (SCREENS & WIDGETS)            │
│  AppRoot -> MainScreen (Home | Analytics | + | Split | Budgets)           │
│  DashboardScreen • AnalyticsScreen • SplitScreen • SplitGroupDetailScreen │
│  BudgetScreen • PaymentRemindersScreen • SearchScreen • SettingsScreen    │
└────────────────────────────────────┬──────────────────────────────────────┘
                                     │ context.watch / Provider / Consumer
                                     ▼
┌───────────────────────────────────────────────────────────────────────────┐
│                       STATE LAYER (5 ChangeNotifier Providers)            │
│  ExpenseProvider • BudgetProvider • SplitProvider                         │
│  ReminderProvider • TripPhotoProvider                                     │
└────────────────────────────────────┬──────────────────────────────────────┘
                                     │
                                     ▼
┌───────────────────────────────────────────────────────────────────────────┐
│                               SERVICE LAYER                               │
│  AuthService • DatabaseService • SplitService • PushNotificationService   │
│  CloudflareR2Service • PixabayService • GoogleSheetsService               │
│  DataExportService • StoragePreferenceService • SmsParser                 │
│  TransactionDetectionService • TripPhotoService • AppPermissionService    │
└───────────────────┬────────────────────────────────────┬──────────────────┘
                    │                                    │
                    ▼                                    ▼
   ┌─────────────────────────────────┐  ┌───────────────────────────────────┐
   │      LOCAL DATA SOURCES         │  │        CLOUD / EXTERNAL APIs      │
   │  • SQLite (`expenses.db`)       │  │  • Supabase Postgres + Auth + RLS │
   │  • SharedPreferences            │  │  • Supabase Edge Function (Deno)  │
   │  • Web in-memory fallback lists │  │  • Firebase Cloud Messaging (v1)  │
   │                                 │  │  • Cloudflare R2 (SigV4 S3 API)   │
   │                                 │  │  • Pixabay API & Google Sheets    │
   └─────────────────────────────────┘  └───────────────────────────────────┘
```

### 3.1 Bootstrap & Root Navigation (`lib/main.dart`)
On startup, `main()` initializes:
1. `WidgetsFlutterBinding.ensureInitialized()`
2. `CategoryIcons.init()` (loads persisted custom category icons from `SharedPreferences`)
3. `Supabase.initialize(url: AppConfig.supabaseUrl, publishableKey: AppConfig.supabaseAnonKey)`
4. `AuthService.instance.initUserCache()` (loads cached name/avatar into `ValueNotifier`s)
5. `PushNotificationService.instance.initialize(navigatorKey: appNavigatorKey)`
6. Web invite code capture: if `kIsWeb` and URL contains `?code=...`, saves `pending_invite_code` in `SharedPreferences` and marks onboarding completed.
7. Mounts `MultiProvider` registering `ExpenseProvider`, `BudgetProvider`, `SplitProvider`, `ReminderProvider..loadReminders()`, and `TripPhotoProvider`.

`_AppRootState` subscribes to `Supabase.instance.client.auth.onAuthStateChange` and resolves the root screen:
- Not completed onboarding (`!_hasSeenOnboarding`) -> `OnboardingScreen`
- Not authenticated and not guest (`!_isAuthenticatedOrGuest`) -> `LoginScreen`
- Otherwise -> `MainScreen(navigatorKey: appNavigatorKey)` (if authenticated, forces `StorageMode.cloud` and calls `PushNotificationService.instance.syncDeviceToken()`).

### 3.2 Providers Overview
| Provider | File | Core Responsibilities |
|---|---|---|
| `ExpenseProvider` | `lib/providers/expense_provider.dart` | Fast-path instant local SQLite read (<5ms) followed by cloud reconciliation; manages personal expenses & incomes, usage-sorted `categories`, `incomeCategories`, `paymentMethods`, stats & filters, Local<->Cloud sync triggers, Google Sheets auto-sync hook |
| `BudgetProvider` | `lib/providers/budget_provider.dart` | Monthly category spending caps (`Budget`), computes `BudgetProgress` (`spentThisMonth`, `remaining`, `percentage`, `isNearLimit` >=80%, `isOverspent`), drives `recentOverspendWarning` for `BudgetAlertBanner` |
| `SplitProvider` | `lib/providers/split_provider.dart` | Caches group lists per `user_id` (`split_group_ids_<uid>`), fetches members/expenses/settlements/shares/expense groups/settlement groups, computes net balances & debt lists (`simplifyDebts` toggle per group), tracks offline queue indicator (`hasPendingSync`), manages **Trip Mode** (`activeTripGroupId`), triggers `sendSettlementReminder` push notifications |
| `ReminderProvider` | `lib/providers/reminder_provider.dart` | Manages `PaymentReminder` lifecycle (`activeReminders`, `overdueReminders`, `dueTodayReminders`, `dashboardActionableReminders`, `completedReminders`, `pausedReminders`), normalized `totalMonthlyCommittedAmount`, 1-tap `markAsPaid` across personal + split ledgers, session banner dismissal persisted per date (`reminder_banner_dismissed_date`), and Day -1 / Day 0 notification rate limiting |
| `TripPhotoProvider` | `lib/providers/trip_photo_provider.dart` | Loads active unexpired photos (`expires_at > now`) and local private likes, supports filters (`all`, `liked`, contributor `uploaderId`), calculates storage metrics (`1.0 GB` default capacity gauge), bulk batch upload, owner-only deletion, and multi-photo liked downloads |

---

## 4. Feature Modules & Core Business Logic

### 4.1 Onboarding, Authentication & Session Lifecycle
- **`OnboardingScreen` (`lib/screens/auth/onboarding_screen.dart`):** 3-step swipeable intro highlighting ownership/offline storage, SMS capture, and group splitting with `screen/onboarding_*.png` illustrations. Completing or skipping saves `has_completed_onboarding_v1`.
- **`LoginScreen` (`lib/screens/auth/login_screen.dart`):** Clean, streamlined login with Email/Password (`AuthService.signInWithEmail`), Password Reset (`AuthService.resetPassword`), **"Continue with Google"** (`GoogleLogoIcon` + `AuthService.signInWithGoogle`), and Sign Up link to `RegisterScreen`.
  - *Note on Guest Mode:* `AuthService` still retains internal `isGuest()` / `setGuestMode()` helpers for offline state & backwards compatibility, while `LoginScreen` focuses on Email/Password and Google Sign-In.
- **Google Sign-In Flow (`AuthService.signInWithGoogle`):**
  - **Web:** Uses `Supabase.auth.signInWithOAuth(OAuthProvider.google, redirectTo: Uri.base.origin)` while preserving pending invite codes.
  - **Android / iOS:** Uses `google_sign_in` (`GoogleSignIn(serverClientId: _webClientId, clientId: ...)`), retrieves `idToken` + `accessToken`, signs into Supabase via `_client.auth.signInWithIdToken(...)`, caches display name/avatar, sets `StorageMode.cloud`, and syncs FCM token.
- **`RegisterScreen` (`lib/screens/auth/register_screen.dart`):** Validates Full Name, Email, Password, Confirm Password, renders a 4-segment strength meter, and requires legal checkbox acceptance with modal Privacy Policy & Terms (`LegalSheets`).
- **Sign Out (`AuthService.signOut`):**
  1. Removes current device's FCM token from `user_device_tokens` (`removeCurrentDeviceToken()`).
  2. Signs out of Supabase Auth & native `GoogleSignIn`.
  3. Clears cached profile `SharedPreferences` (`user_display_name_cached`, `user_photo_url_cached`).
  4. Wipes **only** local SQLite caches (`DatabaseService.clearLocalDatabaseOnly()` & `SplitService.clearLocalDatabaseOnly()`) so cloud rows remain intact while another user signing in on the same phone sees a clean slate.

### 4.2 Hybrid Storage Mode (Local SQLite vs Supabase Cloud)
Managed by `StoragePreferenceService` (`storage_mode_v1`, `storage_mode_has_chosen_v1`) and `StorageChoiceDialog`:
- **Local Mode (`StorageMode.local`):** Personal `expenses`, `budgets`, `categories`, `income_categories`, `payment_methods`, and `payment_reminders` live purely on-device in SQLite (`expenses.db`) or Web in-memory lists (`_webExpenses`, etc.).
- **Cloud Mode (`StorageMode.cloud`):** Personal expenses read/write from Supabase `user_expenses` filtered by `auth.uid()`, mirrored locally in SQLite so app launches stay instantaneous (`fetchExpenses` fast path).
- **Authenticated Default:** Signing in automatically enables `StorageMode.cloud`; users can inspect or switch personal storage mode in **Settings -> Personal Expense Storage** (`_StorageModeTile`), and perform 1-click Local->Cloud (`syncLocalToCloud()`) or Cloud->Local (`syncCloudToLocal()`) transfers.

### 4.3 Personal Income & Expense Tracking Engine
- **Unified `Expense` Model (`lib/models/expense.dart`):** Supports `TransactionType.expense` and `TransactionType.income` via the `type` column (`'expense'` / `'income'`). Safe deserialization handles `num`->`double` conversions (`(map['amount'] as num).toDouble()`) and missing timestamps.
- **Category & Payment Management (`CategoryPaymentManagerSheet` + `DatabaseService`):**
  - Separate default lists for Expense categories (`Food & Dining`, `Shopping`, `Transport`, `Bills & Utilities`, `Entertainment`, `Health & Wellness`, `Investment`, `General`) and Income categories (`Salary`, `Freelance`, `Investments`, `Refund / Cashback`, `Rental Income`, `Gifts`, `Other Income`), plus Payment Methods (`UPI`, `Card`, `Cash`, `Transfer`).
  - Usage-based ordering & Display-name formatting (`ExpenseProvider.formatDisplayName` preserves acronyms like `UPI` and `EMI`).
  - Custom icons mapped & persisted per category via `CategoryIcons` (`lib/utils/category_icons.dart`).
- **Add / Edit Flow (`AddExpenseSheet`):** Supports Expense/Income toggle, numeric amount input, searchable category & payment selectors (`SearchableSelectionSheet`), receipt attachment via `ReceiptAttachmentSheet` (uploads to Cloudflare R2; auto-deletes orphaned upload if save fails), and optional Trip Mode group routing.

### 4.4 Home Dashboard & Spend Trajectory
Built inside `DashboardScreen` (`lib/screens/dashboard_screen.dart`):
1. **Top App Bar (`MainScreen`):** Brand logo + `ExpenCircle PRO` badge (or active tab subtitle), Search shortcut (`SearchScreen`), Notification bell with live urgent-reminder badge (`notificationBadgeCount`), and interactive `UserProfileAvatar` (`SettingsScreen`).
2. **Active Trip Mode Banner (`_buildTripModeBanner`):** Shown when `SplitProvider.isTripModeActive` is true, offering instant navigation to the active group.
3. **Greeting Row (`_buildGreetingRow`):** Simple single-row header showing `Good morning` / `Good afternoon` / `Good evening` on the left (without user name) and the current-month date range pill (`Nov 1 – Nov 30`) on the right.
4. **Minimal Reminder Banner (`ReminderCarouselBanner`):** Auto-rotating (`4s`) swipeable white card with a `5px` left emerald accent bar (`#00B16A`), circular mint category icon, displaying **only** the reminder `title`, formatted `amount` (`₹...`), **`Mark Paid`** button, and **`Snooze`** button. Tapping the card opens `PaymentRemindersScreen`; **`Snooze`** calls `provider.dismissBannerForSession()` to snooze the banner for the current date.
5. **Monthly Budget Snapshot (`_buildBudgetSnapshotCard`):** Displays monthly spent vs total budgeted cap, utilization bar, and quick link to `BudgetScreen`.
6. **Category Donut & Spend Trajectory (`_buildCategoryDonutCard`, `_buildTrajectoryCard`):** `fl_chart` donut breakdown and smooth cumulative spend trajectory curve across month milestones.
7. **Recent Verified Ledger (`_buildVerifiedLedgerSection`):** Latest transactions with tap-to-edit support.

### 4.5 Analytics & Financial Ledger
Implemented in `AnalyticsScreen` (`lib/screens/analytics_screen.dart`):
- **Timeframe Controls:** Presets (`This Month`, `Last Month`, `Last 30 Days`, `This Year`, `Custom`), month/year picker (`_showMonthYearPicker`), and previous/next stepper controls. `DateRangePreset` end bounds carefully extend to `23:59:59.999` so same-day entries are never missed.
- **Pine-Tinted Period Summary Hero Card + Mini Bar Sparkline:** Summarizes total outflows, inflows, net flow, daily average, and transaction count.
- **3 View Switcher Modes (`_viewMode`):**
  1. **`list` (Ledger):** Live search input, quick category filter chips, active filter banner, and grouped chronological transaction timeline with category/merchant avatars.
  2. **`calendar` (Heatmap Calendar):** Monthly grid color-coded by daily outflow intensity + single-day drill-down ledger (`_buildSelectedDayOutflows`).
  3. **`chart` (Breakdown):** Collapsible category breakdown cards strictly separating **Expenses** (`_isExpenseBreakdownExpanded`) and **Income** (`_isIncomeBreakdownExpanded`).

### 4.6 Category Budgets & Guardrail Alerts
Implemented in `BudgetScreen`, `SetBudgetSheet`, `BudgetProvider`, and `BudgetAlertBanner`:
- Monthly spending cap per category (case-insensitive & whitespace-trimmed matching).
- Real-time utilization strictly considers `e.isExpense` within the current calendar month (incomes do not reduce spent amounts or trigger overspend warnings).
- **Guardrail States:**
  - `< 80%`: Safe (Pine Green)
  - `80% – 99.9%`: `isNearLimit` Caution
  - `>= 100%` (or spent > 0 when limit = 0): `isOverspent` Critical Alert; triggers persistent dismissible `BudgetAlertBanner` across `MainScreen`.

### 4.7 Payment Reminders & Cycle Roll-Forward Engine
Implemented in `PaymentReminder`, `ReminderProvider`, `PaymentRemindersScreen`, `AddEditReminderSheet`, and `ReminderCarouselBanner`:
- **Supported Frequencies (`ReminderFrequency`):** `oneTime` (`One-Time`), `weekly`, `monthly`, `quarterly`, `yearly`, and `customDays` (custom `N` days).
- **Smart Month-End Clamping:** `calculateNextCycleDate()` clamps `dueDay` (e.g. day `31`) to `DateTime(year, month + 1, 0).day` so February/30-day months never drift to wrong dates.
- **Calendar-Day Calculations (`daysUntilDue`):** Uses normalized `DateTime.utc(year, month, day)` dates so DST/time-of-day shifts never distort `Due Today`, `Due Tomorrow`, or `Overdue` status.
- **Monthly Committed Calculation (`totalMonthlyCommittedAmount`):** Normalizes Weekly (`amount * 4.33`), Quarterly (`amount / 3`), Yearly (`amount / 12`), Custom Days (`amount / days * 30`), and includes One-Time bills only when due in the current calendar month.
- **1-Tap "Mark as Paid" Flow (`ReminderProvider.markAsPaid`):**
  1. Auto-logs a personal `Expense` (`Auto-logged from reminder: <title>`) into `ExpenseProvider`.
  2. If `splitGroupId` is attached:
     - `ReminderSplitType.settlement`: records a group `Settlement` with `splitTargetMemberId`.
     - `ReminderSplitType.splitExpense`: splits the bill equally across current group members (assigning remainder cents to the last member) and creates a `SplitExpense`.
  3. Advances `nextDueDate` via `calculateNextCycleDate` and clears `notifiedDayBeforeAt` / `notifiedDueDayAt` for the next cycle (or sets `isCompleted = true` for `oneTime`).
- **Strict 2-Notification Rate Limiting (`checkAndTriggerDueAlerts`):** Guarantees at most **1 alert at Day -1** (`notifiedDayBeforeAt`) and **1 alert at Day 0+** (`notifiedDueDayAt`) per billing cycle.

### 4.8 Splitwise-Style Group Expense Engine & Combined Settlements
The collaborative Split module (`lib/screens/split/*`, `lib/models/split_models.dart`, `lib/services/split_service.dart`, `lib/providers/split_provider.dart`) is one of the deepest parts of the codebase:
- **Group Detail Architecture (`SplitGroupDetailScreen` + `SplitBottomNavBar`):**
  4 tabs plus centered elevated **`Add Expense`** button:
  - Tab `0`: **Expenses** (`SplitExpensesView`) — total spend card, Trip Mode toggle, itemized ledger, edit/delete/receipt preview.
  - Tab `1`: **Settle** (`SplitSettleView`) — CheQ-wallet-inspired balance overview, **Simplify Debts** toggle + explanation modal, Direct vs Simplified debt cards, **Remind** push notification trigger, draggable `SlideToPayTrack` 1-swipe settlement, and `SettlementCelebrationModal` confetti/celebration dialog.
  - Tab `2`: **Members** (`SplitMembersView`) — mint-washed top trip info card (`Created on <d MMM> • Active`), `Add Member`, `Group QR` invite modal, shareable invite link (`SharePlus.instance.share`), member search & filter (`All Members` vs `Combined`), inline member editing, Module A `Expense Member Groups`, and Module B `Combined Settlement Groups`.
  - Tab `3`: **Photos** (`TripPhotoVaultTab`) — 48-hour ephemeral trip album.
- **Split Algorithms & Financial Precision:**
  - **Remainder-Cent Safe Equal Split:** Divides in integer paise/cents and allocates any odd paisa to the final participant so shares always sum strictly to `totalAmount`.
  - **Module A (`SplitExpenseGroup`):** Reusable participant subsets (e.g., "Roommates", "Car #1") for fast expense entry.
  - **Module B (`SplitSettlementGroup`):** Virtual coupled entities (e.g., Couples / Families settling together via `sg_<id>` keys). A member can belong to at most one settlement group per split group (enforced client-side and in SQL via `UNIQUE(group_id, member_id)`).
  - **`simplifyDebts(balances)` / `simplifyDebtsWithGroups(...)`:** Greedy creditor-debtor matching in integer cents to minimize total transfers.
  - **`calculateDirectDebts(...)` / `calculateDirectDebtsWithGroups(...)`:** Preserves pairwise who-paid-for-whom relationships without routing through intermediaries, canceling internal debts inside the same settlement group.
  - **`eliminateDebtCycles(inputDebts)`:** Iteratively runs DFS over the directed debt graph and subtracts minimum edge flow along any cycle (`A -> B -> C -> A`), eliminating circular debts.
- **Offline Queue & Batching:** Offline inserts/updates enqueue into SQLite `split_sync_queue` and replay in order via `SplitService.syncPendingData()`. Cloud share loading avoids N+1 queries by invoking the `get_group_shares(p_group_id)` PostgreSQL RPC.

### 4.9 Trip Mode (Direct Expense Routing)
- Users can toggle **Trip Mode** on any active split group inside `SplitGroupDetailScreen` / `SplitExpensesView` (`SplitProvider.enableTripMode(groupId)` / `disableTripMode()`, persisted via `active_trip_mode_group_id`).
- While active, `DashboardScreen` surfaces a prominent emerald **Trip Mode** banner and `AddExpenseSheet` displays a toggle allowing new expenses to automatically route straight into that trip group's shared ledger.

### 4.10 48-Hour Ephemeral Trip Photo Vault
Implemented across `TripPhoto`, `TripPhotoProvider`, `TripPhotoService`, `TripPhotoLocalLikesService`, and `lib/screens/split/trip_photo_vault_*`:
- **Purpose:** Lets trip members drop raw trip photos into a shared group vault that automatically expires after **48 hours** (`expires_at = NOW() + 48h`).
- **Storage Hierarchy:** Uploads via `CloudflareR2Service.uploadBytes()` first (`vaults/{group_id}/{uploader_id}/{timestamp}_{uuid}.{ext}`), falling back to Supabase Storage bucket `trip-vault-photos` when R2 isn't configured, then performs a single bulk `INSERT` into `split_group_photos`.
- **100% Private Local Likes:** Likes are stored solely in `SharedPreferences` via `TripPhotoLocalLikesService` — zero server writes/table bloat and completely private to the user's phone, with a 1-click **"Download All Liked"** helper (`PhotoDownloadHelper` supporting both Web download and Mobile share/save).
- **Group Isolation & Ownership:** Enforced by RLS policies (`is_group_member(group_id)` for read/insert, `uploader_id = auth.uid()` for delete).

### 4.11 On-Device Bank SMS Auto-Detection
Implemented across `SmsParser` (`lib/services/sms_parser.dart`), `TransactionDetectionService` (`lib/services/transaction_detection_service.dart`), native `SmsReceiver.kt`, and `SmsTesterSheet`:
- **Privacy Design:** Raw SMS bodies are processed entirely on-device and discarded immediately — never stored in SQLite or sent over HTTP.
- **2-Stage Noise Filtering:**
  - Rejects OTP / 2FA alerts (`otp`, `verification code`, `security code`, `do not share`, `valid for`, etc.).
  - Rejects marketing/loan promos (`flat rs`, `cashback`, `off on`, `pre-approved`, `loan`, `coupon`, etc.).
- **Anti-Collision Amount Regex:** Prioritizes transaction verbs (`debited`, `credited`, `spent`, `paid`, `withdrawn`, etc.) and ignores amounts preceded by balance keywords (`bal`, `avl`, `available`, `limit`).
- **Store Policy Compliance:** Permissions are **never** requested on cold start; Flutter displays an in-app prominent disclosure (`AppPermissionService`) before requesting Android `RECEIVE_SMS` / `READ_SMS` permissions.

### 4.12 Push Notifications (FCM + Supabase Edge Function)
End-to-end free-tier push notifications (zero Blaze billing required) connecting Android FCM with Supabase:
1. **Token Registration (`PushNotificationService`):** Requests runtime notification permission (`POST_NOTIFICATIONS` on Android 13+), obtains the device's FCM registration token, listens to `onTokenRefresh`, and upserts `(user_id, fcm_token, platform)` into `public.user_device_tokens`. On sign-out, `removeCurrentDeviceToken()` deletes that token.
2. **Triggering Reminders (`SplitSettleView` -> `SplitProvider.sendSettlementReminder` -> `SplitService`):** Clicking **Remind** next to a debtor invokes Supabase Edge Function `send-settlement-reminder` (never copies reminder text to clipboard; returns typed status: `sent`, `noLinkedAccount`, `noDeviceTokens`, `notConfigured`, `failed`).
3. **Edge Function Execution (`supabase/functions/send-settlement-reminder/index.ts`):**
   - Verifies caller's Supabase JWT via `auth.getUser()`.
   - Confirms caller is a verified creator or member of `group_id`.
   - Reads `recipient_user_id`'s tokens from `user_device_tokens` using `SUPABASE_SERVICE_ROLE_KEY`.
   - Signs a short-lived RS256 JWT using `FIREBASE_SERVICE_ACCOUNT_JSON` (pure WebCrypto `crypto.subtle` — no heavy Firebase Admin SDK dependency), exchanges it at `oauth2.googleapis.com/token`, sends to **FCM HTTP v1** (`messages:send`) targeting Android channel `expencircle_push_reminders`, and prunes any `UNREGISTERED` / `NOT_FOUND` stale tokens.
4. **Foreground & Tap Handling:** When the app is foregrounded, `PushNotificationService._handleForegroundMessage` calls native Android `MethodChannel('com.manav.expense/push_notifications')` (`showForegroundNotification`) to display a heads-up system notification (falling back to a SnackBar elsewhere). Tapping the notification opens `SplitGroupDetailScreen` directly on the **Settle** tab (`initialTabIndex: 1`).

### 4.13 Media Pipeline (Cloudflare R2 & Pixabay)
- **`CloudflareR2Service` (`lib/services/cloudflare_r2_service.dart`):** Implements pure-Dart **AWS Signature Version 4 (HMAC-SHA256)** `PUT` uploads and `DELETE` cleanup against `https://<accountId>.r2.cloudflarestorage.com/<bucket>/<key>`, returning public CDN URLs (`AppConfig.r2PublicBaseUrl`). Used for receipts, profile avatars, custom group covers, and trip vault photos. Includes `deleteByUrl()` cleanup if saving the associated record fails.
- **`PixabayService` (`lib/services/pixabay_service.dart`):** Powers `GroupBannerPickerSheet` to search contextual group cover photos with curated local fallback visuals when offline or unconfigured.

### 4.14 Data Export (CSV, JSON & Google Sheets Sync)
- **`DataExportService` (`lib/services/data_export_service.dart`):** Generates CSV and pretty JSON exports containing `Expense` type (`Expense`/`Income`), date, time, category, signed amount, payment method, and note. CSV generation prevents **Formula Injection (OWASP CWE-1236)** by prefixing leading `=`, `+`, `-`, `@`, `\t`, `\r` characters with `'`. Uses conditional imports (`export_helper_web.dart` / `export_helper_io.dart`) for Web browser downloads and mobile share/save.
- **`GoogleSheetsService` (`lib/services/google_sheets_service.dart`):** Supports both live single-transaction `autoSync` (`syncExpenseIfEnabled`) and full batch export to a configurable Google Apps Script Web App webhook URL.

---

## 5. Native Android Architecture (Kotlin Modules & Platform Channels)

Application ID: `com.manav.expense.expense_tracker` (`android/app/build.gradle.kts`, `minSdk = 24` required by `firebase_messaging`, compile/targetSdk inherited from Flutter Gradle plugin, NDK `27.0.12077973`, Java 11, Google Services plugin enabled). `android/gradle.properties` sets `kotlin.incremental=false` to avoid Kotlin daemon cross-drive cache errors when the Pub cache resides on `C:` and the workspace on `D:`.

### Platform Channels (`MainActivity.kt`)
1. `com.manav.expense/widget`: `updateWidget` triggers `ExpenseWidgetProvider.sendUpdateBroadcast(context)`.
2. `com.manav.expense/permissions`: `hasSmsPermission` checks `RECEIVE_SMS` & `READ_SMS`; `requestSmsPermission` requests SMS + Android 13+ `POST_NOTIFICATIONS` on user action.
3. `com.manav.expense/transaction_detection`: Pushes `onTransactionDetected` payloads (`amount`, `category`, `paymentMethod`, `comment`, `type`, `isExpense`) from Kotlin to Flutter.
4. `com.manav.expense/push_notifications`: Creates notification channel `expencircle_push_reminders` (`IMPORTANCE_HIGH`) and displays foreground notifications via `showForegroundNotification`.

### Native Kotlin Components (`android/app/src/main/kotlin/com/manav/expense/expense_tracker/`)
| Class | Purpose |
|---|---|
| `MainActivity.kt` | Hosts `FlutterActivity`, manages all 4 MethodChannels and `expencircle_push_reminders` notification channel |
| `QuickAddActivity.kt` | Transparent modal activity (`Theme.TransparentDialog`, `showWhenLocked=true`) for rapid Expense/Income logging directly from home widget, Quick Settings tile, or app shortcuts |
| `QuickAddTileService.kt` | Android Quick Settings panel tile (`"Add Expense"`) launching `QuickAddActivity` |
| `ExpenseWidgetProvider.kt` | Home-screen Glance AppWidget (`R.layout.widget_expense`) reading today total, month total, and recent 2 transactions directly from SQLite `expenses.db` via `DatabaseHelper` |
| `SmsReceiver.kt` | Background `TELEPHONY.SMS_RECEIVED` `BroadcastReceiver` running Kotlin-side OTP/promo filtering, verb-priority amount extraction, debit/credit disambiguation, and launching transaction notifications |
| `DatabaseHelper.kt` | Native `SQLiteOpenHelper` (`expenses.db`, version `1`) matching Flutter's schema (`expenses`, `categories`, `income_categories`, `payment_methods`) so background widgets & Quick Add stay in sync |
| `NotificationDismissReceiver.kt` | Handles dismissal actions from native transaction notifications |

---

## 6. iOS & Web Platform Specifics

### 6.1 Web (`web/index.html`, `vercel.json`)
- **OAuth:** `<meta name="google-signin-client_id" ...>` in `web/index.html` enables Google Sign-In redirect flow.
- **Cache-Busting Service Worker Cleanup:** `web/index.html` includes an inline script unregistering stale service workers / clearing browser caches on load so SPA updates roll out immediately; `vercel.json` sets `Cache-Control: no-cache` on `/flutter_service_worker.js` and rewrites `/(.*)` to `/index.html`.
- **Web Fallbacks:** Because `sqflite` does not run on Web, `DatabaseService` uses `_webExpenses`, `_webCategories`, `_webIncomeCategories`, `_webPaymentMethods`, `_webBudgets`, and `_webReminders` (plus `Cloud` mode via Supabase), and file pick/download/export swap cleanly via conditional imports (`*_web.dart` vs `*_io.dart` / `*_stub.dart`).

### 6.2 iOS (`ios/Runner/Info.plist`)
- Camera and Photo Library usage descriptions (`NSCameraUsageDescription`, `NSPhotoLibraryUsageDescription`, `NSPhotoLibraryAddUsageDescription`) are configured for receipts, avatars, and Trip Photo Vault.
- On-device SMS detection (`SmsReceiver`) and Quick Settings Tile / Glance widget are **Android-only**; `PushNotificationService` guards platform checks cleanly (`TargetPlatform.android || TargetPlatform.iOS`).
- **Remaining iOS Requirements (if shipping iOS push notifications):** Because iOS requires Xcode + Apple Developer APNs setup (`.p8` APNs Auth Key uploaded to Firebase Cloud Messaging + `GoogleService-Info.plist` + Push Notifications capability & `aps-environment` in Xcode), building/configuring iOS push requires a **Mac / macOS runner**.

---

## 7. Database Architecture & Schemas

### 7.1 Local SQLite Schema (`expenses.db`)
Managed by `DatabaseService` (Flutter `sqflite`) and `DatabaseHelper` (Kotlin Android native), with runtime idempotent `ALTER TABLE` and `CREATE TABLE IF NOT EXISTS` migrations in `_ensureMetaTables`:

| Table | Purpose | Key Columns & Indexes |
|---|---|---|
| `expenses` | Personal expenses & incomes | `id` (PK), `user_id`, `amount`, `category`, `payment_method`, `comment`, `receipt_url`, `expense_date`, `created_at`, `updated_at`, `type` (`'expense'`/`'income'`). Indexes: `idx_expense_date`, `idx_category`, `idx_payment_method`, `idx_expense_type` |
| `categories` | Expense categories | `id` (PK), `name` (UNIQUE) |
| `income_categories` | Income categories | `id` (PK), `name` (UNIQUE) |
| `payment_methods` | Payment channels | `id` (PK), `name` (UNIQUE) |
| `budgets` | Monthly category caps | `id` (PK), `category` (UNIQUE), `monthly_limit`, `created_at`, `updated_at` |
| `payment_reminders` | Scheduled & one-time bills | `id` (PK), `user_id`, `title`, `amount`, `category`, `payment_method`, `frequency`, `custom_interval_days`, `due_day`, `due_date`, `next_due_date`, `last_paid_date`, `notified_day_before_at`, `notified_due_day_at`, `is_active`, `is_completed`, `split_group_id`, `split_type`, `split_target_member_id`, `notes`, `created_at`, `updated_at`. Indexes: `idx_reminders_dashboard`, `idx_reminders_split` |
| `split_groups` | Cached split groups | `id` (PK), `user_id`, `name`, `description`, `image_url`, `created_by`, `invite_code`, `created_at` |
| `split_members` | Cached group members | `id` (PK), `group_id`, `user_id`, `name`, `phone`, `joined_at` |
| `split_expenses` | Cached shared bills | `id` (PK), `group_id`, `title`, `total_amount`, `paid_by_member_id`, `split_type`, `category`, `note`, `receipt_url`, `added_by_member_id`, `created_at` |
| `split_shares` | Member bill shares | `id` (PK), `expense_id`, `member_id`, `share_amount`, `is_settled` |
| `settlements` | Group payments | `id` (PK), `group_id`, `from_member_id`, `to_member_id`, `amount`, `settled_at`, `note`, `from_settlement_group_id`, `to_settlement_group_id` |
| `split_expense_groups` | Module A subgroups | `id` (PK), `group_id`, `name`, `description`, `icon`, `created_by`, `created_at`, `updated_at` |
| `split_expense_group_members` | Module A mappings | `id` (PK), `expense_group_id`, `member_id`, `created_at`, `UNIQUE(expense_group_id, member_id)` |
| `split_settlement_groups` | Module B combined entities | `id` (PK), `group_id`, `name`, `created_by`, `created_at`, `updated_at` |
| `split_settlement_group_members` | Module B mappings | `id` (PK), `group_id`, `settlement_group_id`, `member_id`, `created_at`, `UNIQUE(settlement_group_id, member_id)`, `UNIQUE(group_id, member_id)` |
| `split_sync_queue` | Offline mutation log | `id` (PK), `action`, `table_name`, `record_id`, `payload`, `created_at` |

### 7.2 Cloud PostgreSQL Schema (`supabase_schema.sql`)
Contains **12 tables** with composite production indexes and RLS enabled on every table:
1. `public.split_groups`
2. `public.split_members`
3. `public.split_expenses`
4. `public.split_shares`
5. `public.settlements`
6. `public.split_expense_groups`
7. `public.split_expense_group_members`
8. `public.split_settlement_groups`
9. `public.split_settlement_group_members` (`UNIQUE(group_id, member_id)`)
10. `public.user_expenses` (with `type CHECK (type IN ('expense', 'income'))`)
11. `public.payment_reminders` (with partial index `idx_payment_reminders_active_due WHERE is_active = TRUE AND is_completed = FALSE`)
12. `public.user_device_tokens` (`UNIQUE(user_id, fcm_token)`, indexed on `user_id`)

### 7.3 Ephemeral Photo Vault Schema (`supabase_trip_photo_vault.sql`)
- Table: `public.split_group_photos` (`expires_at DEFAULT NOW() + INTERVAL '48 HOURS'`, indexed on `(group_id, created_at DESC)`, `expires_at`, `uploader_id`).
- Storage Bucket: `trip-vault-photos` (public read URLs, `50 MB` file limit, allowed MIME types `image/jpeg`, `image/png`, `image/webp`, `image/heic`).

### 7.4 Row-Level Security (RLS) & Security Definer RPCs
To enforce strict multi-tenant group isolation without recursive RLS deadlocks, `supabase_schema.sql` provides `SECURITY DEFINER` PostgreSQL functions (`SET search_path = public`):
- `is_group_member(p_group_id TEXT)` — Verifies `auth.uid()` against `split_members.user_id` or `split_groups.user_id` (with legacy claim fallback for pre-migration groups).
- `is_group_creator(p_group_id TEXT)` — Restricts creator-only deletes/updates.
- `is_expense_member(p_expense_id TEXT)` & `is_expense_group_member(p_expense_group_id TEXT)` — Transitive group membership checks.
- `get_group_by_invite_code(p_code TEXT)` — Looks up **only** the single group matching an exact invite code, blocking bulk group enumeration.
- `join_group_by_invite_code(p_code TEXT, p_name TEXT, p_phone TEXT)` — Atomically joins a group, claims matching unowned manual member records (`user_id IS NULL`), or inserts a linked member row (`user_id = auth.uid()`).
- `claim_user_groups(p_group_ids TEXT[])` — Safely claims unowned historical groups stored on the user's device.
- `get_group_shares(p_group_id TEXT)` — Batch-fetches all `split_shares` for a group in a single authenticated query.

Personal tables (`user_expenses`, `payment_reminders`, `user_device_tokens`) enforce strict `auth.uid() = user_id` RLS policies.

---

## 8. Security, Error Handling & Store Compliance

- **Zero Vendor Leak Policy (`lib/core/errors/error_handler.dart`):** `ErrorHandler.getUserMessage()` strips technical keywords (`supabase`, `pgrst`, `schema cache`, `cloudflare`, `r2`, `s3`, `pixabay`, `jwt`) before showing SnackBars or dialogs, returning clean user-friendly messages instead.
- **CSV Formula Injection Defense (OWASP CWE-1236):** `DataExportService._escapeCsv()` neutralizes spreadsheet formula execution (`=`, `+`, `-`, `@`, `\t`, `\r`).
- **Store Compliance (`lib/services/app_permission_service.dart` & `MainActivity.kt`):**
  - Never requests sensitive permissions (`RECEIVE_SMS`, `READ_SMS`, `CAMERA`, `PHOTOS`) on cold app launch.
  - Always presents clear in-app rationale bottom sheets before invoking OS prompts, plus Settings navigation links when permanently denied.
- **Secrets Hygiene:** `.gitignore` ignores `lib/config/api_keys.dart`, build artifacts, and local metadata. Production keys should be supplied via `--dart-define`, GitHub Actions Secrets, and Supabase Edge Function Secrets rather than hardcoded into docs or client files.

---

## 9. Design System & Visual Tokens

Centralized in `lib/core/theme/app_colors.dart` and `lib/core/theme/app_theme.dart` using Material 3 (`useMaterial3: true`) and **Plus Jakarta Sans** (`google_fonts`):

| Token (`AppColors.*`) | Hex Value | Usage |
|---|---|---|
| `primary` | `#006948` | Imperial Pine Green: primary CTAs, active tabs, positive ("You are owed") balances |
| `primaryDark` / `primaryDeep` | `#004D34` / `#003825` | Hero gradient headers, Trip Mode banner |
| `primaryContainer` | `#00855D` | Prominent accents, gradient highlights |
| `primaryLight` / `primaryFill` / `primaryBorder` | `#E8F5E9` / `#F0FDF4` / `#A7F3D0` | Soft mint icon badges, card surfaces, borders |
| `accentMint` / `onAccentMint` | `#85F8C4` / `#002114` | `PRO` badge, celebratory pills |
| `secondary` / `secondaryContainer` | `#4B41E1` / `#645EFB` | Electric Indigo: secondary chart/setting accents |
| `tertiary` / `tertiaryContainer` | `#008096` / `#00A2BE` | Ocean Teal: analytics metrics, calendar date accents |
| `background` | `#FAF8FF` | Soft tinted app canvas |
| `surface` / `surfaceSubtle` | `#FFFFFF` / `#F4F6F9` | Elevated cards (`20px` radius, `1px` `borderSubtle`), sheets |
| `textPrimary` / `textSecondary` / `textMuted` | `#131B2E` / `#3D4A42` / `#6D7A72` | Midnight Slate headings, neutral slate subtitles & timestamps |
| `warning` / `warningLight` | `#D97706` / `#FEF3C7` | Budget >= 80% warnings |
| `error` / `errorContainer` | `#BA1A1A` / `#FFDAD6` | Overspend alerts, destructive actions, debt indicators |

---

## 10. Complete Codebase Directory Inventory

```text
expence tracker/
├── .github/workflows/deploy.yml              # CI/CD: Flutter Web build & deploy to Vercel
├── .env.example                              # Template for --dart-define environment keys
├── analysis_options.yaml                     # Linter & analyzer exclusions (flutter_lints)
├── pubspec.yaml                              # App metadata (1.0.3+4), dependencies & asset bundles
├── shorebird.yaml                            # Shorebird OTA updater app_id configuration
├── supabase_schema.sql                       # PostgreSQL 12 tables, composite indexes, RPCs & RLS
├── supabase_trip_photo_vault.sql             # 48h ephemeral trip photo vault schema & storage bucket
├── vercel.json                               # SPA rewrites & service worker no-cache headers
├── supabase/functions/send-settlement-reminder/
│   └── index.ts                              # Deno Edge Function calling FCM HTTP v1 API
├── android/                                  # Android native config, FCM, Widget, QuickAdd & SMS
│   ├── settings.gradle.kts                   # Configures com.google.gms.google-services
│   └── app/
│       ├── build.gradle.kts                  # Package ID com.manav.expense.expense_tracker
│       ├── google-services.json              # Firebase Android app config (local/project)
│       └── src/main/
│           ├── AndroidManifest.xml           # Deep links, SMS receiver, QuickAdd, FCM channel
│           └── kotlin/com/manav/expense/expense_tracker/
│               ├── MainActivity.kt
│               ├── QuickAddActivity.kt
│               ├── QuickAddTileService.kt
│               ├── ExpenseWidgetProvider.kt
│               ├── SmsReceiver.kt
│               ├── DatabaseHelper.kt
│               └── NotificationDismissReceiver.kt
├── ios/Runner/Info.plist                     # Camera/Photo permission descriptions
├── web/index.html                            # Google Sign-In client ID meta & SW cache reset
├── lib/
│   ├── main.dart                             # App initialization, MultiProvider, AppRoot auth router
│   ├── config/                               # api_keys.example.dart (+ gitignored api_keys.dart)
│   ├── core/
│   │   ├── config/app_config.dart            # Central --dart-define environment reader
│   │   ├── constants/                        # app_assets.dart, app_constants.dart
│   │   ├── errors/                           # app_exception.dart, error_handler.dart
│   │   ├── network/                          # api_client.dart, api_response.dart
│   │   ├── theme/                            # app_colors.dart, app_theme.dart
│   │   ├── utils/                            # category_icons.dart, currency/date formatters, invite parser, validators
│   │   └── core.dart                         # Core barrel exports
│   ├── models/
│   │   ├── expense.dart                      # Expense + TransactionType
│   │   ├── budget.dart                       # Budget
│   │   ├── payment_reminder.dart             # PaymentReminder + frequency & cycle logic
│   │   ├── search_filter.dart                # ExpenseSortOption, DateRangePreset, SearchFilter
│   │   ├── split_models.dart                 # Split entities + debt & combined group algorithms
│   │   └── trip_photo.dart                   # Ephemeral 48h TripPhoto model
│   ├── providers/                            # 5 ChangeNotifier providers
│   ├── screens/
│   │   ├── main_screen.dart                  # 4-tab dock, center +, deep links, top bar & alerts
│   │   ├── dashboard_screen.dart             # Home dashboard
│   │   ├── analytics_screen.dart             # List / Calendar / Breakdown analytics
│   │   ├── budget_screen.dart                # Category budget manager
│   │   ├── history_screen.dart               # Full transaction list
│   │   ├── search_screen.dart                # Multi-filter search UI
│   │   ├── category_detail_screen.dart       # Per-category spend breakdown
│   │   ├── payment_reminders_screen.dart     # Upcoming / Completed / Paused bills manager
│   │   ├── settings_screen.dart              # Profile photo edit, storage switch, export, legal, logout
│   │   ├── auth/                             # onboarding_screen, login_screen, register_screen
│   │   └── split/                            # split_screen, create/join/settle/detail, views/, widgets/, photo vault
│   ├── services/                             # Data, Auth, Split, FCM Push, R2, Pixabay, SMS, Sheets, Export, Permissions
│   ├── utils/category_icons.dart             # Category icon persistence helper
│   └── widgets/                              # Bottom sheets, dialogs, banners, common UI kit
└── test/                                     # 28 automated test files (189 total tests)
```

---

## 11. Testing & Quality Assurance Guide

### Running Verification Commands
```powershell
# Static analyzer (must report 0 issues)
flutter analyze --no-pub

# Run full automated suite (currently 189 passing tests across 28 files)
flutter test --no-pub

# Run a targeted test file
flutter test --no-pub test/splitwise_test.dart
```

> **Note on Console Output During Widget Tests:** When instantiating `ExpenseProvider`, `BudgetProvider`, or `SplitProvider` in widget tests without initializing `sqflite_common_ffi` or `Supabase.initialize(...)`, caught debug logs (`Bad state: databaseFactory not initialized` / `You must initialize the supabase instance...`) print harmlessly to stdout while the tests run offline against seeded in-memory test state. Use `ExpenseProvider(autoFetch: false)` / `BudgetProvider(autoFetch: false)` or `set*ForTesting(...)` when adding new tests.

### Complete Test Suite Inventory (28 Files, 189 Tests)
| Test File | Coverage Focus |
|---|---|
| `all_bugfixes_regression_test.dart` | 24-bug audit regressions (`Expense.fromMap`, cent remainder distribution, negative shares, SMS balance/OTP/promo guards, case-insensitive budgets, `DateRangePreset`, CSV injection) |
| `analytics_screen_test.dart` | Analytics screen presets, calendar heatmap, ledger rendering, strict separation of Income vs Expense cards |
| `app_permission_service_test.dart` | Store-compliant permission request rationale flows |
| `auth_flow_test.dart` | `LoginScreen` fields, Google button, absence of guest/welcome copy, `RegisterScreen` strength meter & legal terms |
| `budget_provider_test.dart` | Monthly utilization percentage calculation, near-limit & overspend state |
| `budget_screen_test.dart` | Empty/populated budget UI, decimal % display, `BudgetAlertBanner` dismiss flow |
| `category_detail_and_sms_cancel_test.dart` | `ExpenseProvider` category helpers & SMS dialog cancellation |
| `category_sorting_and_icons_test.dart` | Frequency-based category sorting & `CategoryIcons` |
| `client_side_security_fixes_test.dart` | `ErrorHandler` sanitization & `InviteCodeParser` |
| `combined_settlement_test.dart` | Module B `SplitSettlementGroup` combined net balance & transfer algorithms |
| `dynamic_greeting_and_name_test.dart` | `AuthService.updateDisplayName` cache/notifier & nameless simple `DashboardScreen` greeting |
| `income_categories_test.dart` | Custom income category sync & local persistence |
| `notification_expense_and_instant_load_test.dart` | SMS notification expense injection & instant local load fast path |
| `payment_reminder_test.dart` | Cycle roll-forward (`calculateNextCycleDate`, leap/month-end clamping), UTC day math, normalized committed sum |
| `qa_edge_cases_and_calculation_breakdown_test.dart` | Edge-case financial rounding & multi-group breakdowns |
| `qa_math_and_calculations_stress_test.dart` | High-volume floating-point & debt-simplification stress checks |
| `reminder_flow_widget_test.dart` | Minimal `ReminderCarouselBanner` UI (title, amount, Mark Paid, Snooze), `PaymentRemindersScreen` tabs, `AddEditReminderSheet` |
| `search_filter_test.dart` | `SearchFilter` presets, amount/category/payment/type predicates & sorting |
| `settings_and_profile_test.dart` | Profile updates, avatar notifier & Settings tiles |
| `slide_to_pay_and_self_settlement_test.dart` | `SlideToPayTrack` gesture & self-settlement guards |
| `sms_parser_test.dart` | Multi-bank SMS debit/credit regex extraction & channel classification |
| `splitwise_test.dart` | Equal/Unequal/Percentage split math, `simplifyDebts`, `calculateDirectDebts`, `eliminateDebtCycles` |
| `split_members_and_settlement_regression_test.dart` | Split Members top trip card buttons (`Add Member`, `Group QR`, invite share), `Remind` button without clipboard side-effects |
| `trajectory_chart_test.dart` | Cumulative month spend curve computation |
| `transaction_type_and_credit_test.dart` | `TransactionType.expense` vs `TransactionType.income` segregation |
| `trip_mode_test.dart` | Active Trip Mode toggle, Dashboard banner & `AddExpenseSheet` group routing |
| `trip_photo_vault_test.dart` | `TripPhoto` TTL expiration, local private likes, contributor filtering & capacity calculations |
| `widget_test.dart` | Core smoke tests |

---

## 12. CI/CD, OTA Updates & Release Runbook

### 12.1 Web Deployment (`.github/workflows/deploy.yml` -> Vercel)
- Automatically triggers on every `push` to `main` (or manual `workflow_dispatch`).
- Generates `lib/config/api_keys.dart`, installs Flutter dependencies, compiles `flutter build web --release --base-href /` passing Cloudflare R2 `--dart-define`s, copies `vercel.json`, and deploys `./build/web` to production via Vercel CLI (`VERCEL_TOKEN`, `VERCEL_ORG_ID`, `VERCEL_PROJECT_ID`).

### 12.2 Android Release & In-Place Upgrade Safety
```powershell
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```
To preserve users' local SQLite `expenses.db` and `SharedPreferences` across updates (Android leaves `/data/data/com.manav.expense.expense_tracker/` untouched during updates):
1. Keep identical `applicationId` (`com.manav.expense.expense_tracker`).
2. Sign every release with the **exact same keystore certificate** (changing keystore causes `INSTALL_FAILED_UPDATE_INCOMPATIBLE`).
3. Increment `versionCode` in `pubspec.yaml` (`version: X.Y.Z+N` -> bump `+N`).

### 12.3 Shorebird OTA Updates (`shorebird.yaml`)
- Configured with `app_id: 54bbcf43-cb62-4ffe-808c-677820f47e3d` (auto-updates enabled on launch unless overridden).
- Enables shipping Dart-code patches to existing release builds without forcing a full store reinstall.

### 12.4 Edge Function & Push Updates
```powershell
# Re-deploy push notification function when modifying supabase/functions/send-settlement-reminder/index.ts
supabase functions deploy send-settlement-reminder
```
Ensure `FIREBASE_SERVICE_ACCOUNT_JSON` remains set in Supabase Edge Function Secrets.
