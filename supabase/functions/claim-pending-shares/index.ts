import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import {
  createServiceClient,
  getUserId,
  corsHeaders,
} from "../_shared/supabase-client.ts";

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders() });
  }

  try {
    const userId = getUserId(req);
    if (!userId) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { ...corsHeaders(), "Content-Type": "application/json" },
      });
    }

    const serviceClient = createServiceClient();

    // Get caller's phone_hash from profiles
    const { data: profile, error: profileError } = await serviceClient
      .from("profiles")
      .select("phone_hash")
      .eq("id", userId)
      .maybeSingle();

    if (profileError || !profile || !profile.phone_hash) {
      return new Response(
        JSON.stringify({
          claimed_transactions: 0,
          claimed_settlements: 0,
          claimed_subscriptions: 0,
          claimed_reminders: 0,
          transaction_ids: [],
          settlement_ids: [],
          subscription_ids: [],
        }),
        { headers: { ...corsHeaders(), "Content-Type": "application/json" } }
      );
    }

    const phoneHash = profile.phone_hash;

    // Claim transaction participants
    const { data: claimedTxns } = await serviceClient
      .from("transaction_participants")
      .update({ profile_id: userId, updated_at: new Date().toISOString() })
      .eq("phone_hash", phoneHash)
      .is("profile_id", null)
      .select("transaction_id");

    const transactionIds = (claimedTxns || []).map(
      (r: any) => r.transaction_id
    );

    // Claim settlement participants
    const { data: claimedSetts } = await serviceClient
      .from("settlement_participants")
      .update({ profile_id: userId, updated_at: new Date().toISOString() })
      .eq("phone_hash", phoneHash)
      .is("profile_id", null)
      .select("settlement_id");

    const settlementIds = (claimedSetts || []).map(
      (r: any) => r.settlement_id
    );

    // Claim subscription participants
    const { data: claimedSubs } = await serviceClient
      .from("subscription_participants")
      .update({ profile_id: userId, updated_at: new Date().toISOString() })
      .eq("phone_hash", phoneHash)
      .is("profile_id", null)
      .select("subscription_id");

    const subscriptionIds = (claimedSubs || []).map(
      (r: any) => r.subscription_id
    );

    // Claim shared reminders
    const { data: claimedReminders } = await serviceClient
      .from("shared_reminders")
      .update({
        to_profile_id: userId,
        updated_at: new Date().toISOString(),
      })
      .eq("phone_hash", phoneHash)
      .is("to_profile_id", null)
      .select("id");

    return new Response(
      JSON.stringify({
        claimed_transactions: transactionIds.length,
        claimed_settlements: settlementIds.length,
        claimed_subscriptions: subscriptionIds.length,
        claimed_reminders: (claimedReminders || []).length,
        transaction_ids: transactionIds,
        settlement_ids: settlementIds,
        subscription_ids: subscriptionIds,
      }),
      { headers: { ...corsHeaders(), "Content-Type": "application/json" } }
    );
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      {
        status: 500,
        headers: { ...corsHeaders(), "Content-Type": "application/json" },
      }
    );
  }
});
