# Feature Proposal & Scope: Family & Household Expense Tracker

> **Status:** Future Roadmap Proposal  
> **Document Purpose:** Preserved scope for collaborative household and family finance tracking.

---

## 1. Executive Summary

While **Personal Mode** solves individual tracking and **Split Mode** handles debt-settlement among friends or flatmates, **Family Mode** addresses collective household finance. In couples and families, financial management is cooperative: there are no debts to settle; instead, all members contribute to and draw from a shared household pool, requiring joint visibility and unified budget safeguards.

---

## 2. Core Comparison

| Dimension | Personal Mode | Split Mode | Family / Household Mode |
|---|---|---|---|
| **Audience** | Individual user | Friends, roommates, trips | Married couples, families, shared homes |
| **Mental Model** | "Where did my money go?" | "Who owes whom how much?" | "What is our collective household burn?" |
| **Settlement** | None | Balances & debt simplification | None (Shared pool & joint goals) |
| **Budgets** | Solo category limits | None | Combined household limits (e.g. ₹30k Groceries) |
| **Visibility** | Private to user | Group members only | All household members |

---

## 3. User Experience & Architecture: "Spaces / Household Switcher"

Instead of creating separate apps or disconnected screens, the recommended architecture uses a **Spaces** paradigm:

```text
┌──────────────────────────────────────────────────┐
│ [Logo] ExpenCircle  ▼ [ 👨‍👩‍👧 Satasiya Home ]    ⚙️│  <-- Top Bar Space Switcher
├──────────────────────────────────────────────────┤
│ 🏠 Monthly Household Outflow: ₹68,400            │
│ • Groceries: ₹22,000 (Priya: 14k, Manav: 8k)     │
│ • Utilities: ₹8,500 (Manav: 8.5k)                │
├──────────────────────────────────────────────────┤
│ Analytics: "Spend Contribution by Member"        │
│ 🟩 Manav (55%)   🟪 Priya (35%)   🟦 Other (10%) │
└──────────────────────────────────────────────────┘
```

### Key UI Capabilities:
1. **Header Space Switcher**: Dropdown in the top navigation bar to toggle between:
   - 👤 **Personal Space** (Private to the authenticated user).
   - 👨‍👩‍👧 **Family Space** (Shared with family members).
2. **Unified Dashboard & Analytics**:
   - In Family Space, Dashboard and Analytics aggregate transactions across all household members.
   - Transaction list items display member avatar chips (e.g., *"Added by Priya"*, *"Added by Manav"*).
3. **Contribution by Member**:
   - New analytics breakdown showing each member's funding percentage.
4. **Shared Category Budgets**:
   - Household-level category spending caps with overspend warning banners across devices.
5. **Invite System**:
   - Instant invitation via short invite link or 6-character code (`FAM-882X`).

---

## 4. Proposed Database Schema (Supabase)

```sql
-- 1. Households table
CREATE TABLE IF NOT EXISTS public.households (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    description TEXT,
    created_by UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    invite_code TEXT UNIQUE NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Household Members table
CREATE TABLE IF NOT EXISTS public.household_members (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    household_id UUID REFERENCES public.households(id) ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    display_name TEXT NOT NULL,
    role TEXT NOT NULL DEFAULT 'member', -- 'owner', 'admin', 'member'
    joined_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(household_id, user_id)
);

-- 3. Link expenses & budgets to household (Nullable: NULL = personal expense)
ALTER TABLE public.user_expenses ADD COLUMN IF NOT EXISTS household_id UUID REFERENCES public.households(id) ON DELETE CASCADE;
ALTER TABLE public.user_budgets ADD COLUMN IF NOT EXISTS household_id UUID REFERENCES public.households(id) ON DELETE CASCADE;
```

---

## 5. Phased Implementation Plan

- **Phase 1 (MVP)**:
  - Household creation, join via invite link/code.
  - Space switcher in top bar.
  - Combined expense list with member attribution badges.
- **Phase 2 (Analytics & Budgets)**:
  - Family-wide category budgets.
  - "Spending by Member" contribution charts.
- **Phase 3 (Privacy Controls)**:
  - Discretionary private items (e.g. gift purchases hidden or categorized as general without merchant details).
