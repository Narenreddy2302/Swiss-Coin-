# 02 - Database Schema

Complete PostgreSQL schema for Swiss Coin. 16 tables mapped from 12 CoreData entities plus `profiles` and 2 junction tables. All tables use soft deletes (`deleted_at`) where applicable, `owner_id` for data isolation, and `moddatetime` triggers for automatic `updated_at`.

---

## Table of Contents

1. [Prerequisites](#1-prerequisites)
2. [Table Creation Order](#2-table-creation-order)
3. [Table Definitions](#3-table-definitions)
4. [Triggers](#4-triggers)
5. [Indexes](#5-indexes)
6. [CoreData Mapping Reference](#6-coredata-mapping-reference)

---

## 1. Prerequisites

### Enable Extensions

```sql
-- moddatetime: auto-updates `updated_at` on row modification
CREATE EXTENSION IF NOT EXISTS moddatetime WITH SCHEMA extensions;
```

### Auth Trigger Function

```sql
-- Auto-create a profile row when a user signs up
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  INSERT INTO public.profiles (id, display_name, phone, created_at, updated_at)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data ->> 'display_name', 'Me'),
    NEW.phone,
    NOW(),
    NOW()
  );
  RETURN NEW;
END;
$$;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();
```

---

## 2. Table Creation Order

Tables must be created in FK dependency order. The diagram below shows the dependency tree:

```
auth.users
    |
    +-- profiles (1:1)
    |
    +-- persons (owner_id)
    |       |
    |       +-- group_members (person_id)
    |       +-- subscription_subscribers (person_id)
    |       +-- financial_transactions (payer_id, created_by_id)
    |       +-- transaction_splits (owed_by_id)
    |       +-- transaction_payers (paid_by_id)
    |       +-- settlements (from_person_id, to_person_id)
    |       +-- reminders (to_person_id)
    |       +-- chat_messages (via person context)
    |       +-- subscription_payments (payer_id)
    |       +-- subscription_settlements (from/to_person_id)
    |       +-- subscription_reminders (to_person_id)
    |
    +-- user_groups (owner_id)
    |       |
    |       +-- group_members (group_id)
    |       +-- financial_transactions (group_id)
    |
    +-- subscriptions (owner_id)
            |
            +-- subscription_subscribers (subscription_id)
            +-- subscription_payments (subscription_id)
            +-- subscription_settlements (subscription_id)
            +-- subscription_reminders (subscription_id)
```

**Creation order:**

1. `profiles`
2. `persons`
3. `user_groups`
4. `group_members`
5. `subscriptions`
6. `subscription_subscribers`
7. `financial_transactions`
8. `transaction_splits`
9. `transaction_payers`
10. `settlements`
11. `reminders`
12. `chat_messages`
13. `subscription_payments`
14. `subscription_settlements`
15. `subscription_reminders`

---

## 3. Table Definitions

### 3.1 profiles

1:1 with `auth.users`. Auto-created by the `handle_new_user()` trigger.

```sql
CREATE TABLE public.profiles (
  id          UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  display_name TEXT NOT NULL DEFAULT 'Me',
  full_name   TEXT,
  phone       TEXT,
  email       TEXT,
  photo_url   TEXT,
  color_hex   TEXT,
  is_archived BOOLEAN NOT NULL DEFAULT FALSE,
  last_viewed_date TIMESTAMPTZ,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.profiles IS 'User profile data, 1:1 with auth.users. Auto-created on signup.';
```

### 3.2 persons

Contacts/people in the user's expense-splitting world. Each user has their own set of persons.

```sql
CREATE TABLE public.persons (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id    UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name        TEXT NOT NULL,
  phone_number TEXT,
  photo_url   TEXT,
  color_hex   TEXT,
  is_archived BOOLEAN NOT NULL DEFAULT FALSE,
  last_viewed_date TIMESTAMPTZ,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at  TIMESTAMPTZ
);

COMMENT ON TABLE public.persons IS 'Contacts that the user splits expenses with.';
```

### 3.3 user_groups

Expense groups (e.g., "Roommates", "Trip to Paris").

```sql
CREATE TABLE public.user_groups (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id    UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name        TEXT NOT NULL,
  photo_url   TEXT,
  color_hex   TEXT,
  created_date TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  last_viewed_date TIMESTAMPTZ,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at  TIMESTAMPTZ
);

COMMENT ON TABLE public.user_groups IS 'Expense groups for organizing splits.';
```

### 3.4 group_members

Junction table: which persons belong to which groups.

```sql
CREATE TABLE public.group_members (
  group_id    UUID NOT NULL REFERENCES public.user_groups(id) ON DELETE CASCADE,
  person_id   UUID NOT NULL REFERENCES public.persons(id) ON DELETE CASCADE,
  PRIMARY KEY (group_id, person_id)
);

COMMENT ON TABLE public.group_members IS 'Junction: group <-> person membership.';
```

### 3.5 subscriptions

Recurring expenses (Netflix, rent, etc.).

```sql
CREATE TABLE public.subscriptions (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id        UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name            TEXT NOT NULL,
  amount          DOUBLE PRECISION NOT NULL,
  cycle           TEXT NOT NULL,
  custom_cycle_days SMALLINT DEFAULT 0,
  start_date      TIMESTAMPTZ NOT NULL,
  next_billing_date TIMESTAMPTZ,
  is_shared       BOOLEAN NOT NULL DEFAULT FALSE,
  is_active       BOOLEAN NOT NULL DEFAULT TRUE,
  category        TEXT,
  icon_name       TEXT,
  color_hex       TEXT,
  notes           TEXT,
  notification_enabled BOOLEAN NOT NULL DEFAULT TRUE,
  notification_days_before SMALLINT NOT NULL DEFAULT 3,
  is_archived     BOOLEAN NOT NULL DEFAULT FALSE,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at      TIMESTAMPTZ
);

COMMENT ON TABLE public.subscriptions IS 'Recurring expenses and subscriptions.';
```

### 3.6 subscription_subscribers

Junction table: which persons are subscribers on a shared subscription.

```sql
CREATE TABLE public.subscription_subscribers (
  subscription_id UUID NOT NULL REFERENCES public.subscriptions(id) ON DELETE CASCADE,
  person_id       UUID NOT NULL REFERENCES public.persons(id) ON DELETE CASCADE,
  PRIMARY KEY (subscription_id, person_id)
);

COMMENT ON TABLE public.subscription_subscribers IS 'Junction: subscription <-> person subscribers.';
```

### 3.7 financial_transactions

Core expense/income records with split and payer details.

```sql
CREATE TABLE public.financial_transactions (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id      UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title         TEXT NOT NULL,
  amount        DOUBLE PRECISION NOT NULL,
  currency      TEXT,
  date          TIMESTAMPTZ NOT NULL,
  split_method  TEXT,
  note          TEXT,
  payer_id      UUID REFERENCES public.persons(id) ON DELETE SET NULL,
  created_by_id UUID REFERENCES public.persons(id) ON DELETE SET NULL,
  group_id      UUID REFERENCES public.user_groups(id) ON DELETE SET NULL,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at    TIMESTAMPTZ
);

COMMENT ON TABLE public.financial_transactions IS 'Expense and income transactions. payer_id is legacy single-payer field.';
```

### 3.8 transaction_splits

Who owes what amount on a transaction. Each split belongs to one transaction.

```sql
CREATE TABLE public.transaction_splits (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  transaction_id  UUID NOT NULL REFERENCES public.financial_transactions(id) ON DELETE CASCADE,
  owed_by_id      UUID NOT NULL REFERENCES public.persons(id) ON DELETE CASCADE,
  amount          DOUBLE PRECISION NOT NULL,
  raw_amount      DOUBLE PRECISION
);

COMMENT ON TABLE public.transaction_splits IS 'Individual split amounts per person on a transaction.';
```

### 3.9 transaction_payers

Who paid what amount on a transaction (multi-payer support).

```sql
CREATE TABLE public.transaction_payers (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  transaction_id  UUID NOT NULL REFERENCES public.financial_transactions(id) ON DELETE CASCADE,
  paid_by_id      UUID NOT NULL REFERENCES public.persons(id) ON DELETE CASCADE,
  amount          DOUBLE PRECISION NOT NULL
);

COMMENT ON TABLE public.transaction_payers IS 'Individual payer amounts on a transaction (multi-payer support).';
```

### 3.10 settlements

Debt settlements between persons.

```sql
CREATE TABLE public.settlements (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id          UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  amount            DOUBLE PRECISION NOT NULL,
  currency          TEXT,
  date              TIMESTAMPTZ NOT NULL,
  note              TEXT,
  is_full_settlement BOOLEAN NOT NULL DEFAULT FALSE,
  from_person_id    UUID NOT NULL REFERENCES public.persons(id) ON DELETE CASCADE,
  to_person_id      UUID NOT NULL REFERENCES public.persons(id) ON DELETE CASCADE,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at        TIMESTAMPTZ
);

COMMENT ON TABLE public.settlements IS 'Debt settlement records between two persons.';
```

### 3.11 reminders

Payment reminders sent to persons.

```sql
CREATE TABLE public.reminders (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id      UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_date  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  to_person_id  UUID NOT NULL REFERENCES public.persons(id) ON DELETE CASCADE,
  amount        DOUBLE PRECISION NOT NULL,
  message       TEXT,
  is_read       BOOLEAN NOT NULL DEFAULT FALSE,
  is_cleared    BOOLEAN NOT NULL DEFAULT FALSE,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.reminders IS 'Payment reminder notifications.';
```

### 3.12 chat_messages

In-app messages and transaction comments. Can be associated with a person, group, subscription, or transaction.

```sql
CREATE TABLE public.chat_messages (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id            UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  content             TEXT NOT NULL,
  timestamp           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  is_from_user        BOOLEAN NOT NULL DEFAULT TRUE,
  is_edited           BOOLEAN NOT NULL DEFAULT FALSE,
  with_person_id      UUID REFERENCES public.persons(id) ON DELETE SET NULL,
  with_group_id       UUID REFERENCES public.user_groups(id) ON DELETE SET NULL,
  with_subscription_id UUID REFERENCES public.subscriptions(id) ON DELETE SET NULL,
  on_transaction_id   UUID REFERENCES public.financial_transactions(id) ON DELETE SET NULL,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.chat_messages IS 'In-app messages and transaction comments.';
```

### 3.13 subscription_payments

Individual payment records for shared subscriptions.

```sql
CREATE TABLE public.subscription_payments (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  subscription_id     UUID NOT NULL REFERENCES public.subscriptions(id) ON DELETE CASCADE,
  payer_id            UUID NOT NULL REFERENCES public.persons(id) ON DELETE CASCADE,
  amount              DOUBLE PRECISION NOT NULL,
  date                TIMESTAMPTZ NOT NULL,
  billing_period_start TIMESTAMPTZ,
  billing_period_end  TIMESTAMPTZ,
  note                TEXT,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.subscription_payments IS 'Individual payments on shared subscriptions.';
```

### 3.14 subscription_settlements

Settlement records for shared subscription debts.

```sql
CREATE TABLE public.subscription_settlements (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  subscription_id UUID NOT NULL REFERENCES public.subscriptions(id) ON DELETE CASCADE,
  from_person_id  UUID NOT NULL REFERENCES public.persons(id) ON DELETE CASCADE,
  to_person_id    UUID NOT NULL REFERENCES public.persons(id) ON DELETE CASCADE,
  amount          DOUBLE PRECISION NOT NULL,
  date            TIMESTAMPTZ NOT NULL,
  note            TEXT,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.subscription_settlements IS 'Settlement records for shared subscription debts.';
```

### 3.15 subscription_reminders

Reminders for subscription payments.

```sql
CREATE TABLE public.subscription_reminders (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  subscription_id UUID NOT NULL REFERENCES public.subscriptions(id) ON DELETE CASCADE,
  created_date    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  to_person_id    UUID NOT NULL REFERENCES public.persons(id) ON DELETE CASCADE,
  amount          DOUBLE PRECISION NOT NULL,
  message         TEXT,
  is_read         BOOLEAN NOT NULL DEFAULT FALSE,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.subscription_reminders IS 'Reminders for subscription payment obligations.';
```

---

## 4. Triggers

### moddatetime Triggers

Auto-update `updated_at` on every row modification. Apply to all tables that have an `updated_at` column:

```sql
-- profiles
CREATE TRIGGER handle_updated_at_profiles
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION extensions.moddatetime(updated_at);

-- persons
CREATE TRIGGER handle_updated_at_persons
  BEFORE UPDATE ON public.persons
  FOR EACH ROW
  EXECUTE FUNCTION extensions.moddatetime(updated_at);

-- user_groups
CREATE TRIGGER handle_updated_at_user_groups
  BEFORE UPDATE ON public.user_groups
  FOR EACH ROW
  EXECUTE FUNCTION extensions.moddatetime(updated_at);

-- subscriptions
CREATE TRIGGER handle_updated_at_subscriptions
  BEFORE UPDATE ON public.subscriptions
  FOR EACH ROW
  EXECUTE FUNCTION extensions.moddatetime(updated_at);

-- financial_transactions
CREATE TRIGGER handle_updated_at_financial_transactions
  BEFORE UPDATE ON public.financial_transactions
  FOR EACH ROW
  EXECUTE FUNCTION extensions.moddatetime(updated_at);

-- settlements
CREATE TRIGGER handle_updated_at_settlements
  BEFORE UPDATE ON public.settlements
  FOR EACH ROW
  EXECUTE FUNCTION extensions.moddatetime(updated_at);

-- reminders
CREATE TRIGGER handle_updated_at_reminders
  BEFORE UPDATE ON public.reminders
  FOR EACH ROW
  EXECUTE FUNCTION extensions.moddatetime(updated_at);

-- chat_messages
CREATE TRIGGER handle_updated_at_chat_messages
  BEFORE UPDATE ON public.chat_messages
  FOR EACH ROW
  EXECUTE FUNCTION extensions.moddatetime(updated_at);

-- subscription_payments
CREATE TRIGGER handle_updated_at_subscription_payments
  BEFORE UPDATE ON public.subscription_payments
  FOR EACH ROW
  EXECUTE FUNCTION extensions.moddatetime(updated_at);

-- subscription_settlements
CREATE TRIGGER handle_updated_at_subscription_settlements
  BEFORE UPDATE ON public.subscription_settlements
  FOR EACH ROW
  EXECUTE FUNCTION extensions.moddatetime(updated_at);

-- subscription_reminders
CREATE TRIGGER handle_updated_at_subscription_reminders
  BEFORE UPDATE ON public.subscription_reminders
  FOR EACH ROW
  EXECUTE FUNCTION extensions.moddatetime(updated_at);
```

---

## 5. Indexes

Indexes on foreign keys and commonly queried columns for performance:

```sql
-- persons
CREATE INDEX idx_persons_owner_id ON public.persons(owner_id);
CREATE INDEX idx_persons_deleted_at ON public.persons(deleted_at) WHERE deleted_at IS NULL;

-- user_groups
CREATE INDEX idx_user_groups_owner_id ON public.user_groups(owner_id);
CREATE INDEX idx_user_groups_deleted_at ON public.user_groups(deleted_at) WHERE deleted_at IS NULL;

-- group_members
CREATE INDEX idx_group_members_person_id ON public.group_members(person_id);

-- subscriptions
CREATE INDEX idx_subscriptions_owner_id ON public.subscriptions(owner_id);
CREATE INDEX idx_subscriptions_deleted_at ON public.subscriptions(deleted_at) WHERE deleted_at IS NULL;
CREATE INDEX idx_subscriptions_next_billing ON public.subscriptions(next_billing_date) WHERE is_active = TRUE;

-- subscription_subscribers
CREATE INDEX idx_subscription_subscribers_person_id ON public.subscription_subscribers(person_id);

-- financial_transactions
CREATE INDEX idx_financial_transactions_owner_id ON public.financial_transactions(owner_id);
CREATE INDEX idx_financial_transactions_payer_id ON public.financial_transactions(payer_id);
CREATE INDEX idx_financial_transactions_created_by_id ON public.financial_transactions(created_by_id);
CREATE INDEX idx_financial_transactions_group_id ON public.financial_transactions(group_id);
CREATE INDEX idx_financial_transactions_date ON public.financial_transactions(date DESC);
CREATE INDEX idx_financial_transactions_deleted_at ON public.financial_transactions(deleted_at) WHERE deleted_at IS NULL;

-- transaction_splits
CREATE INDEX idx_transaction_splits_transaction_id ON public.transaction_splits(transaction_id);
CREATE INDEX idx_transaction_splits_owed_by_id ON public.transaction_splits(owed_by_id);

-- transaction_payers
CREATE INDEX idx_transaction_payers_transaction_id ON public.transaction_payers(transaction_id);
CREATE INDEX idx_transaction_payers_paid_by_id ON public.transaction_payers(paid_by_id);

-- settlements
CREATE INDEX idx_settlements_owner_id ON public.settlements(owner_id);
CREATE INDEX idx_settlements_from_person_id ON public.settlements(from_person_id);
CREATE INDEX idx_settlements_to_person_id ON public.settlements(to_person_id);
CREATE INDEX idx_settlements_date ON public.settlements(date DESC);
CREATE INDEX idx_settlements_deleted_at ON public.settlements(deleted_at) WHERE deleted_at IS NULL;

-- reminders
CREATE INDEX idx_reminders_owner_id ON public.reminders(owner_id);
CREATE INDEX idx_reminders_to_person_id ON public.reminders(to_person_id);
CREATE INDEX idx_reminders_unread ON public.reminders(owner_id) WHERE is_read = FALSE;

-- chat_messages
CREATE INDEX idx_chat_messages_owner_id ON public.chat_messages(owner_id);
CREATE INDEX idx_chat_messages_with_person_id ON public.chat_messages(with_person_id);
CREATE INDEX idx_chat_messages_with_group_id ON public.chat_messages(with_group_id);
CREATE INDEX idx_chat_messages_with_subscription_id ON public.chat_messages(with_subscription_id);
CREATE INDEX idx_chat_messages_on_transaction_id ON public.chat_messages(on_transaction_id);
CREATE INDEX idx_chat_messages_timestamp ON public.chat_messages(timestamp DESC);

-- subscription_payments
CREATE INDEX idx_subscription_payments_subscription_id ON public.subscription_payments(subscription_id);
CREATE INDEX idx_subscription_payments_payer_id ON public.subscription_payments(payer_id);

-- subscription_settlements
CREATE INDEX idx_subscription_settlements_subscription_id ON public.subscription_settlements(subscription_id);
CREATE INDEX idx_subscription_settlements_from_person_id ON public.subscription_settlements(from_person_id);
CREATE INDEX idx_subscription_settlements_to_person_id ON public.subscription_settlements(to_person_id);

-- subscription_reminders
CREATE INDEX idx_subscription_reminders_subscription_id ON public.subscription_reminders(subscription_id);
CREATE INDEX idx_subscription_reminders_to_person_id ON public.subscription_reminders(to_person_id);
CREATE INDEX idx_subscription_reminders_unread ON public.subscription_reminders(subscription_id) WHERE is_read = FALSE;
```

---

## 6. CoreData Mapping Reference

Detailed column-level mapping between CoreData attributes and Supabase columns.

### Person -> persons

| CoreData Attribute | Supabase Column | Type | Notes |
|-------------------|-----------------|------|-------|
| `id` (UUID) | `id` (UUID PK) | UUID | Same value |
| -- | `owner_id` | UUID FK | New: references auth.users |
| `name` (String) | `name` (TEXT) | TEXT | NOT NULL |
| `phoneNumber` (String?) | `phone_number` (TEXT) | TEXT | Nullable |
| `photoData` (Binary?) | `photo_url` (TEXT) | TEXT | Changed: blob -> URL |
| `colorHex` (String?) | `color_hex` (TEXT) | TEXT | Nullable |
| `isArchived` (Bool) | `is_archived` (BOOLEAN) | BOOLEAN | Default FALSE |
| `lastViewedDate` (Date?) | `last_viewed_date` (TIMESTAMPTZ) | TIMESTAMPTZ | Nullable |
| -- | `created_at` | TIMESTAMPTZ | New: auto-set |
| -- | `updated_at` | TIMESTAMPTZ | New: auto-updated |
| -- | `deleted_at` | TIMESTAMPTZ | New: soft delete |

### UserGroup -> user_groups

| CoreData Attribute | Supabase Column | Notes |
|-------------------|-----------------|-------|
| `id` | `id` | Same |
| -- | `owner_id` | New |
| `name` | `name` | NOT NULL |
| `photoData` | `photo_url` | blob -> URL |
| `colorHex` | `color_hex` | |
| `createdDate` | `created_date` | |
| `lastViewedDate` | `last_viewed_date` | |
| -- | `created_at`, `updated_at`, `deleted_at` | New |

### FinancialTransaction -> financial_transactions

| CoreData Attribute | Supabase Column | Notes |
|-------------------|-----------------|-------|
| `id` | `id` | Same |
| -- | `owner_id` | New |
| `title` | `title` | NOT NULL |
| `amount` | `amount` | DOUBLE PRECISION |
| `currency` | `currency` | Nullable |
| `date` | `date` | TIMESTAMPTZ |
| `splitMethod` | `split_method` | Nullable |
| `note` | `note` | Nullable |
| `payer` (relationship) | `payer_id` (UUID FK) | Legacy single payer |
| `createdBy` (relationship) | `created_by_id` (UUID FK) | |
| `group` (relationship) | `group_id` (UUID FK) | Nullable |
| -- | `created_at`, `updated_at`, `deleted_at` | New |

### TransactionSplit -> transaction_splits

| CoreData Attribute | Supabase Column | Notes |
|-------------------|-----------------|-------|
| -- | `id` | New: UUID PK (CoreData has no id) |
| `transaction` (relationship) | `transaction_id` (UUID FK) | CASCADE |
| `owedBy` (relationship) | `owed_by_id` (UUID FK) | CASCADE |
| `amount` | `amount` | DOUBLE PRECISION |
| `rawAmount` | `raw_amount` | Nullable |

### TransactionPayer -> transaction_payers

| CoreData Attribute | Supabase Column | Notes |
|-------------------|-----------------|-------|
| -- | `id` | New: UUID PK (CoreData has no id) |
| `transaction` (relationship) | `transaction_id` (UUID FK) | CASCADE |
| `paidBy` (relationship) | `paid_by_id` (UUID FK) | CASCADE |
| `amount` | `amount` | DOUBLE PRECISION |

### Settlement -> settlements

| CoreData Attribute | Supabase Column | Notes |
|-------------------|-----------------|-------|
| `id` | `id` | Same |
| -- | `owner_id` | New |
| `amount` | `amount` | DOUBLE PRECISION |
| `currency` | `currency` | Nullable |
| `date` | `date` | TIMESTAMPTZ |
| `note` | `note` | Nullable |
| `isFullSettlement` | `is_full_settlement` | BOOLEAN |
| `fromPerson` (relationship) | `from_person_id` (UUID FK) | CASCADE |
| `toPerson` (relationship) | `to_person_id` (UUID FK) | CASCADE |
| -- | `created_at`, `updated_at`, `deleted_at` | New |

### Reminder -> reminders

| CoreData Attribute | Supabase Column | Notes |
|-------------------|-----------------|-------|
| `id` | `id` | Same |
| -- | `owner_id` | New |
| `createdDate` | `created_date` | TIMESTAMPTZ |
| `toPerson` (relationship) | `to_person_id` (UUID FK) | CASCADE |
| `amount` | `amount` | DOUBLE PRECISION |
| `message` | `message` | Nullable |
| `isRead` | `is_read` | BOOLEAN |
| `isCleared` | `is_cleared` | BOOLEAN |
| -- | `created_at`, `updated_at` | New |

### ChatMessage -> chat_messages

| CoreData Attribute | Supabase Column | Notes |
|-------------------|-----------------|-------|
| `id` | `id` | Same |
| -- | `owner_id` | New |
| `content` | `content` | NOT NULL |
| `timestamp` | `timestamp` | TIMESTAMPTZ |
| `isFromUser` | `is_from_user` | BOOLEAN |
| `isEdited` | `is_edited` | BOOLEAN |
| `withPerson` (relationship) | `with_person_id` (UUID FK) | SET NULL |
| `withGroup` (relationship) | `with_group_id` (UUID FK) | SET NULL |
| `withSubscription` (relationship) | `with_subscription_id` (UUID FK) | SET NULL |
| `onTransaction` (relationship) | `on_transaction_id` (UUID FK) | SET NULL |
| -- | `created_at`, `updated_at` | New |

### Subscription -> subscriptions

| CoreData Attribute | Supabase Column | Notes |
|-------------------|-----------------|-------|
| `id` | `id` | Same |
| -- | `owner_id` | New |
| `name` | `name` | NOT NULL |
| `amount` | `amount` | DOUBLE PRECISION |
| `cycle` | `cycle` | TEXT |
| `customCycleDays` | `custom_cycle_days` | SMALLINT |
| `startDate` | `start_date` | TIMESTAMPTZ |
| `nextBillingDate` | `next_billing_date` | TIMESTAMPTZ |
| `isShared` | `is_shared` | BOOLEAN |
| `isActive` | `is_active` | BOOLEAN |
| `category` | `category` | Nullable |
| `iconName` | `icon_name` | Nullable |
| `colorHex` | `color_hex` | Nullable |
| `notes` | `notes` | Nullable |
| `notificationEnabled` | `notification_enabled` | BOOLEAN |
| `notificationDaysBefore` | `notification_days_before` | SMALLINT |
| `isArchived` | `is_archived` | BOOLEAN |
| `subscribers` (M2M) | `subscription_subscribers` | Junction table |
| -- | `created_at`, `updated_at`, `deleted_at` | New |

### SubscriptionPayment -> subscription_payments

| CoreData Attribute | Supabase Column | Notes |
|-------------------|-----------------|-------|
| `id` | `id` | Same |
| `subscription` (relationship) | `subscription_id` (UUID FK) | CASCADE |
| `payer` (relationship) | `payer_id` (UUID FK) | CASCADE |
| `amount` | `amount` | DOUBLE PRECISION |
| `date` | `date` | TIMESTAMPTZ |
| `billingPeriodStart` | `billing_period_start` | Nullable |
| `billingPeriodEnd` | `billing_period_end` | Nullable |
| `note` | `note` | Nullable |
| -- | `created_at`, `updated_at` | New |

### SubscriptionSettlement -> subscription_settlements

| CoreData Attribute | Supabase Column | Notes |
|-------------------|-----------------|-------|
| `id` | `id` | Same |
| `subscription` (relationship) | `subscription_id` (UUID FK) | CASCADE |
| `fromPerson` (relationship) | `from_person_id` (UUID FK) | CASCADE |
| `toPerson` (relationship) | `to_person_id` (UUID FK) | CASCADE |
| `amount` | `amount` | DOUBLE PRECISION |
| `date` | `date` | TIMESTAMPTZ |
| `note` | `note` | Nullable |
| -- | `created_at`, `updated_at` | New |

### SubscriptionReminder -> subscription_reminders

| CoreData Attribute | Supabase Column | Notes |
|-------------------|-----------------|-------|
| `id` | `id` | Same |
| `subscription` (relationship) | `subscription_id` (UUID FK) | CASCADE |
| `createdDate` | `created_date` | TIMESTAMPTZ |
| `toPerson` (relationship) | `to_person_id` (UUID FK) | CASCADE |
| `amount` | `amount` | DOUBLE PRECISION |
| `message` | `message` | Nullable |
| `isRead` | `is_read` | BOOLEAN |
| -- | `created_at`, `updated_at` | New |

---

## Naming Conventions

| Convention | Rule | Example |
|-----------|------|---------|
| Table names | Lowercase, plural, snake_case | `financial_transactions` |
| Column names | Lowercase, snake_case | `is_full_settlement` |
| Primary keys | `id` (UUID) | `id UUID PRIMARY KEY` |
| Foreign keys | `<entity>_id` | `payer_id`, `group_id` |
| Timestamps | `created_at`, `updated_at`, `deleted_at` | TIMESTAMPTZ |
| Booleans | `is_<adjective>` | `is_archived`, `is_read` |
| Indexes | `idx_<table>_<column>` | `idx_persons_owner_id` |
| Triggers | `handle_updated_at_<table>` | `handle_updated_at_persons` |

---

## Full Migration SQL (Combined)

For convenience, see the individual migrations applied via Supabase MCP or the migration files in `supabase/migrations/`. Each table and its triggers/indexes should be applied as a single migration for atomicity.
