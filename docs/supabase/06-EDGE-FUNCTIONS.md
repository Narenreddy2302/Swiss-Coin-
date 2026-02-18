# 06 - Edge Functions

Server-side Deno functions deployed to Supabase Edge Runtime. These handle operations that must run server-side: balance verification, scheduled reminders, and push notifications.

---

## Table of Contents

1. [Overview](#overview)
2. [Device Tokens Table](#device-tokens-table)
3. [calculate-balance](#calculate-balance)
4. [schedule-reminders](#schedule-reminders)
5. [send-push-notification](#send-push-notification)
6. [Cron Setup](#cron-setup)
7. [Deployment](#deployment)

---

## Overview

| Function | Trigger | Purpose |
|----------|---------|---------|
| `calculate-balance` | HTTP (on-demand) | Server-side balance verification between two persons |
| `schedule-reminders` | Cron (hourly) | Check subscriptions and create reminders |
| `send-push-notification` | HTTP (internal) | Send APNs push notification to iOS device |

All functions use Deno runtime and import from `jsr:@supabase/functions-js/edge-runtime.d.ts`.

---

## Device Tokens Table

Required for push notifications. Apply this migration before deploying edge functions.

```sql
-- Migration: create_device_tokens
CREATE TABLE device_tokens (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  token text NOT NULL,
  platform text NOT NULL DEFAULT 'ios',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(user_id, token)
);

ALTER TABLE device_tokens ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users manage own device tokens"
  ON device_tokens FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE TRIGGER handle_device_tokens_updated_at
  BEFORE UPDATE ON device_tokens
  FOR EACH ROW EXECUTE FUNCTION moddatetime(updated_at);
```

---

## calculate-balance

Server-side balance verification that ports the Swift `pairwiseBalance()` algorithm to TypeScript. Called on-demand to verify client-calculated balances or resolve disputes.

### Request

```
POST /functions/v1/calculate-balance
Authorization: Bearer <user_jwt>
Content-Type: application/json

{
  "person_id": "uuid-of-the-other-person"
}
```

### Response

```json
{
  "balances": {
    "USD": 45.50,
    "EUR": -12.00
  },
  "is_settled": false,
  "primary_amount": 45.50,
  "primary_currency": "USD"
}
```

### Full TypeScript Code

```typescript
// supabase/functions/calculate-balance/index.ts

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

interface TransactionRow {
  id: string;
  amount: number;
  currency: string | null;
}

interface SplitRow {
  amount: number;
  owed_by_id: string;
  transaction_id: string;
}

interface PayerRow {
  amount: number;
  paid_by_id: string;
  transaction_id: string;
}

interface SettlementRow {
  amount: number;
  currency: string | null;
  from_person_id: string;
  to_person_id: string;
}

interface CurrencyBalance {
  [currency: string]: number;
}

/**
 * Pairwise balance calculation — mirrors Swift FinancialTransaction.pairwiseBalance()
 *
 * For a single transaction, calculates how much personA is owed by personB (positive)
 * or owes personB (negative) using the net-position algorithm.
 */
function pairwiseBalance(
  personA: string,
  personB: string,
  payers: PayerRow[],
  splits: SplitRow[]
): number {
  const netPositions: Record<string, number> = {};

  // Build net positions: net_i = paid_i - owed_i
  for (const payer of payers) {
    netPositions[payer.paid_by_id] =
      (netPositions[payer.paid_by_id] || 0) + payer.amount;
  }

  for (const split of splits) {
    netPositions[split.owed_by_id] =
      (netPositions[split.owed_by_id] || 0) - split.amount;
  }

  const netA = netPositions[personA] || 0;
  const netB = netPositions[personB] || 0;

  // Total credit = sum of all positive net positions
  const totalCredit = Object.values(netPositions)
    .filter((v) => v > 0.001)
    .reduce((sum, v) => sum + v, 0);

  if (totalCredit < 0.001) return 0;

  if (netA > 0.001 && netB < -0.001) {
    // B owes A: proportional share of B's debt allocated to A
    return Math.abs(netB) * (netA / totalCredit);
  } else if (netA < -0.001 && netB > 0.001) {
    // A owes B: proportional share of A's debt allocated to B
    return -(Math.abs(netA) * (netB / totalCredit));
  }

  return 0;
}

Deno.serve(async (req: Request) => {
  try {
    // Verify JWT and get user
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Missing authorization" }), {
        status: 401,
        headers: { "Content-Type": "application/json" },
      });
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      {
        global: { headers: { Authorization: authHeader } },
      }
    );

    const {
      data: { user },
      error: authError,
    } = await supabase.auth.getUser();
    if (authError || !user) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { "Content-Type": "application/json" },
      });
    }

    const { person_id } = await req.json();
    if (!person_id) {
      return new Response(
        JSON.stringify({ error: "person_id is required" }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    const currentUserId = user.id;

    // Use service role client for cross-table queries
    const serviceClient = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    // Verify the person belongs to this user
    const { data: person, error: personError } = await serviceClient
      .from("persons")
      .select("id")
      .eq("id", person_id)
      .eq("owner_id", currentUserId)
      .is("deleted_at", null)
      .single();

    if (personError || !person) {
      return new Response(
        JSON.stringify({ error: "Person not found" }),
        { status: 404, headers: { "Content-Type": "application/json" } }
      );
    }

    // The "current user as person" — the Person record whose ID matches auth.users.id
    // This is the self-referential person created during migration
    const selfPersonId = currentUserId;

    // 1. Get all transactions where both persons are involved
    //    A person is "involved" if they are a payer, a split owed_by, or a transaction_payer

    // Get transaction IDs where person_id is involved (as legacy payer, split, or multi-payer)
    const { data: personSplits } = await serviceClient
      .from("transaction_splits")
      .select("transaction_id")
      .eq("owed_by_id", person_id);

    const { data: personPayers } = await serviceClient
      .from("transaction_payers")
      .select("transaction_id")
      .eq("paid_by_id", person_id);

    const { data: personLegacyPayer } = await serviceClient
      .from("financial_transactions")
      .select("id")
      .eq("payer_id", person_id)
      .eq("owner_id", currentUserId);

    // Collect all transaction IDs where person_id participates
    const personTxIds = new Set<string>();
    personSplits?.forEach((r) => personTxIds.add(r.transaction_id));
    personPayers?.forEach((r) => personTxIds.add(r.transaction_id));
    personLegacyPayer?.forEach((r) => personTxIds.add(r.id));

    // Get transaction IDs where self (currentUser) is involved
    const { data: selfSplits } = await serviceClient
      .from("transaction_splits")
      .select("transaction_id")
      .eq("owed_by_id", selfPersonId);

    const { data: selfPayers } = await serviceClient
      .from("transaction_payers")
      .select("transaction_id")
      .eq("paid_by_id", selfPersonId);

    const { data: selfLegacyPayer } = await serviceClient
      .from("financial_transactions")
      .select("id")
      .eq("payer_id", selfPersonId)
      .eq("owner_id", currentUserId);

    const selfTxIds = new Set<string>();
    selfSplits?.forEach((r) => selfTxIds.add(r.transaction_id));
    selfPayers?.forEach((r) => selfTxIds.add(r.transaction_id));
    selfLegacyPayer?.forEach((r) => selfTxIds.add(r.id));

    // Mutual transactions = intersection
    const mutualTxIds = [...personTxIds].filter((id) => selfTxIds.has(id));

    // 2. Calculate per-currency balance from transactions
    const balances: CurrencyBalance = {};

    for (const txId of mutualTxIds) {
      // Fetch transaction details
      const { data: tx } = await serviceClient
        .from("financial_transactions")
        .select("id, amount, currency, payer_id")
        .eq("id", txId)
        .is("deleted_at", null)
        .single();

      if (!tx) continue;

      const currency = tx.currency || "USD";

      // Get splits for this transaction
      const { data: txSplits } = await serviceClient
        .from("transaction_splits")
        .select("amount, owed_by_id, transaction_id")
        .eq("transaction_id", txId);

      // Get multi-payers for this transaction
      const { data: txPayers } = await serviceClient
        .from("transaction_payers")
        .select("amount, paid_by_id, transaction_id")
        .eq("transaction_id", txId);

      // Build effective payers (handle legacy single-payer fallback)
      let effectivePayers: PayerRow[] = txPayers || [];
      if (effectivePayers.length === 0 && tx.payer_id) {
        effectivePayers = [
          {
            amount: tx.amount,
            paid_by_id: tx.payer_id,
            transaction_id: txId,
          },
        ];
      }

      const pw = pairwiseBalance(
        selfPersonId,
        person_id,
        effectivePayers,
        txSplits || []
      );

      balances[currency] = (balances[currency] || 0) + pw;
    }

    // 3. Apply settlements between the two persons
    const { data: settlements } = await serviceClient
      .from("settlements")
      .select("amount, currency, from_person_id, to_person_id")
      .eq("owner_id", currentUserId)
      .is("deleted_at", null)
      .or(
        `and(from_person_id.eq.${person_id},to_person_id.eq.${selfPersonId}),` +
          `and(from_person_id.eq.${selfPersonId},to_person_id.eq.${person_id})`
      );

    for (const s of settlements || []) {
      const currency = s.currency || "USD";

      if (
        s.from_person_id === person_id &&
        s.to_person_id === selfPersonId
      ) {
        // They paid us — reduces their debt (balance decreases)
        balances[currency] = (balances[currency] || 0) - s.amount;
      } else if (
        s.from_person_id === selfPersonId &&
        s.to_person_id === person_id
      ) {
        // We paid them — reduces our debt (balance increases toward zero)
        balances[currency] = (balances[currency] || 0) + s.amount;
      }
    }

    // 4. Filter near-zero balances
    const nonZero: CurrencyBalance = {};
    for (const [code, amount] of Object.entries(balances)) {
      if (Math.abs(amount) >= 0.01) {
        nonZero[code] = Math.round(amount * 100) / 100;
      }
    }

    // Find primary (largest absolute value)
    const sorted = Object.entries(nonZero).sort(
      (a, b) => Math.abs(b[1]) - Math.abs(a[1])
    );
    const primaryAmount = sorted.length > 0 ? sorted[0][1] : 0;
    const primaryCurrency = sorted.length > 0 ? sorted[0][0] : "USD";

    return new Response(
      JSON.stringify({
        balances: nonZero,
        is_settled: Object.keys(nonZero).length === 0,
        primary_amount: primaryAmount,
        primary_currency: primaryCurrency,
      }),
      {
        status: 200,
        headers: { "Content-Type": "application/json", "Connection": "keep-alive" },
      }
    );
  } catch (error) {
    return new Response(
      JSON.stringify({ error: (error as Error).message }),
      {
        status: 500,
        headers: { "Content-Type": "application/json" },
      }
    );
  }
});
```

---

## schedule-reminders

Hourly cron function that checks active subscriptions where `next_billing_date` falls within the subscriber's `notification_days_before` window. Creates `subscription_reminders` records and triggers push notifications.

### Full TypeScript Code

```typescript
// supabase/functions/schedule-reminders/index.ts

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

interface SubscriptionRow {
  id: string;
  owner_id: string;
  name: string;
  amount: number;
  next_billing_date: string;
  notification_days_before: number;
  notification_enabled: boolean;
}

Deno.serve(async (req: Request) => {
  try {
    // Verify this is called by cron (check for service role or cron header)
    const authHeader = req.headers.get("Authorization");
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

    // For cron invocations, use service role
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      serviceRoleKey
    );

    const now = new Date();

    // Find active subscriptions with notifications enabled
    // where next_billing_date is within notification_days_before from now
    const { data: subscriptions, error: subError } = await supabase
      .from("subscriptions")
      .select("id, owner_id, name, amount, next_billing_date, notification_days_before, notification_enabled")
      .eq("is_active", true)
      .eq("notification_enabled", true)
      .eq("is_archived", false)
      .is("deleted_at", null)
      .not("next_billing_date", "is", null);

    if (subError) {
      throw new Error(`Failed to fetch subscriptions: ${subError.message}`);
    }

    let remindersCreated = 0;
    let notificationsSent = 0;

    for (const sub of subscriptions || []) {
      const billingDate = new Date(sub.next_billing_date);
      const daysUntilBilling = Math.ceil(
        (billingDate.getTime() - now.getTime()) / (1000 * 60 * 60 * 24)
      );

      // Only create reminder if within the notification window
      if (daysUntilBilling > sub.notification_days_before || daysUntilBilling < 0) {
        continue;
      }

      // Check if a reminder already exists for this billing period
      const reminderWindowStart = new Date(billingDate);
      reminderWindowStart.setDate(
        reminderWindowStart.getDate() - sub.notification_days_before
      );

      const { data: existingReminder } = await supabase
        .from("subscription_reminders")
        .select("id")
        .eq("subscription_id", sub.id)
        .gte("created_at", reminderWindowStart.toISOString())
        .limit(1);

      if (existingReminder && existingReminder.length > 0) {
        continue; // Already reminded for this billing period
      }

      // Get all subscribers for this subscription
      const { data: subscribers } = await supabase
        .from("subscription_subscribers")
        .select("person_id")
        .eq("subscription_id", sub.id);

      // Create a reminder for each subscriber
      for (const subscriber of subscribers || []) {
        const daysText =
          daysUntilBilling === 0
            ? "today"
            : daysUntilBilling === 1
            ? "tomorrow"
            : `in ${daysUntilBilling} days`;

        const message = `${sub.name} billing ${daysText}`;

        const { error: insertError } = await supabase
          .from("subscription_reminders")
          .insert({
            subscription_id: sub.id,
            to_person_id: subscriber.person_id,
            amount: sub.amount,
            message: message,
            is_read: false,
          });

        if (!insertError) {
          remindersCreated++;
        }
      }

      // Send push notification to the subscription owner
      const { data: deviceTokens } = await supabase
        .from("device_tokens")
        .select("token")
        .eq("user_id", sub.owner_id);

      for (const device of deviceTokens || []) {
        try {
          const pushUrl = `${Deno.env.get("SUPABASE_URL")}/functions/v1/send-push-notification`;
          await fetch(pushUrl, {
            method: "POST",
            headers: {
              "Content-Type": "application/json",
              Authorization: `Bearer ${serviceRoleKey}`,
            },
            body: JSON.stringify({
              token: device.token,
              title: "Subscription Reminder",
              body: `${sub.name} billing ${
                daysUntilBilling === 0
                  ? "today"
                  : daysUntilBilling === 1
                  ? "tomorrow"
                  : `in ${daysUntilBilling} days`
              } - $${sub.amount.toFixed(2)}`,
              data: {
                type: "subscription_reminder",
                subscription_id: sub.id,
              },
            }),
          });
          notificationsSent++;
        } catch (pushError) {
          console.error(
            `Failed to send push for subscription ${sub.id}:`,
            pushError
          );
        }
      }
    }

    return new Response(
      JSON.stringify({
        success: true,
        reminders_created: remindersCreated,
        notifications_sent: notificationsSent,
        checked_at: now.toISOString(),
      }),
      {
        status: 200,
        headers: { "Content-Type": "application/json", "Connection": "keep-alive" },
      }
    );
  } catch (error) {
    console.error("schedule-reminders error:", error);
    return new Response(
      JSON.stringify({ error: (error as Error).message }),
      {
        status: 500,
        headers: { "Content-Type": "application/json" },
      }
    );
  }
});
```

---

## send-push-notification

Sends Apple Push Notification Service (APNs) notifications via HTTP/2 with JWT authentication. Called internally by other edge functions (not directly by the client).

### Prerequisites

Store these as Supabase Edge Function secrets:

```bash
supabase secrets set APNS_KEY_ID="your-key-id"
supabase secrets set APNS_TEAM_ID="your-team-id"
supabase secrets set APNS_BUNDLE_ID="com.yourcompany.SwissCoin"
supabase secrets set APNS_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----"
```

### Request (Internal)

```json
{
  "token": "device-token-hex-string",
  "title": "Subscription Reminder",
  "body": "Netflix billing tomorrow - $15.99",
  "data": {
    "type": "subscription_reminder",
    "subscription_id": "uuid"
  }
}
```

### Full TypeScript Code

```typescript
// supabase/functions/send-push-notification/index.ts

import "jsr:@supabase/functions-js/edge-runtime.d.ts";

interface PushPayload {
  token: string;
  title: string;
  body: string;
  badge?: number;
  sound?: string;
  data?: Record<string, string>;
}

/**
 * Create a JWT token for APNs authentication.
 * Uses ES256 (P-256 + SHA-256) algorithm as required by Apple.
 */
async function createApnsJwt(
  keyId: string,
  teamId: string,
  privateKeyPem: string
): Promise<string> {
  // JWT Header
  const header = {
    alg: "ES256",
    kid: keyId,
  };

  // JWT Claims
  const claims = {
    iss: teamId,
    iat: Math.floor(Date.now() / 1000),
  };

  const encoder = new TextEncoder();

  // Base64url encode helper
  function base64url(data: Uint8Array): string {
    const base64 = btoa(String.fromCharCode(...data));
    return base64.replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
  }

  function base64urlString(str: string): string {
    return base64url(encoder.encode(str));
  }

  const headerB64 = base64urlString(JSON.stringify(header));
  const claimsB64 = base64urlString(JSON.stringify(claims));
  const signingInput = `${headerB64}.${claimsB64}`;

  // Import the private key
  const pemBody = privateKeyPem
    .replace(/-----BEGIN PRIVATE KEY-----/g, "")
    .replace(/-----END PRIVATE KEY-----/g, "")
    .replace(/\s/g, "");

  const keyData = Uint8Array.from(atob(pemBody), (c) => c.charCodeAt(0));

  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8",
    keyData,
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"]
  );

  // Sign
  const signature = await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" },
    cryptoKey,
    encoder.encode(signingInput)
  );

  const signatureB64 = base64url(new Uint8Array(signature));

  return `${headerB64}.${claimsB64}.${signatureB64}`;
}

Deno.serve(async (req: Request) => {
  try {
    const payload: PushPayload = await req.json();

    if (!payload.token || !payload.title) {
      return new Response(
        JSON.stringify({ error: "token and title are required" }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    const keyId = Deno.env.get("APNS_KEY_ID")!;
    const teamId = Deno.env.get("APNS_TEAM_ID")!;
    const bundleId = Deno.env.get("APNS_BUNDLE_ID")!;
    const privateKey = Deno.env.get("APNS_PRIVATE_KEY")!;

    // Create JWT for APNs
    const jwt = await createApnsJwt(keyId, teamId, privateKey);

    // APNs payload
    const apnsPayload = {
      aps: {
        alert: {
          title: payload.title,
          body: payload.body,
        },
        badge: payload.badge ?? 1,
        sound: payload.sound ?? "default",
        "mutable-content": 1,
      },
      ...payload.data,
    };

    // Use production APNs endpoint
    // For development/sandbox, use: api.sandbox.push.apple.com
    const apnsHost = "api.push.apple.com";
    const url = `https://${apnsHost}/3/device/${payload.token}`;

    const response = await fetch(url, {
      method: "POST",
      headers: {
        Authorization: `bearer ${jwt}`,
        "apns-topic": bundleId,
        "apns-push-type": "alert",
        "apns-priority": "10",
        "apns-expiration": "0",
        "Content-Type": "application/json",
      },
      body: JSON.stringify(apnsPayload),
    });

    if (response.status === 200) {
      return new Response(
        JSON.stringify({ success: true, apns_id: response.headers.get("apns-id") }),
        { status: 200, headers: { "Content-Type": "application/json", "Connection": "keep-alive" } }
      );
    } else {
      const errorBody = await response.text();
      console.error(`APNs error (${response.status}):`, errorBody);

      // If token is invalid, remove it from device_tokens
      if (response.status === 410 || response.status === 400) {
        const { createClient } = await import("jsr:@supabase/supabase-js@2");
        const supabase = createClient(
          Deno.env.get("SUPABASE_URL")!,
          Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
        );
        await supabase
          .from("device_tokens")
          .delete()
          .eq("token", payload.token);
      }

      return new Response(
        JSON.stringify({
          success: false,
          status: response.status,
          error: errorBody,
        }),
        { status: 502, headers: { "Content-Type": "application/json" } }
      );
    }
  } catch (error) {
    console.error("send-push-notification error:", error);
    return new Response(
      JSON.stringify({ error: (error as Error).message }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
});
```

---

## Cron Setup

Use `pg_cron` and `pg_net` to schedule the `schedule-reminders` function to run hourly.

### Step 1: Enable Extensions

```sql
-- These should already be available on Supabase
CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS pg_net;
```

### Step 2: Create Cron Job

```sql
-- Schedule reminders check every hour at minute 0
SELECT cron.schedule(
  'check-subscription-reminders',  -- job name
  '0 * * * *',                     -- every hour at :00
  $$
  SELECT net.http_post(
    url := 'https://fgcjijairsikaeshpiof.supabase.co/functions/v1/schedule-reminders',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key')
    ),
    body := '{}'::jsonb
  ) AS request_id;
  $$
);
```

### Step 3: Set Service Role Key for Cron

The cron job needs the service role key to call the edge function. Set it via the Supabase dashboard under **Database > Extensions > pg_cron**, or run:

```sql
ALTER DATABASE postgres SET app.settings.service_role_key = 'your-service-role-key';
```

### Managing Cron Jobs

```sql
-- List all cron jobs
SELECT * FROM cron.job;

-- Unschedule a job
SELECT cron.unschedule('check-subscription-reminders');

-- View job run history
SELECT * FROM cron.job_run_details
ORDER BY start_time DESC
LIMIT 20;
```

---

## Deployment

### Deploy Individual Function

```bash
# From project root
supabase functions deploy calculate-balance
supabase functions deploy schedule-reminders
supabase functions deploy send-push-notification --no-verify-jwt
```

Note: `send-push-notification` uses `--no-verify-jwt` because it is called internally by other edge functions and the cron job, not by client apps directly. It should validate the caller via service role key or internal header.

### Set Secrets

```bash
supabase secrets set \
  APNS_KEY_ID="XXXXXXXXXX" \
  APNS_TEAM_ID="XXXXXXXXXX" \
  APNS_BUNDLE_ID="com.yourcompany.SwissCoin" \
  APNS_PRIVATE_KEY="$(cat AuthKey_XXXXXXXXXX.p8)"
```

### Test Locally

```bash
# Start local Supabase
supabase start

# Serve functions locally
supabase functions serve

# Test calculate-balance
curl -X POST http://localhost:54321/functions/v1/calculate-balance \
  -H "Authorization: Bearer <user-jwt>" \
  -H "Content-Type: application/json" \
  -d '{"person_id": "uuid-here"}'

# Test schedule-reminders (no JWT needed — uses service role internally)
curl -X POST http://localhost:54321/functions/v1/schedule-reminders \
  -H "Authorization: Bearer <service-role-key>" \
  -H "Content-Type: application/json"
```

### Project Structure

```
supabase/
  functions/
    calculate-balance/
      index.ts
    schedule-reminders/
      index.ts
    send-push-notification/
      index.ts
```

---

## Error Handling

All edge functions follow consistent error response format:

```json
{
  "error": "Human-readable error message"
}
```

HTTP status codes:
- `200` — Success
- `400` — Bad request (missing/invalid parameters)
- `401` — Unauthorized (missing or invalid JWT)
- `404` — Resource not found
- `500` — Internal server error
- `502` — Upstream error (APNs failure)
