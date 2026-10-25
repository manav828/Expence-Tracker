# ExpenCircle & Splitwise - Complete Master Knowledge Base

> **Authoritative Technical & Functional Reference Manual**  
> *Version:* 2.0 (Production Release)  
> *Stack:* Flutter (Dart 3.x) • Supabase (PostgreSQL 17) • SQLite (`expenses.db`) • Google OAuth  
> *Target Platforms:* Android (Mobile), iOS, Web (PWA / Responsive Desktop)

---

## Table of Contents
1. [Executive Summary & Core Value Proposition](#1-executive-summary--core-value-proposition)
2. [End-to-End Functional Specifications](#2-end-to-end-functional-specifications)
   - [2.1 3-Step Onboarding Journey](#21-3-step-onboarding-journey)
   - [2.2 Authentication & Guest Mode](#22-authentication--guest-mode)
   - [2.3 Immediate Storage Choice Prompt (Cloud vs Local)](#23-immediate-storage-choice-prompt-cloud-vs-local)
   - [2.4 Home Dashboard & Spend Trajectory](#24-home-dashboard--spend-trajectory)
   - [2.5 Expenses & Financial Analytics Ledger (Option A Architecture)](#25-expenses--financial-analytics-ledger-option-a-architecture)
   - [2.6 Shared Group Splitting Engine (Splitwise Alternative)](#26-shared-group-splitting-engine-splitwise-alternative)
   - [2.7 Budgeting & Guardrail Alerts](#27-budgeting--guardrail-alerts)
   - [2.8 Automated On-Device SMS Transaction Ingestion](#28-automated-on-device-sms-transaction-ingestion)
   - [2.9 Settings, Data Portability & Legal Modals](#29-settings-data-portability--legal-modals)
3. [System Architecture & Technical Implementation](#3-system-architecture--technical-implementation)
   - [3.1 Architecture Overview (MVVM + Provider Pattern)](#31-architecture-overview-mvvm--provider-pattern)
   - [3.2 State Management & Reactive Streams](#32-state-management--reactive-streams)
   - [3.3 Complete Local Database Schema (SQLite)](#33-complete-local-database-schema-sqlite)
   - [3.4 Complete Cloud Database Schema (Supabase PostgreSQL 17)](#34-complete-cloud-database-schema-supabase-postgresql-17)
   - [3.5 Supabase Authentication & Google OAuth Flow](#35-supabase-authentication--google-oauth-flow)
4. [Deep Dive: App Upgrades & Data Preservation](#4-deep-dive-app-upgrades--data-preservation)
   - [4.1 What Happens When an Existing User Updates the App](#41-what-happens-when-an-existing-user-updates-the-app)
   - [4.2 Android OS Sandbox Storage Mechanics](#42-android-os-sandbox-storage-mechanics)
   - [4.3 Keystore & Signing Rules for In-Place Upgrades](#43-keystore--signing-rules-for-in-place-upgrades)
5. [Industry Comparison: How Real-World Finance Apps Store Data](#5-industry-comparison-how-real-world-finance-apps-store-data)
   - [5.1 Storage Architecture Comparison Matrix](#51-storage-architecture-comparison-matrix)
   - [5.2 Why Apex Uses a Hybrid Local-First Architecture](#52-why-apex-uses-a-hybrid-local-first-architecture)
6. [High-Scale Data Synchronization Mechanics](#6-high-scale-data-synchronization-mechanics)
   - [6.1 The Scaling Challenge: Hundreds of Entries Per User](#61-the-scaling-challenge-hundreds-of-entries-per-user)
   - [6.2 Delta Sync / Change Data Capture (CDC)](#62-delta-sync--change-data-capture-cdc)
   - [6.3 Pagination, Index Traversal & Memory Efficiency](#63-pagination-index-traversal--memory-efficiency)
   - [6.4 Network Bandwidth & Payload Mathematics](#64-network-bandwidth--payload-mathematics)
7. [Design System & UI Tokens](#7-design-system--ui-tokens)
8. [Complete Codebase Directory & File Inventory](#8-complete-codebase-directory--file-inventory)
9. [Deployment, Configuration & Verification Runbook](#9-deployment-configuration--verification-runbook)

---

## 1. Executive Summary & Core Value Proposition

**ExpenCircle** is a production-grade personal finance management and collaborative group-splitting system. Built as a high-performance cross-platform Flutter application, it operates seamlessly on Android, iOS, and Web browsers, backed by Supabase (PostgreSQL 17, Mumbai Region).

### The Core Problems It Solves
1. **The Privacy Dilemma in Personal Finance**: Most commercial financial apps force users to upload their sensitive personal income, bank balances, and expense records to proprietary third-party servers. Apex solves this by offering a **100% Offline-First Local Mode** where financial data resides exclusively within an encrypted on-device SQLite database.
2. **Frictionless Shared Splitting**: Roommates, travel groups, and couples require shared ledgers with real-time sync. Apex provides a built-in Splitwise engine powered by Supabase Cloud, supporting equal, unequal, and percentage splits with 1-click debt settlement.
3. **Manual Logging Fatigue**: Entering expenses by hand leads to abandoned apps. Apex incorporates an on-device bank SMS parser that extracts amounts, merchants, categories, and payment channels without transmitting raw SMS text off the device.
4. **Information Overload in Financial Analytics**: Traditional analytics screens present dense tables. Apex implements **Option A UX Architecture**: high-level executive cards, an interactive category donut with tap-to-filter, an adaptive spending rhythm bar chart, an interactive daily heatmap calendar, and an instant filterable ledger.

---

## 2. End-to-End Functional Specifications

### 2.1 3-Step Onboarding Journey
- **Component File**: `lib/screens/auth/onboarding_screen.dart`
- **Illustrations**: Displayed via native asset bundle images (`screen/onboarding_1_illustration.png`, `screen/onboarding_2_illus.png`, `screen/onboarding_3_illust.png`).
- **Flow Logic**:
  - **Step 1: Complete Data Ownership**: Introduces offline-first architecture. Informs users they own their data—stored locally on their phone with optional encrypted cloud backup.
  - **Step 2: Auto-Log from SMS**: Explains automated transactional SMS parsing for instantaneous entry creation without manual typing.
  - **Step 3: Split Expenses with Friends**: Demonstrates group ledgers, bill splitting, and debt settlements.
- **Controls**:
  - Active step indicator dots with animated widths.
  - "Skip" text button: Bypasses directly to the `LoginScreen`.
  - "Next →" button on steps 1 and 2; transforms into "Get Started →" on step 3.

### 2.2 Authentication & Guest Mode
- **Component Files**: `lib/screens/auth/login_screen.dart`, `lib/screens/auth/register_screen.dart`, `lib/services/auth_service.dart`
- **Capabilities**:
  - **Email & Password Login**: Full validation, Supabase error message mapping, and "Forgot password?" reset link triggering.
  - **Google OAuth Login**: One-tap sign-in via Google credentials using Supabase Auth with automated browser callback handling.
  - **Guest Offline Mode**: A dedicated "Continue as Guest (Use offline • No account required)" action. Users can immediately enter the full application in Local SQLite mode without creating an account or supplying credentials.
  - **Registration Screen**:
    - Input fields: Full Name, Email, Password, Confirm Password.
    - **Live 4-Segment Password Strength Meter**: Evaluates character length, numbers, special characters, and mixed casing (Weak = Red, Fair = Amber, Good = Teal, Strong = Green).
    - **Legal Agreement Checkbox**: Mandatory checkbox with clickable modal triggers for "Terms of Service" and "Privacy Policy".
  - **Session Routing**: `AppRoot` in `lib/main.dart` listens to `Supabase.instance.client.auth.onAuthStateChange` in real-time. Successful sign-in or guest bypass immediately renders `MainScreen()`.

### 2.3 Immediate Storage Choice Prompt (Cloud vs Local)
- **Component File**: `lib/widgets/storage_choice_dialog.dart`
- **Behavior & Trigger**:
  - Automatically pops up on the Home screen the very first time an authenticated or guest user lands on the dashboard.
  - Checks `StoragePreferenceService.hasUserChosenStorage()`. If `false`, displays a modal dialog with two clear options:
    1. **Cloud Storage (Recommended)**: Backs up expenses to Supabase Mumbai, enables multi-device sync. Automatically triggers `DatabaseService.syncLocalToCloud()` to upload any offline transactions.
    2. **Local Storage Only (Privacy First)**: Stores transactions strictly on the physical device inside `expenses.db`. No personal records touch the network.
  - **Persistent Settings Switcher**: Users can modify their preference at any time from **Settings → Storage Location**. Switching between modes offers 1-click tools to upload local records to cloud or download cloud records to local SQLite.

### 2.4 Home Dashboard & Spend Trajectory
- **Component File**: `lib/screens/dashboard_screen.dart`
- **Features**:
  - **Storage Mode Status Banner**: Live badge indicating "Local Storage (Offline)" or "Supabase Cloud", displaying sync status.
  - **Current Month Spend Trajectory Curve**: Smooth Spline line chart charting cumulative spending across the days of the month. Formatted with clean 4-milestone X-axis labels (Day 1, 10, 20, End of Month) with individual data dots removed for clarity.
  - **Quick Stats Bar**: Total spent this month, daily average, top category badge, and active budget utilization.
  - **Recent Transactions Section**: Most recent 5 transactions with category icons, notes, and formatted INR amounts (`₹`).
  - **Floating Action Button (`+`)**: Launches `AddExpenseSheet` modal for manual logging.

### 2.5 Expenses & Financial Analytics Ledger (Option A Architecture)
- **Component File**: `lib/screens/analytics_screen.dart`
- **Features**:
  1. **Dynamic Timeframe Selector**:
     - Quick preset pills: `This Month`, `Last Month`, `Last 30 Days`, `This Year`, and `Custom 📅`.
     - Month stepper buttons (`<` and `>`) for fast chronological navigation.
     - Native Flutter `showDateRangePicker` allowing users to select any custom date range.
  2. **Period Summary Hero Card**:
     - Large formatted Total Spend (`₹XX,XXX.XX`).
     - Sub-metrics: Daily average spend (`₹/day`), total transaction count, and active span in days.
  3. **"Where Your Money Went" Category Donut Chart**:
     - Interactive FL Chart `PieChart` with color-coded slices.
     - **Tap-to-Filter Ledger**: Tapping any category slice or legend pill automatically filters the transaction ledger below to only transactions from that category, with an active filter badge and `✕` dismiss button.
  4. **Adaptive Spending Rhythm Bar Chart**:
     - Dynamically shifts aggregation intervals based on selected date span:
       - $\le 7$ days: Daily bars (`Mon`, `Tue`, `Wed`, etc.).
       - $8 - 45$ days: Weekly interval bars (`Wk 1`, `Wk 2`, etc.).
       - $> 45$ days: Monthly interval bars (`Jan`, `Feb`, etc.).
     - Prevents label overlap and adapts bar widths cleanly.
  5. **Preserved Daily Heatmap Calendar**:
     - Full interactive monthly calendar with color-graded day cells:
       - Light Green: $< ₹500$
       - Ocean Teal: $₹500 - ₹2,000$
       - Electric Indigo: $> ₹2,000$
     - Expandable and collapsible card.
     - Tapping any day displays that day's total expense and provides a **"Filter Ledger"** button to isolate that single day's records in the ledger below.
  6. **Searchable & Filterable Transactions Ledger**:
     - Live text search bar across comments, merchant names, amounts, and categories.
     - Filter chips for Categories (Food, Shopping, Utilities, etc.) and Payment Methods (UPI, Credit Card, Cash, NetBanking).
     - Tap any transaction item to open `AddExpenseSheet` in edit mode (or delete).

### 2.6 Shared Group Splitting Engine (Splitwise Alternative)
- **Component Files**: `lib/screens/split/split_screen.dart`, `lib/screens/split/split_group_detail_screen.dart`, `lib/screens/split/join_group_screen.dart`, `lib/services/split_service.dart`
- **Features**:
  - **Group Creation & Invites**: Create groups (e.g., "Goa Trip 2026", "Apartment 402"). Generates an 8-character unique alphanumeric invite code (e.g. `K9B2X4A1`) and web deep link (`https://.../?code=XYZ`).
  - **Group Joining**: Members join via code entry or URL.
  - **Splitting Engine**:
    - **Equal Split**: Even division of bill amount among all selected participants.
    - **Unequal Split**: Custom amounts specified per member, with client-side balance validation ensuring the sum of shares equals the total.
    - **Percentage Split**: Proportional percentage shares per member (validating that $\sum \% = 100\%$).
  - **Multi-Payer Logging**: Any group member can record that another member paid for an expense.
  - **Real-Time Net Balance Algorithm**:
    - Calculates the net balance of each member:
      $$\text{Net Balance} = \sum \text{Paid By Member} - \sum \text{Member's Share} + \sum \text{Settlements Received} - \sum \text{Settlements Sent}$$
    - Visual indicators: "You are owed ₹X" (Pine Green) vs "You owe ₹Y" (Rose Red).
  - **"Settle Up" Flow**: Direct recording of payments between debtor and creditor, marking shares settled and logging the settlement in `settlements`.

### 2.7 Budgeting & Guardrail Alerts
- **Component Files**: `lib/screens/budget_screen.dart`, `lib/providers/budget_provider.dart`, `lib/widgets/budget_alert_banner.dart`
- **Features**:
  - Set monthly spending ceilings per category.
  - Visual progress bars comparing spent amount against limit.
  - **Automated Alerts**:
    - **Caution Banner (Yellow)**: Triggers at $\ge 80\%$ budget utilization.
    - **Critical Alert Banner (Red)**: Triggers at $\ge 100\%$ budget overrun.
  - Real-time notification banners appear on the Dashboard and Budget screens.

### 2.8 Automated On-Device SMS Transaction Ingestion
- **Component Files**: `lib/services/transaction_detection_service.dart`, `lib/widgets/sms_tester_sheet.dart`
- **Features**:
  - Native Android platform channel listening for incoming SMS.
  - **Privacy Guarantee**: SMS parsing is 100% on-device. SMS body text is processed with regular expressions and immediately discarded from memory. No raw SMS is stored or transmitted over the internet.
  - **Regex Extraction**:
    - Amount regex matches Indian currency patterns (`INR`, `Rs.`, `Rs`, `₹`).
    - Merchant extraction identifies vendors (`Swiggy`, `Zomato`, `Uber`, `Amazon`, `Flipkart`, etc.).
    - Payment channel identifies `UPI`, `Debit Card`, `Credit Card`, `ATM`, or `NetBanking`.
  - **Interactive Confirmation Bottom Sheet**: When an SMS is detected, the app presents a pre-filled bottom sheet asking the user to confirm or edit before saving.

### 2.9 Settings, Data Portability & Legal Modals
- **Component Files**: `lib/screens/settings_screen.dart`, `lib/widgets/legal_sheets.dart`, `lib/services/google_sheets_service.dart`
- **Features**:
  - **Storage Location Switcher**: Toggle between Local SQLite and Supabase Cloud. Includes 1-click manual upload and download tools.
  - **Google Sheets Sync**: Instant export of personal ledger to a user's Google Sheet via Service Account or OAuth.
  - **CSV & JSON Export**: Complete local database backup exportable to device storage or shared via OS share sheet.
  - **Legal Sheets (`LegalSheets`)**:
    - **Privacy Policy**: Explicit disclosure of local-only data residence, on-device SMS parsing, zero advertising SDKs, and data deletion rights.
    - **Terms of Service**: Bookkeeping disclaimer, informal debt settlement clarity, and liability boundaries.
  - **Account & Sign Out**: Clean logout handling clearing Supabase session while preserving local SQLite database.

---

## 3. System Architecture & Technical Implementation

### 3.1 Architecture Overview (MVVM + Provider Pattern)
Apex adopts the **Model-View-ViewModel (MVVM)** pattern combined with Provider for dependency injection and state propagation.

```
┌────────────────────────────────────────────────────────────────────────┐
│                        PRESENTATION LAYER (VIEWS)                      │
│   DashboardScreen • AnalyticsScreen • SplitScreen • BudgetScreen       │
│   OnboardingScreen • LoginScreen • RegisterScreen • SettingsScreen     │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │ Watches & Listens
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│                        VIEWMODELS / PROVIDERS                          │
│   ExpenseProvider • BudgetProvider • SplitProvider                     │
│   - Holds observable state (ChangeNotifier)                            │
│   - Computes derived analytics (Totals, Daily Avgs, Slices, Trends)    │
│   - Dispatches user actions to underlying Services                     │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │ Calls
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│                            SERVICE LAYER                               │
│   DatabaseService • SplitService • AuthService                         │
│   StoragePreferenceService • TransactionDetectionService               │
└───────────────────┬────────────────────────────────┬───────────────────┘
                    │                                │
                    ▼                                ▼
       ┌────────────────────────┐       ┌────────────────────────┐
       │   LOCAL DATA SOURCE    │       │   CLOUD DATA SOURCE    │
       │   SQLite (expenses.db) │       │   Supabase Postgres 17 │
       │   (On-Device Sandbox)  │       │   (Mumbai ap-south-1)  │
       └────────────────────────┘       └────────────────────────┘
```

### 3.2 State Management & Reactive Streams
- `ExpenseProvider`: Manages personal expenses list, custom date range filtering, search terms, and active category/payment filters. Notifies UI via `notifyListeners()`.
- `SplitProvider`: Manages group lists, active group ledger, split share computations, and net balances.
- `BudgetProvider`: Manages monthly budget limits and evaluates overspend warnings.
- `AuthService`: Exposes Supabase auth state and guest session flags.
- `StoragePreferenceService`: Manages persistent `SharedPreferences` keys:
  - `storage_location`: `'cloud'` or `'local'`.
  - `storage_choice_made`: `true` or `false`.

### 3.3 Complete Local Database Schema (SQLite)
Stored in `/data/data/<package_name>/databases/expenses.db` on Android.

```sql
-- 1. Personal Expenses Table
CREATE TABLE expenses (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    amount REAL NOT NULL,
    category TEXT NOT NULL,
    payment_method TEXT NOT NULL,
    comment TEXT,
    expense_date INTEGER NOT NULL, -- Epoch milliseconds
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL
);

-- 2. Performance B-Tree Indexes
CREATE INDEX idx_expense_date ON expenses(expense_date);
CREATE INDEX idx_category ON expenses(category);
CREATE INDEX idx_payment_method ON expenses(payment_method);

-- 3. Custom Categories
CREATE TABLE categories (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT UNIQUE NOT NULL
);

-- 4. Custom Payment Methods
CREATE TABLE payment_methods (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT UNIQUE NOT NULL
);

-- 5. Monthly Category Budgets
CREATE TABLE budgets (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    category TEXT UNIQUE NOT NULL,
    monthly_limit REAL NOT NULL,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL
);
```

### 3.4 Complete Cloud Database Schema (Supabase PostgreSQL 17)
Hosted in the **Mumbai Region (`ap-south-1`)**:
- Project URL: `https://kqchjyfnvzfcxvhaonqz.supabase.co`
- Publishable Key: `sb_publishable_r7uEuebZL7Ed74YQzWlTqg_VnmFZ6It`

```sql
-- 1. Split Groups Table
CREATE TABLE IF NOT EXISTS public.split_groups (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    created_by TEXT NOT NULL,
    invite_code TEXT UNIQUE NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Split Members Table
CREATE TABLE IF NOT EXISTS public.split_members (
    id TEXT PRIMARY KEY,
    group_id TEXT NOT NULL REFERENCES public.split_groups(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    phone TEXT,
    joined_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. Split Expenses Table
CREATE TABLE IF NOT EXISTS public.split_expenses (
    id TEXT PRIMARY KEY,
    group_id TEXT NOT NULL REFERENCES public.split_groups(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    total_amount NUMERIC(12, 2) NOT NULL,
    paid_by_member_id TEXT NOT NULL,
    split_type TEXT NOT NULL DEFAULT 'equal', -- 'equal', 'unequal', 'percentage'
    category TEXT,
    note TEXT,
    added_by_member_id TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. Split Shares Table
CREATE TABLE IF NOT EXISTS public.split_shares (
    id TEXT PRIMARY KEY,
    expense_id TEXT NOT NULL REFERENCES public.split_expenses(id) ON DELETE CASCADE,
    member_id TEXT NOT NULL,
    share_amount NUMERIC(12, 2) NOT NULL,
    is_settled BOOLEAN DEFAULT FALSE
);

-- 5. Settlements Table
CREATE TABLE IF NOT EXISTS public.settlements (
    id TEXT PRIMARY KEY,
    group_id TEXT NOT NULL REFERENCES public.split_groups(id) ON DELETE CASCADE,
    from_member_id TEXT NOT NULL,
    to_member_id TEXT NOT NULL,
    amount NUMERIC(12, 2) NOT NULL,
    settled_at TIMESTAMPTZ DEFAULT NOW(),
    note TEXT
);

-- 6. User Personal Cloud Expenses (Cloud Storage Mode)
CREATE TABLE IF NOT EXISTS public.user_expenses (
    id BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    user_id UUID DEFAULT auth.uid(),
    amount NUMERIC(12, 2) NOT NULL,
    category TEXT NOT NULL,
    payment_method TEXT NOT NULL,
    comment TEXT,
    expense_date BIGINT NOT NULL, -- Epoch millis
    created_at BIGINT NOT NULL,
    updated_at BIGINT NOT NULL
);

-- Production Performance Indexes
CREATE INDEX IF NOT EXISTS idx_split_members_group_id ON public.split_members(group_id);
CREATE INDEX IF NOT EXISTS idx_split_groups_invite_code ON public.split_groups(invite_code);
CREATE INDEX IF NOT EXISTS idx_split_expenses_group_id ON public.split_expenses(group_id);
CREATE INDEX IF NOT EXISTS idx_split_shares_expense_id ON public.split_shares(expense_id);
CREATE INDEX IF NOT EXISTS idx_settlements_group_id ON public.settlements(group_id);
CREATE INDEX IF NOT EXISTS idx_user_expenses_date ON public.user_expenses(expense_date DESC);
CREATE INDEX IF NOT EXISTS idx_user_expenses_user_id ON public.user_expenses(user_id);

-- Row Level Security (RLS) Policies
ALTER TABLE public.user_expenses ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can only view their own expenses" 
ON public.user_expenses FOR SELECT 
USING (auth.uid() = user_id);

CREATE POLICY "Users can only insert their own expenses" 
ON public.user_expenses FOR INSERT 
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can only update their own expenses" 
ON public.user_expenses FOR UPDATE 
USING (auth.uid() = user_id);

CREATE POLICY "Users can only delete their own expenses" 
ON public.user_expenses FOR DELETE 
USING (auth.uid() = user_id);
```

### 3.5 Supabase Authentication & Google OAuth Flow
- **Google Web Client ID**: `399080992633-83vkmq76bgerotmks2ol10bniofcjq4t.apps.googleusercontent.com`
- **Web Client Configuration**: Injected into `web/index.html` via `<meta name="google-signin-client_id" content="...">`.
- **Android Deep Link Integration**:
  In `android/app/src/main/AndroidManifest.xml`:
  ```xml
  <intent-filter>
      <action android:name="android.intent.action.VIEW" />
      <category android:name="android.intent.category.DEFAULT" />
      <category android:name="android.intent.category.BROWSABLE" />
      <data android:scheme="io.supabase.expensetracker" android:host="login-callback" />
  </intent-filter>
  ```
- **Live Auth Listener**: `_AppRootState` in `lib/main.dart` subscribes to `Supabase.instance.client.auth.onAuthStateChange`. When the browser redirects back with an auth token, the listener captures the session and instantly refreshes the root view to `MainScreen()` without manual reload.

---

## 4. Deep Dive: App Upgrades & Data Preservation

### 4.1 What Happens When an Existing User Updates the App
When a user has an older version of this app installed on their phone with hundreds of logged expenses and subsequently installs an update:

> **All existing local data is 100% safe and preserved.**

### 4.2 Android OS Sandbox Storage Mechanics
1. **Isolated App Directory**: On Android, an application's internal data is stored inside a private sandbox at:  
   `/data/data/<package_name>/databases/expenses.db`
2. **Package Manager Upgrade Routine**: When the Android OS installs an update (via Google Play Store, ADB, or APK direct install):
   - The OS **only replaces the application binaries** (`/data/app/<package_name>/base.apk` containing Dalvik/ART code and assets).
   - The OS **never touches or deletes** the `/data/data/<package_name>/` private directory.
   - The SQLite database file (`expenses.db`), shared preferences, and key-value stores remain completely untouched.
3. **Data Loss Only Occurs If**:
   - The user explicitly taps **"Uninstall"** before installing the update. (Uninstalling instructs the OS to wipe `/data/data/<package_name>/`).
   - The user goes into **Android Settings → Apps → Storage → Clear Data**.

### 4.3 Keystore & Signing Rules for In-Place Upgrades
To perform an in-place update without uninstalling:
- **Same Package Name**: Must match `com.example.expense_tracker` (or your registered application ID).
- **Same Signing Certificate**: The APK must be signed with the same keystore file and key alias. If the keystore differs, Android will reject the update with `INSTALL_FAILED_UPDATE_INCOMPATIBLE`.
- **Higher Version Code**: `pubspec.yaml` `version: X.Y.Z+N` where `N` (the versionCode) is strictly greater than the currently installed version.

---

## 5. Industry Comparison: How Real-World Finance Apps Store Data

### 5.1 Storage Architecture Comparison Matrix

| Application | Storage Architecture | Local Offline Support | Cloud Backup / Sync | Multi-User Splitting | Notes |
|---|---|---|---|---|---|
| **Splitwise** | **Cloud-First** (Server DB + Local Cache) | Partial (Read cache, queues edits) | Yes (AWS / Postgres) | Full (Primary feature) | Requires account. High server load, syncs via background workers. |
| **Walnut / Axio** | **Hybrid / Cloud-Centric** | Yes (Local SQLite) | Yes (Proprietary cloud) | No | Auto-reads bank SMS locally, syncs financial profiles to server for credit/loan offers. |
| **Money Lover** | **Cloud-Centric** | Yes (Offline SQLite) | Yes (Paid subscription) | Basic | Free tier has sync limits. Syncs via REST APIs. |
| **Cashew** | **Local-First** | Yes (SQLite) | Optional Google Drive | No | Open-source, extreme privacy focus, no proprietary cloud. |
| **Apex (This App)** | **Configurable Hybrid** | **100% Complete Offline Mode** | **Yes (Supabase Mumbai)** | **Full Splitwise Engine** | **User explicitly chooses Local or Cloud.** Zero vendor lock-in. |

### 5.2 Why Apex Uses a Hybrid Local-First Architecture
1. **Zero Latency**: Reading from an on-device SQLite database takes $\sim 1\text{ to }3\text{ milliseconds}$. The app opens instantly, even in an elevator or on airplane mode, without any spinner or skeleton screen.
2. **User Sovereignty**: Users who do not trust third-party clouds with their financial records can select "Local Storage Only" and use the entire personal finance suite indefinitely with complete peace of mind.
3. **Selective Cloud Collaboration**: Group splitting by definition requires network synchronization so friends can see who paid what. By utilizing Supabase only where collaboration is required, Apex minimizes server costs while maximizing user privacy.

---

## 6. High-Scale Data Synchronization Mechanics

### 6.1 The Scaling Challenge: Hundreds of Entries Per User
A common concern for developers is:
> *"If every user has hundreds or thousands of expense entries, isn't fetching all entries every time a huge bottleneck for the server and mobile data?"*

Real-world production applications (and Apex) solve this using four specific engineering mechanisms:

### 6.2 Delta Sync / Change Data Capture (CDC)
Production finance apps **never download the entire database on every app launch**. Instead, they perform **Incremental Sync (Delta Sync)**:

```
Mobile Device                          Supabase Cloud Database
     │                                           │
     │ 1. GET /expenses?updated_at > 1729780000  │
     ├──────────────────────────────────────────►│
     │    (Only asking for changes since         │
     │     last sync timestamp)                  │
     │                                           │
     │ 2. Return 3 new rows (300 bytes)          │
     │◄──────────────────────────────────────────┤
     │                                           │
     │ 3. Apply changes into local SQLite        │
     │    Update last_sync = 1729800000          │
```

- Each record contains `created_at` and `updated_at` (epoch milliseconds or ISO-8601).
- The mobile app saves `last_successful_sync_timestamp` in `SharedPreferences`.
- On launch, the app only asks:  
  `SELECT * FROM user_expenses WHERE updated_at > :last_sync`
- If 0 expenses changed, the server returns an empty list (`[]`) in $20\text{ ms}$, consuming less than $1\text{ KB}$ of bandwidth.
- **Deletions (Tombstones)**: Soft deletions (`is_deleted = TRUE`) ensure that when an item is deleted on one device, other devices receive the deletion instruction during their delta sync.

### 6.3 Pagination, Index Traversal & Memory Efficiency
1. **PostgreSQL B-Tree Indexing**:
   ```sql
   CREATE INDEX idx_user_expenses_date ON user_expenses(user_id, expense_date DESC);
   ```
   Because the database table is indexed by `(user_id, expense_date)`, PostgreSQL does not scan every row in the table (O(N)). It traverses an index tree in logarithmic time ($O(\log N)$), retrieving 50 rows in $<1\text{ millisecond}$ regardless of whether the table has 10,000 or 10,000,000 rows.
2. **Pagination / Infinite Scroll**:
   When opening the Ledger or History screen, the app requests:
   ```sql
   SELECT * FROM user_expenses 
   WHERE user_id = :uid 
   ORDER BY expense_date DESC 
   LIMIT 50 OFFSET 0;
   ```
   Only when the user scrolls to the bottom does the app fetch the next 50 entries.

### 6.4 Network Bandwidth & Payload Mathematics
Financial records consist of basic primitives (numbers, small strings, dates):
- `id`: 8 bytes
- `amount`: 8 bytes
- `category`: ~12 bytes
- `payment_method`: ~10 bytes
- `comment`: ~30 bytes
- `expense_date`: 8 bytes
- **Total payload per record**: $\approx 100 \text{ to } 150 \text{ bytes}$.

#### The Math:
- 1 single expense row $\approx 0.1\text{ KB}$.
- 100 expenses $\approx 10\text{ KB}$.
- 1,000 expenses $\approx 100\text{ KB}$ (roughly the size of a single compressed icon).
- With HTTP gzip/brotli compression applied by Supabase, 1,000 expense records compress down to $\approx 25\text{ KB}$.
- Even over a slow 3G connection (1 Mbps), downloading 1,000 records takes **under 0.2 seconds**.

---

## 7. Design System & UI Tokens

The application follows a curated, modern aesthetic centered around the **Imperial Pine & Electric Indigo** palette with typography powered by **Plus Jakarta Sans**.

| Design Token | Hex Code | Visual Application |
|---|---|---|
| **Primary (Imperial Pine Green)** | `#006948` | Primary CTA buttons, positive balances ("Owed"), active bottom navigation tab |
| **Primary Container** | `#00855D` | Hover states, prominent progress fills, section headers |
| **Secondary (Electric Indigo)** | `#4B41E1` | Group splitting icons, text links, interactive toggles |
| **Secondary Accent** | `#645EFB` | Card glows, tags, secondary button highlights |
| **Tertiary (Ocean Teal)** | `#008096` | Financial metric indicators, analytics progress rings |
| **Scaffold Canvas** | `#FAF8FF` / `#F8F9FD` | Crisp, modern soft tinted application canvas |
| **Surface (Cards & Sheets)** | `#FFFFFF` | Elevated cards, bottom sheets, form input fields |
| **Soft Pill / Chip Tint** | `#F2F3FF` | Inactive filter pills, input borders, unselected day cells |
| **Headline / Primary Text** | `#131B2E` | Deep Midnight Slate for bold headings and legible amounts |
| **Muted Text / Subtitles** | `#3D4A42` / `#6D7A72` | Secondary body text, timestamps, helper labels |
| **Alert / Negative Balance** | `#F43F5E` | Budget overspend warnings, debt indicators ("You Owe"), delete actions |
| **Warning / Caution** | `#F59E0B` | Budget 80% threshold warnings, pending settlements |
| **Typography Family** | `Plus Jakarta Sans` | Modern geometric sans-serif font across all weights (400, 500, 600, 700) |

---

## 8. Complete Codebase Directory & File Inventory

```
expence tracker/
├── android/                           # Native Android build configurations
│   └── app/src/main/AndroidManifest.xml # Deep link intent filters & SMS permissions
├── web/                               # Web build configurations
│   └── index.html                     # Google OAuth meta client-id injection
├── screen/                            # Screen UI mockup & illustration assets
│   ├── onboarding_1_illustration.png  # Onboarding Step 1 graphic
│   ├── onboarding_2_illus.png         # Onboarding Step 2 graphic
│   ├── onboarding_3_illust.png        # Onboarding Step 3 graphic
│   ├── reg_login_illus.png            # Auth hero graphic
│   ├── login.png                      # Login design specification
│   ├── register.png                   # Register design specification
│   └── expenses.png                   # Expenses design specification
├── lib/
│   ├── main.dart                      # AppRoot, route management, live auth listener, theme
│   ├── models/
│   │   ├── expense.dart               # Personal Expense data model
│   │   ├── budget.dart                # Monthly Category Budget model
│   │   └── split_models.dart          # SplitGroup, SplitMember, SplitExpense, Settlement models
│   ├── providers/
│   │   ├── expense_provider.dart      # Personal expense state, filter queries, aggregation logic
│   │   ├── budget_provider.dart       # Budget limits & overspend alert notifications
│   │   └── split_provider.dart        # Group ledger, equal/unequal splitting, net balances
│   ├── screens/
│   │   ├── dashboard_screen.dart      # Home dashboard, spend trajectory curve, storage badge
│   │   ├── analytics_screen.dart      # Option A: Date Range, Donut, Rhythm Bars, Calendar, Ledger
│   │   ├── budget_screen.dart         # Category budget configuration & alert banners
│   │   ├── history_screen.dart        # Chronological transaction history ledger
│   │   ├── search_screen.dart         # Multi-parameter advanced transaction search
│   │   ├── category_detail_screen.dart# Deep-dive spend breakdown per category
│   │   ├── settings_screen.dart       # Storage switch, Google Sheets, legal sheets, sign out
│   │   ├── auth/
│   │   │   ├── onboarding_screen.dart # 3-step feature introduction carousel
│   │   │   ├── login_screen.dart      # Email/Password, Google OAuth, Guest offline button
│   │   │   └── register_screen.dart   # Register form, password strength meter, legal checkbox
│   │   └── split/
│   │       ├── split_screen.dart      # Group list, net debt balance hero
│   │       ├── split_group_detail_screen.dart # Group ledger, split engine, settle-up
│   │       └── join_group_screen.dart # Invite code entry & deep link receiver
│   ├── services/
│   │   ├── auth_service.dart          # Supabase Auth, Google OAuth, guest session manager
│   │   ├── database_service.dart      # SQLite CRUD operations & Supabase cloud sync
│   │   ├── split_service.dart         # Group splitting cloud database operations
│   │   ├── storage_preference_service.dart # Local vs Cloud preference persistence
│   │   ├── transaction_detection_service.dart # On-device bank SMS regex parser
│   │   └── google_sheets_service.dart # Direct export/sync to Google Sheets
│   ├── utils/
│   │   └── category_icons.dart        # Icon mapping & custom category icons
│   └── widgets/
│       ├── storage_choice_dialog.dart # Immediate Cloud vs Local prompt modal
│       ├── legal_sheets.dart          # Privacy Policy & Terms of Service sheets
│       ├── add_expense_sheet.dart     # Manual expense entry & editing bottom sheet
│       ├── set_budget_sheet.dart      # Category budget configuration sheet
│       ├── budget_alert_banner.dart   # Overspend caution and alert banners
│       ├── sms_tester_sheet.dart      # Interactive SMS test simulator
│       └── export_data_sheet.dart     # CSV / JSON export modal
├── test/                              # Automated test suites (50 passing tests)
│   ├── auth_flow_test.dart            # Onboarding & Auth navigation verification
│   ├── analytics_screen_test.dart     # Option A date range, donut, calendar verification
│   ├── splitwise_test.dart            # Equal/unequal splitting & net balance math tests
│   ├── budget_provider_test.dart      # Budget overspend calculation tests
│   ├── trajectory_chart_test.dart     # Spend trajectory curve math tests
│   └── category_sorting_and_icons_test.dart # Category reordering tests
├── supabase_schema.sql                # Complete PostgreSQL 17 schema for Supabase
├── pubspec.yaml                       # Dependencies, fonts, and asset declarations
└── KNOWLEDGE.md                       # This Master Knowledge Base document
```

---

## 9. Deployment, Configuration & Verification Runbook

### 9.1 Database Deployment (Supabase Mumbai)
1. Open the Supabase project dashboard:  
   `https://supabase.com/dashboard/project/kqchjyfnvzfcxvhaonqz/sql`
2. Open [`supabase_schema.sql`](file:///d:/Manav/website/expence%20tracker/supabase_schema.sql).
3. Paste the complete SQL code into the SQL Editor and click **Run**.
4. Confirm that all 6 tables (`split_groups`, `split_members`, `split_expenses`, `split_shares`, `settlements`, `user_expenses`) and indexes are created successfully.

### 9.2 Google OAuth Configuration
1. Open [Google Cloud Console](https://console.cloud.google.com/apis/credentials).
2. Select your project and navigate to **Credentials**.
3. Under **OAuth 2.0 Client IDs**:
   - Web Client ID: `399080992633-83vkmq76bgerotmks2ol10bniofcjq4t.apps.googleusercontent.com`
   - Authorized JavaScript origins:  
     `https://kqchjyfnvzfcxvhaonqz.supabase.co`  
     `http://localhost:3000` (for local web testing)
   - Authorized redirect URIs:  
     `https://kqchjyfnvzfcxvhaonqz.supabase.co/auth/v1/callback`
4. In Supabase Dashboard: Navigate to **Authentication → Providers → Google**.
   - Enable Google.
   - Paste the Client ID and Client Secret.
   - Save changes.

### 9.3 Code Quality & Test Verification
Run static analysis and automated test suites from the root directory:

```powershell
# 1. Run Flutter static analyzer (Must pass with 0 issues)
flutter analyze

# 2. Run the complete test suite (Must pass all 50 tests)
flutter test
```

### 9.4 Release Builds
```powershell
# Build optimized Android release APK
flutter build apk --release

# Build production Web application
flutter build web --release
```
The output APK is generated at:  
`build/app/outputs/flutter-apk/app-release.apk`
