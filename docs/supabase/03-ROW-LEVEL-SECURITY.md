# 03 - Row Level Security (RLS)

All tables have RLS enabled. Every query requires an authenticated user, and users can only access their own data. This document covers the complete RLS policy set for all 15 tables.

---

## Table of Contents

1. [Design Principles](#1-design-principles)
2. [Policy Categories](#2-policy-categories)
3. [Direct-Ownership Tables](#3-direct-ownership-tables)
4. [Parent-Ownership Tables](#4-parent-ownership-tables)
5. [Junction Tables](#5-junction-tables)
6. [Testing Queries](#6-testing-queries)
7. [Future Multi-User Expansion](#7-future-multi-user-expansion)

---

## 1. Design Principles

### Single-User Data Isolation

Swiss Coin is currently a **single-user app** -- each user has their own isolated dataset. The base RLS pattern is:

```
owner_id = auth.uid()
```

Every top-level table has an `owner_id` column referencing `auth.users(id)`. All CRUD operations filter on this column.

### Policy Naming Convention

```
<table>_<operation>_policy
```

Examples: `persons_select_policy`, `settlements_delete_policy`

### Key Rules

1. **Every table has RLS enabled** -- no exceptions
2. **All policies use `auth.uid()`** -- the built-in function returning the authenticated user's UUID
3. **Direct-ownership tables** check `owner_id = auth.uid()` directly
4. **Child tables** use `EXISTS` subqueries to verify ownership through the parent
5. **INSERT policies** set `owner_id` automatically via `WITH CHECK`
6. **DELETE policies** use soft delete (`deleted_at`) at the application level; the SQL DELETE policy exists as a safety net

---

## 2. Policy Categories

| Category | Tables | Pattern |
|----------|--------|---------|
| **Profile** (SELECT + UPDATE only) | `profiles` | `id = auth.uid()` |
| **Direct ownership** (full CRUD) | `persons`, `user_groups`, `financial_transactions`, `settlements`, `reminders`, `chat_messages`, `subscriptions` | `owner_id = auth.uid()` |
| **Parent ownership** (EXISTS subquery) | `transaction_splits`, `transaction_payers`, `subscription_payments`, `subscription_settlements`, `subscription_reminders` | Check parent's `owner_id` |
| **Junction tables** (EXISTS subquery) | `group_members`, `subscription_subscribers` | Check both parents' `owner_id` |

---

## 3. Direct-Ownership Tables

### 3.1 profiles

Special case: users can only read and update their own profile. No INSERT (handled by trigger) or DELETE.

```sql
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Users can read their own profile
CREATE POLICY profiles_select_policy ON public.profiles
  FOR SELECT
  USING (id = auth.uid());

-- Users can update their own profile
CREATE POLICY profiles_update_policy ON public.profiles
  FOR UPDATE
  USING (id = auth.uid())
  WITH CHECK (id = auth.uid());
```

### 3.2 persons

```sql
ALTER TABLE public.persons ENABLE ROW LEVEL SECURITY;

CREATE POLICY persons_select_policy ON public.persons
  FOR SELECT
  USING (owner_id = auth.uid());

CREATE POLICY persons_insert_policy ON public.persons
  FOR INSERT
  WITH CHECK (owner_id = auth.uid());

CREATE POLICY persons_update_policy ON public.persons
  FOR UPDATE
  USING (owner_id = auth.uid())
  WITH CHECK (owner_id = auth.uid());

CREATE POLICY persons_delete_policy ON public.persons
  FOR DELETE
  USING (owner_id = auth.uid());
```

### 3.3 user_groups

```sql
ALTER TABLE public.user_groups ENABLE ROW LEVEL SECURITY;

CREATE POLICY user_groups_select_policy ON public.user_groups
  FOR SELECT
  USING (owner_id = auth.uid());

CREATE POLICY user_groups_insert_policy ON public.user_groups
  FOR INSERT
  WITH CHECK (owner_id = auth.uid());

CREATE POLICY user_groups_update_policy ON public.user_groups
  FOR UPDATE
  USING (owner_id = auth.uid())
  WITH CHECK (owner_id = auth.uid());

CREATE POLICY user_groups_delete_policy ON public.user_groups
  FOR DELETE
  USING (owner_id = auth.uid());
```

### 3.4 financial_transactions

```sql
ALTER TABLE public.financial_transactions ENABLE ROW LEVEL SECURITY;

CREATE POLICY financial_transactions_select_policy ON public.financial_transactions
  FOR SELECT
  USING (owner_id = auth.uid());

CREATE POLICY financial_transactions_insert_policy ON public.financial_transactions
  FOR INSERT
  WITH CHECK (owner_id = auth.uid());

CREATE POLICY financial_transactions_update_policy ON public.financial_transactions
  FOR UPDATE
  USING (owner_id = auth.uid())
  WITH CHECK (owner_id = auth.uid());

CREATE POLICY financial_transactions_delete_policy ON public.financial_transactions
  FOR DELETE
  USING (owner_id = auth.uid());
```

### 3.5 settlements

```sql
ALTER TABLE public.settlements ENABLE ROW LEVEL SECURITY;

CREATE POLICY settlements_select_policy ON public.settlements
  FOR SELECT
  USING (owner_id = auth.uid());

CREATE POLICY settlements_insert_policy ON public.settlements
  FOR INSERT
  WITH CHECK (owner_id = auth.uid());

CREATE POLICY settlements_update_policy ON public.settlements
  FOR UPDATE
  USING (owner_id = auth.uid())
  WITH CHECK (owner_id = auth.uid());

CREATE POLICY settlements_delete_policy ON public.settlements
  FOR DELETE
  USING (owner_id = auth.uid());
```

### 3.6 reminders

```sql
ALTER TABLE public.reminders ENABLE ROW LEVEL SECURITY;

CREATE POLICY reminders_select_policy ON public.reminders
  FOR SELECT
  USING (owner_id = auth.uid());

CREATE POLICY reminders_insert_policy ON public.reminders
  FOR INSERT
  WITH CHECK (owner_id = auth.uid());

CREATE POLICY reminders_update_policy ON public.reminders
  FOR UPDATE
  USING (owner_id = auth.uid())
  WITH CHECK (owner_id = auth.uid());

CREATE POLICY reminders_delete_policy ON public.reminders
  FOR DELETE
  USING (owner_id = auth.uid());
```

### 3.7 chat_messages

```sql
ALTER TABLE public.chat_messages ENABLE ROW LEVEL SECURITY;

CREATE POLICY chat_messages_select_policy ON public.chat_messages
  FOR SELECT
  USING (owner_id = auth.uid());

CREATE POLICY chat_messages_insert_policy ON public.chat_messages
  FOR INSERT
  WITH CHECK (owner_id = auth.uid());

CREATE POLICY chat_messages_update_policy ON public.chat_messages
  FOR UPDATE
  USING (owner_id = auth.uid())
  WITH CHECK (owner_id = auth.uid());

CREATE POLICY chat_messages_delete_policy ON public.chat_messages
  FOR DELETE
  USING (owner_id = auth.uid());
```

### 3.8 subscriptions

```sql
ALTER TABLE public.subscriptions ENABLE ROW LEVEL SECURITY;

CREATE POLICY subscriptions_select_policy ON public.subscriptions
  FOR SELECT
  USING (owner_id = auth.uid());

CREATE POLICY subscriptions_insert_policy ON public.subscriptions
  FOR INSERT
  WITH CHECK (owner_id = auth.uid());

CREATE POLICY subscriptions_update_policy ON public.subscriptions
  FOR UPDATE
  USING (owner_id = auth.uid())
  WITH CHECK (owner_id = auth.uid());

CREATE POLICY subscriptions_delete_policy ON public.subscriptions
  FOR DELETE
  USING (owner_id = auth.uid());
```

---

## 4. Parent-Ownership Tables

These tables don't have their own `owner_id`. Access is verified by checking the parent table's `owner_id` via `EXISTS` subquery.

### 4.1 transaction_splits

Parent: `financial_transactions` (via `transaction_id`)

```sql
ALTER TABLE public.transaction_splits ENABLE ROW LEVEL SECURITY;

CREATE POLICY transaction_splits_select_policy ON public.transaction_splits
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.financial_transactions ft
      WHERE ft.id = transaction_splits.transaction_id
        AND ft.owner_id = auth.uid()
    )
  );

CREATE POLICY transaction_splits_insert_policy ON public.transaction_splits
  FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.financial_transactions ft
      WHERE ft.id = transaction_splits.transaction_id
        AND ft.owner_id = auth.uid()
    )
  );

CREATE POLICY transaction_splits_update_policy ON public.transaction_splits
  FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.financial_transactions ft
      WHERE ft.id = transaction_splits.transaction_id
        AND ft.owner_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.financial_transactions ft
      WHERE ft.id = transaction_splits.transaction_id
        AND ft.owner_id = auth.uid()
    )
  );

CREATE POLICY transaction_splits_delete_policy ON public.transaction_splits
  FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM public.financial_transactions ft
      WHERE ft.id = transaction_splits.transaction_id
        AND ft.owner_id = auth.uid()
    )
  );
```

### 4.2 transaction_payers

Parent: `financial_transactions` (via `transaction_id`)

```sql
ALTER TABLE public.transaction_payers ENABLE ROW LEVEL SECURITY;

CREATE POLICY transaction_payers_select_policy ON public.transaction_payers
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.financial_transactions ft
      WHERE ft.id = transaction_payers.transaction_id
        AND ft.owner_id = auth.uid()
    )
  );

CREATE POLICY transaction_payers_insert_policy ON public.transaction_payers
  FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.financial_transactions ft
      WHERE ft.id = transaction_payers.transaction_id
        AND ft.owner_id = auth.uid()
    )
  );

CREATE POLICY transaction_payers_update_policy ON public.transaction_payers
  FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.financial_transactions ft
      WHERE ft.id = transaction_payers.transaction_id
        AND ft.owner_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.financial_transactions ft
      WHERE ft.id = transaction_payers.transaction_id
        AND ft.owner_id = auth.uid()
    )
  );

CREATE POLICY transaction_payers_delete_policy ON public.transaction_payers
  FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM public.financial_transactions ft
      WHERE ft.id = transaction_payers.transaction_id
        AND ft.owner_id = auth.uid()
    )
  );
```

### 4.3 subscription_payments

Parent: `subscriptions` (via `subscription_id`)

```sql
ALTER TABLE public.subscription_payments ENABLE ROW LEVEL SECURITY;

CREATE POLICY subscription_payments_select_policy ON public.subscription_payments
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.subscriptions s
      WHERE s.id = subscription_payments.subscription_id
        AND s.owner_id = auth.uid()
    )
  );

CREATE POLICY subscription_payments_insert_policy ON public.subscription_payments
  FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.subscriptions s
      WHERE s.id = subscription_payments.subscription_id
        AND s.owner_id = auth.uid()
    )
  );

CREATE POLICY subscription_payments_update_policy ON public.subscription_payments
  FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.subscriptions s
      WHERE s.id = subscription_payments.subscription_id
        AND s.owner_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.subscriptions s
      WHERE s.id = subscription_payments.subscription_id
        AND s.owner_id = auth.uid()
    )
  );

CREATE POLICY subscription_payments_delete_policy ON public.subscription_payments
  FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM public.subscriptions s
      WHERE s.id = subscription_payments.subscription_id
        AND s.owner_id = auth.uid()
    )
  );
```

### 4.4 subscription_settlements

Parent: `subscriptions` (via `subscription_id`)

```sql
ALTER TABLE public.subscription_settlements ENABLE ROW LEVEL SECURITY;

CREATE POLICY subscription_settlements_select_policy ON public.subscription_settlements
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.subscriptions s
      WHERE s.id = subscription_settlements.subscription_id
        AND s.owner_id = auth.uid()
    )
  );

CREATE POLICY subscription_settlements_insert_policy ON public.subscription_settlements
  FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.subscriptions s
      WHERE s.id = subscription_settlements.subscription_id
        AND s.owner_id = auth.uid()
    )
  );

CREATE POLICY subscription_settlements_update_policy ON public.subscription_settlements
  FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.subscriptions s
      WHERE s.id = subscription_settlements.subscription_id
        AND s.owner_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.subscriptions s
      WHERE s.id = subscription_settlements.subscription_id
        AND s.owner_id = auth.uid()
    )
  );

CREATE POLICY subscription_settlements_delete_policy ON public.subscription_settlements
  FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM public.subscriptions s
      WHERE s.id = subscription_settlements.subscription_id
        AND s.owner_id = auth.uid()
    )
  );
```

### 4.5 subscription_reminders

Parent: `subscriptions` (via `subscription_id`)

```sql
ALTER TABLE public.subscription_reminders ENABLE ROW LEVEL SECURITY;

CREATE POLICY subscription_reminders_select_policy ON public.subscription_reminders
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.subscriptions s
      WHERE s.id = subscription_reminders.subscription_id
        AND s.owner_id = auth.uid()
    )
  );

CREATE POLICY subscription_reminders_insert_policy ON public.subscription_reminders
  FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.subscriptions s
      WHERE s.id = subscription_reminders.subscription_id
        AND s.owner_id = auth.uid()
    )
  );

CREATE POLICY subscription_reminders_update_policy ON public.subscription_reminders
  FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.subscriptions s
      WHERE s.id = subscription_reminders.subscription_id
        AND s.owner_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.subscriptions s
      WHERE s.id = subscription_reminders.subscription_id
        AND s.owner_id = auth.uid()
    )
  );

CREATE POLICY subscription_reminders_delete_policy ON public.subscription_reminders
  FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM public.subscriptions s
      WHERE s.id = subscription_reminders.subscription_id
        AND s.owner_id = auth.uid()
    )
  );
```

---

## 5. Junction Tables

Junction tables require checking ownership of BOTH parent records.

### 5.1 group_members

Parents: `user_groups` (via `group_id`) and `persons` (via `person_id`)

```sql
ALTER TABLE public.group_members ENABLE ROW LEVEL SECURITY;

CREATE POLICY group_members_select_policy ON public.group_members
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.user_groups g
      WHERE g.id = group_members.group_id
        AND g.owner_id = auth.uid()
    )
  );

CREATE POLICY group_members_insert_policy ON public.group_members
  FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.user_groups g
      WHERE g.id = group_members.group_id
        AND g.owner_id = auth.uid()
    )
    AND EXISTS (
      SELECT 1 FROM public.persons p
      WHERE p.id = group_members.person_id
        AND p.owner_id = auth.uid()
    )
  );

CREATE POLICY group_members_delete_policy ON public.group_members
  FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM public.user_groups g
      WHERE g.id = group_members.group_id
        AND g.owner_id = auth.uid()
    )
  );
```

> No UPDATE policy -- junction table rows are inserted or deleted, never updated.

### 5.2 subscription_subscribers

Parents: `subscriptions` (via `subscription_id`) and `persons` (via `person_id`)

```sql
ALTER TABLE public.subscription_subscribers ENABLE ROW LEVEL SECURITY;

CREATE POLICY subscription_subscribers_select_policy ON public.subscription_subscribers
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.subscriptions s
      WHERE s.id = subscription_subscribers.subscription_id
        AND s.owner_id = auth.uid()
    )
  );

CREATE POLICY subscription_subscribers_insert_policy ON public.subscription_subscribers
  FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.subscriptions s
      WHERE s.id = subscription_subscribers.subscription_id
        AND s.owner_id = auth.uid()
    )
    AND EXISTS (
      SELECT 1 FROM public.persons p
      WHERE p.id = subscription_subscribers.person_id
        AND p.owner_id = auth.uid()
    )
  );

CREATE POLICY subscription_subscribers_delete_policy ON public.subscription_subscribers
  FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM public.subscriptions s
      WHERE s.id = subscription_subscribers.subscription_id
        AND s.owner_id = auth.uid()
    )
  );
```

---

## 6. Testing Queries

### Verify RLS is Enabled

```sql
-- Check which tables have RLS enabled
SELECT tablename, rowsecurity
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY tablename;
```

All tables should show `rowsecurity = true`.

### Verify Policies Exist

```sql
-- List all RLS policies
SELECT
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual,
  with_check
FROM pg_policies
WHERE schemaname = 'public'
ORDER BY tablename, policyname;
```

### Test Data Isolation

To verify that User A cannot see User B's data:

```sql
-- As User A (authenticated via Supabase client)
-- Should return only User A's persons
SELECT * FROM public.persons;

-- Should return 0 rows (User A doesn't own User B's data)
SELECT * FROM public.persons WHERE owner_id = '<user-b-id>';

-- INSERT with wrong owner_id should fail
INSERT INTO public.persons (owner_id, name)
VALUES ('<user-b-id>', 'Hacker Attempt');
-- ERROR: new row violates row-level security policy
```

### Test Parent-Ownership Policies

```sql
-- Create a transaction owned by current user
INSERT INTO public.financial_transactions (owner_id, title, amount, date)
VALUES (auth.uid(), 'Test', 100.00, NOW())
RETURNING id;

-- Add a split to that transaction (should succeed)
INSERT INTO public.transaction_splits (transaction_id, owed_by_id, amount)
VALUES ('<transaction-id>', '<person-id>', 50.00);

-- Try adding a split to another user's transaction (should fail)
INSERT INTO public.transaction_splits (transaction_id, owed_by_id, amount)
VALUES ('<other-users-transaction-id>', '<person-id>', 50.00);
-- ERROR: new row violates row-level security policy
```

### Test Junction Table Policies

```sql
-- Adding a member to your own group (should succeed)
INSERT INTO public.group_members (group_id, person_id)
VALUES ('<your-group-id>', '<your-person-id>');

-- Adding someone else's person to your group (should fail)
INSERT INTO public.group_members (group_id, person_id)
VALUES ('<your-group-id>', '<other-users-person-id>');
-- ERROR: new row violates row-level security policy
```

---

## 7. Future Multi-User Expansion

The current RLS design is for a **single-user app** where `owner_id = auth.uid()` provides complete isolation. When Swiss Coin expands to support shared groups (multiple users collaborating), the following changes will be needed:

### Shared Group Access Pattern

```sql
-- Future: Allow group members to see group transactions
CREATE POLICY financial_transactions_group_select ON public.financial_transactions
  FOR SELECT
  USING (
    owner_id = auth.uid()
    OR (
      group_id IS NOT NULL
      AND EXISTS (
        SELECT 1 FROM public.group_members gm
        JOIN public.user_groups g ON g.id = gm.group_id
        WHERE gm.group_id = financial_transactions.group_id
          AND gm.person_id IN (
            SELECT p.id FROM public.persons p
            WHERE p.phone_number = (
              SELECT phone FROM public.profiles WHERE id = auth.uid()
            )
          )
      )
    )
  );
```

### What Changes

| Current | Future |
|---------|--------|
| `owner_id = auth.uid()` only | `owner_id = auth.uid() OR member of shared group` |
| Single user per dataset | Multiple users can see shared data |
| No person-to-user linking | `persons.linked_user_id` references `auth.users` |
| Junction tables check one owner | Junction tables check any group member |

### Migration Strategy

1. Add `linked_user_id UUID REFERENCES auth.users(id)` to `persons`
2. Create invitation/acceptance flow
3. Update RLS policies with OR clauses for group membership
4. Keep existing `owner_id` policies as the base case

> **Important:** The current single-owner policies are a correct subset of the future multi-user policies. Expanding is additive, not breaking.

---

## Policy Summary Table

| Table | SELECT | INSERT | UPDATE | DELETE | Pattern |
|-------|--------|--------|--------|--------|---------|
| `profiles` | Own profile | -- (trigger) | Own profile | -- | `id = auth.uid()` |
| `persons` | Own data | Own data | Own data | Own data | `owner_id` |
| `user_groups` | Own data | Own data | Own data | Own data | `owner_id` |
| `group_members` | Own group | Own group + person | -- | Own group | EXISTS (group) |
| `subscriptions` | Own data | Own data | Own data | Own data | `owner_id` |
| `subscription_subscribers` | Own sub | Own sub + person | -- | Own sub | EXISTS (sub) |
| `financial_transactions` | Own data | Own data | Own data | Own data | `owner_id` |
| `transaction_splits` | Own txn | Own txn | Own txn | Own txn | EXISTS (txn) |
| `transaction_payers` | Own txn | Own txn | Own txn | Own txn | EXISTS (txn) |
| `settlements` | Own data | Own data | Own data | Own data | `owner_id` |
| `reminders` | Own data | Own data | Own data | Own data | `owner_id` |
| `chat_messages` | Own data | Own data | Own data | Own data | `owner_id` |
| `subscription_payments` | Own sub | Own sub | Own sub | Own sub | EXISTS (sub) |
| `subscription_settlements` | Own sub | Own sub | Own sub | Own sub | EXISTS (sub) |
| `subscription_reminders` | Own sub | Own sub | Own sub | Own sub | EXISTS (sub) |

**Total: 56 policies** (4 per direct-ownership table x 8, 4 per parent table x 5, 3 per junction table x 2, 2 for profiles)
