# ExpenCircle & Splitwise - Complete Application Specification

## 1. Executive Summary & Value Proposition
**ExpenCircle** is a next-generation personal finance and group splitting platform built on Flutter and powered by Supabase. It solves two critical pain points in modern expense management:
1. **Zero-Friction Logging**: Automated on-device SMS/Notification transaction capture.
2. **Hybrid Privacy Architecture**: Users have 100% control over their financial privacy. Personal expenses can be stored strictly **Locally (offline SQLite)** or synced to the **Supabase Cloud Database**. Group splitting expenses seamlessly leverage Supabase for real-time collaboration across web, iOS, and Android.

---

## 2. Core Pillars & Capabilities

### Pillar A: Hybrid Data Storage (Privacy First)
- **Local-Only Mode**: Personal financial transactions, budgets, custom categories, and payment methods remain exclusively on the user's physical device inside SQLite. No personal data ever leaves the device without explicit user consent.
- **Supabase Cloud Mode**: Secure cloud storage enabling cross-device sync, real-time backups, and unified authentication.
- **1-Click Two-Way Sync**: Ability to sync local records to the cloud or export cloud records back to device storage.
- **Group Splitting (Always Cloud Connected)**: Group ledgers (friends, trips, roommates) leverage Supabase real-time tables so all members stay in sync.

### Pillar B: Automated On-Device Expense Ingestion
- **Automated Bank SMS Parsing**: Detects incoming debit/credit SMS messages (UPI, NetBanking, ATM, Cards) from major banks (HDFC, SBI, ICICI, Axis, Kotak, etc.).
- **Smart Entity Extraction**: Parses exact transaction amount, merchant name, payment channel, and timestamp.
- **Auto-Categorization Engine**: Intelligent keyword heuristic matches merchants to categories (e.g., Swiggy/Zomato -> Food & Dining, Uber/Ola -> Transport).
- **Non-Intrusive Approval Flow**: Interactive bottom sheet/notification allowing users to approve, edit category, or discard detected transactions.

### Pillar C: Shared Group Splitting (Built-in Splitwise Alternative)
- **Zero-Friction Joining**: Shareable 8-character invite codes and direct deep links (`https://app.expensetracker.com?code=XYZ`).
- **Flexible Splitting Engine**:
  - **Equal Split**: Even division among all group members.
  - **Unequal Split**: Explicit exact amounts per member.
  - **Percentage Split**: Custom proportional split (e.g., 60% / 40%).
- **Multi-Payer Logging**: Any group member can record expenses on behalf of another member.
- **Debt Minimization & 1-Click Settlement**: Calculates real-time net balances ("Who Owes Whom") and logs settlement payments.

### Pillar D: Deep Financial Analytics & Budget Guardrails
- **Executive Period Summary**: Dynamic timeframe views (This Month, Last Month, Last 30 Days, This Year, and Custom Date Range).
- **Category Donut Breakdown**: Visual percentage distribution with tap-to-filter ledger capabilities.
- **Adaptive Trend Rhythm**: Responsive daily, weekly, or monthly bar charts with zero label overlapping.
- **Heatmap Daily Spending Calendar**: Interactive calendar highlighting high, medium, and low spend days with single-tap date ledger filtering.
- **Category-Specific Budget Thresholds**: Configurable budget limits with automated visual alerts (warning at 80%, critical alert at 100%).
- **Multi-Format Data Export**: Instant export to CSV, JSON, and Google Sheets sync.

---

## 3. Screen Inventory & User Journeys

### 1. Onboarding Flow (3 Distinct Steps)
- **Screen 1: Privacy & Storage Choice**
  - Highlights complete data ownership and offline-first security.
  - Educates users on choosing between offline local storage or encrypted Supabase cloud backup.
- **Screen 2: Automatic Expense Logging**
  - Demonstrates automated SMS and notification transaction ingestion with zero manual typing.
- **Screen 3: Shared Group Splitting**
  - Showcases bill splitting for roommates, dining, and vacations with debt settlement.

### 2. Authentication Flow
- **Login Screen**:
  - Email & Password sign-in.
  - "Continue with Google" OAuth one-tap login.
  - "Continue as Guest / Offline Only" bypass (lets users use the app immediately with no account requirement).
  - Forgot password password reset flow.
- **Register Screen**:
  - Name, Email, Password, Confirm Password.
  - Storage Mode selector (Local vs Cloud).
  - "Sign up with Google" one-tap registration.

### 3. Main Application Navigation
- **Tab 0: Dashboard**
  - Total Spend & Net Trajectory Chart (smooth milestone curve).
  - Quick Expense Ingestion Fab (`+`).
  - Storage Mode Status Badge (Local vs Supabase Cloud with 1-click sync indicator).
  - Category quick cards and recent transaction feed.
