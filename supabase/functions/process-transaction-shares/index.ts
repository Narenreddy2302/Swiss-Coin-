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

    const { transaction_ids } = await req.json();
    if (!transaction_ids || !Array.isArray(transaction_ids) || transaction_ids.length === 0) {
      return new Response(
        JSON.stringify({ processed: 0, participants_created: 0 }),
        { headers: { ...corsHeaders(), "Content-Type": "application/json" } }
      );
    }

    const serviceClient = createServiceClient();
    let processed = 0;
    let participantsCreated = 0;

    for (const txnId of transaction_ids) {
      // Fetch splits for this transaction to find all involved persons
      const { data: splits, error: splitsError } = await serviceClient
        .from("transaction_splits")
        .select("owed_by_id")
        .eq("transaction_id", txnId);

      if (splitsError || !splits) continue;

      // Fetch payers for this transaction
      const { data: payers } = await serviceClient
        .from("transaction_payers")
        .select("paid_by_id")
        .eq("transaction_id", txnId);

      // Collect all involved person IDs (from splits and payers)
      const personIds = new Set<string>();
      for (const split of splits) {
        if (split.owed_by_id) personIds.add(split.owed_by_id);
      }
      if (payers) {
        for (const payer of payers) {
          if (payer.paid_by_id) personIds.add(payer.paid_by_id);
        }
      }

      // Fetch phone hashes for all involved persons
      const { data: persons } = await serviceClient
        .from("persons")
        .select("id, phone_hash")
        .in("id", Array.from(personIds))
        .not("phone_hash", "is", null);

      if (!persons || persons.length === 0) {
        processed++;
        continue;
      }

      for (const person of persons) {
        // Check if this phone_hash already matches a registered profile
        const { data: matchedProfile } = await serviceClient
          .from("profiles")
          .select("id")
          .eq("phone_hash", person.phone_hash)
          .maybeSingle();

        const profileId = matchedProfile?.id ?? null;

        // Insert participant record (idempotent via ON CONFLICT)
        const { error: insertError } = await serviceClient
          .from("transaction_participants")
          .upsert(
            {
              transaction_id: txnId,
              phone_hash: person.phone_hash,
              profile_id: profileId,
              status: profileId ? "pending" : "pending",
              role: "participant",
              source_owner_id: userId,
            },
            { onConflict: "transaction_id,phone_hash", ignoreDuplicates: true }
          );

        if (!insertError) {
          participantsCreated++;
        }
      }

      processed++;
    }

    return new Response(
      JSON.stringify({ processed, participants_created: participantsCreated }),
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
