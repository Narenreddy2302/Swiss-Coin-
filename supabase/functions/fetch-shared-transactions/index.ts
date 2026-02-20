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

    const body = await req.json().catch(() => ({}));
    const since = body.since || null;

    const serviceClient = createServiceClient();

    // Find all transaction participations for this user
    let query = serviceClient
      .from("transaction_participants")
      .select("id, transaction_id, status, role")
      .eq("profile_id", userId);

    if (since) {
      query = query.gte("updated_at", since);
    }

    const { data: participations, error: partError } = await query;

    if (partError || !participations || participations.length === 0) {
      return new Response(
        JSON.stringify({ shared_transactions: [] }),
        { headers: { ...corsHeaders(), "Content-Type": "application/json" } }
      );
    }

    const sharedTransactions = [];

    for (const participation of participations) {
      const txnId = participation.transaction_id;

      // Fetch full transaction data
      const { data: txn } = await serviceClient
        .from("financial_transactions")
        .select("*")
        .eq("id", txnId)
        .maybeSingle();

      if (!txn) continue;

      // Fetch splits
      const { data: splits } = await serviceClient
        .from("transaction_splits")
        .select("id, owed_by_id, amount, raw_amount")
        .eq("transaction_id", txnId);

      // Fetch payers
      const { data: payers } = await serviceClient
        .from("transaction_payers")
        .select("id, paid_by_id, amount")
        .eq("transaction_id", txnId);

      // Collect all person IDs referenced
      const personIds = new Set<string>();
      if (txn.payer_id) personIds.add(txn.payer_id);
      if (txn.created_by_id) personIds.add(txn.created_by_id);
      for (const split of splits || []) {
        if (split.owed_by_id) personIds.add(split.owed_by_id);
      }
      for (const payer of payers || []) {
        if (payer.paid_by_id) personIds.add(payer.paid_by_id);
      }

      // Fetch person details
      let persons: any[] = [];
      if (personIds.size > 0) {
        const { data: personData } = await serviceClient
          .from("persons")
          .select("id, name, phone_number, photo_url, color_hex, linked_profile_id")
          .in("id", Array.from(personIds));
        persons = personData || [];
      }

      // Fetch creator profile
      let creator = null;
      if (txn.owner_id) {
        const { data: creatorProfile } = await serviceClient
          .from("profiles")
          .select("id, display_name, avatar_url")
          .eq("id", txn.owner_id)
          .maybeSingle();

        if (creatorProfile) {
          creator = {
            id: creatorProfile.id,
            display_name: creatorProfile.display_name,
            photo_url: creatorProfile.avatar_url,
          };
        }
      }

      sharedTransactions.push({
        participation: {
          id: participation.id,
          status: participation.status,
          role: participation.role,
        },
        transaction: {
          id: txn.id,
          title: txn.title,
          amount: txn.amount,
          currency: txn.currency,
          date: txn.date,
          split_method: txn.split_method,
          note: txn.note,
          owner_id: txn.owner_id,
          payer_id: txn.payer_id,
          created_by_id: txn.created_by_id,
          group_id: txn.group_id,
          is_shared: txn.is_shared,
          deleted_at: txn.deleted_at,
        },
        splits: (splits || []).map((s: any) => ({
          id: s.id,
          owed_by_id: s.owed_by_id,
          amount: s.amount,
          raw_amount: s.raw_amount,
        })),
        payers: (payers || []).map((p: any) => ({
          id: p.id,
          paid_by_id: p.paid_by_id,
          amount: p.amount,
        })),
        persons: persons.map((p: any) => ({
          id: p.id,
          name: p.name,
          phone_number: p.phone_number,
          photo_url: p.photo_url,
          color_hex: p.color_hex,
          linked_profile_id: p.linked_profile_id,
        })),
        creator,
      });
    }

    return new Response(
      JSON.stringify({ shared_transactions: sharedTransactions }),
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