- **Tab 1: Expenses & Analytics (Option A)**
  - Dynamic Date Range selector (`This Month`, `Last Month`, `Last 30 Days`, `This Year`, `Custom Range 📅`).
  - Total Period Overview (Total spent, daily average, transaction count).
  - Category Donut breakdown with tap-to-filter logic.
  - Spending Trend Bar Chart (Daily / Weekly / Monthly adaptive views).
  - Preserved Heatmap Daily Calendar (heat-colored day cells, month stepper, tap-to-filter day ledger).
  - Searchable & Filterable Transactions Ledger with in-place edit/delete.
- **Tab 2: Split (Group Expenses)**
  - Active Groups overview with net balances ("You are owed ₹X" / "You owe ₹Y").
  - Create Group and Join via Invite Code / Deep Link.
  - Group Detail view: group ledger, member list, split type configuration, and Settle Up modal.
- **Tab 3: Budgets**
  - Overall monthly spend vs ceiling.
  - Category-by-category progress meters with overspend warning badges.
  - Set / Edit category budget dialog.
- **Tab 4: Settings & More**
  - Storage Mode Switcher (Local SQLite vs Supabase Cloud).
  - Google Sheets Cloud Sync sheet.
  - Category & Payment Method drag-and-drop order manager.
  - Data Export (CSV, JSON).
  - Account Profile & Logout.

---

## 4. Technical Architecture & Tech Stack

| Layer | Technology |
|---|---|
| **Frontend Framework** | Flutter (Dart SDK >= 3.0.0) |
| **State Management** | Provider (`ChangeNotifier`) |
| **Local Database** | SQLite via `sqflite` (Mobile) & In-Memory Fallback (Web) |
| **Backend / Cloud DB** | Supabase (PostgreSQL 17, Row Level Security, Auth) |
| **Charting Library** | `fl_chart` (Customized BarChart, PieChart, LineChart) |
| **SMS Ingestion** | `telephony` / Native Android Platform Channels |
| **Deep Linking** | Flutter Web URI fragment routing (`?code=...`) |
| **Formatting & Utilities** | `intl` (INR Indian Rupee localization), `uuid` |

---

## 5. Supabase Database Schema Overview

1. `split_groups`: `id`, `name`, `description`, `created_by`, `invite_code`, `created_at`
2. `split_members`: `id`, `group_id`, `name`, `phone`, `joined_at`
3. `split_expenses`: `id`, `group_id`, `title`, `total_amount`, `paid_by_member_id`, `split_type`, `category`, `note`, `added_by_member_id`, `created_at`
4. `split_shares`: `id`, `expense_id`, `member_id`, `share_amount`, `is_settled`
5. `settlements`: `id`, `group_id`, `from_member_id`, `to_member_id`, `amount`, `settled_at`, `note`
6. `user_expenses`: `id`, `user_id`, `amount`, `category`, `payment_method`, `comment`, `expense_date`, `created_at`, `updated_at`

---

## 6. Official Design System & Theme Color Palette

All screens and components strictly adhere to this fintech color palette:

| Token | Hex Code | Visual Role |
|---|---|---|
| **Primary (Imperial Pine Green)** | `#006948` | Primary CTA buttons, positive values, key brand accents, active states |
| **Primary Container** | `#00855D` | Hover states, prominent progress fills, headers |
| **Secondary (Electric Indigo)** | `#4B41E1` | Secondary actions, Splitwise icons, links, interactive toggles |
| **Secondary Accent** | `#645EFB` | Subtle card glows, badges, secondary button highlights |
| **Tertiary (Ocean Teal)** | `#008096` | Financial metric indicators, analytics charts, progress rings |
| **Scaffold Background** | `#FAF8FF` / `#F8F9FD` | Crisp, modern soft tinted canvas |
| **Surface (Card & Modal)** | `#FFFFFF` | Elevated cards, bottom sheets, form input fields |
| **Soft Chip / Pill Tint** | `#F2F3FF` | Inactive filter pills, input borders, unselected day cells |
| **Headline / Primary Text** | `#131B2E` | Deep Midnight Slate for bold headings and readable amounts |
| **Muted Text / Subtitles** | `#3D4A42` / `#6D7A72` | Secondary body text, timestamps, helper labels |
| **Alert / Negative Outflow** | `#F43F5E` | Budget overspend warnings, debt indicators, delete actions |
| **Warning / Caution** | `#F59E0B` | Budget 80% threshold warnings, pending settlements |
| **Typography** | `Plus Jakarta Sans` | Modern geometric sans-serif with high legibility |
