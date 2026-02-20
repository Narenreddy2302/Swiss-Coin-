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

    const { settlement_ids } = await req.json();
    if (!settlement_ids || !Array.isArray(settlement_ids) || settlement_ids.length === 0) {
      return new Response(
        JSON.stringify({ processed: 0, participants_created: 0 }),
        { headers: { ...corsHeaders(), "Content-Type": "application/json" } }
      );
    }

    const serviceClient = createServiceClient();
    let processed = 0;
    let participantsCreated = 0;

    for (const settlementId of settlement_ids) {
      // Fetch settlement to find from/to person IDs
      const { data: settlement, error: settError } = await serviceClient
        .from("settlements")
        .select("from_person_id, to_person_id")
        .eq("id", settlementId)
        .maybeSingle();

      if (settError || !settlement) continue;

      // Collect person IDs involved
      const personIds: string[] = [];
      if (settlement.from_person_id) personIds.push(settlement.from_person_id);
      if (settlement.to_person_id) personIds.push(settlement.to_person_id);

      if (personIds.length === 0) {
        processed++;
        continue;
      }

      // Fetch phone hashes for involved persons
      const { data: persons } = await serviceClient
        .from("persons")
        .select("id, phone_hash")
        .in("id", personIds)
        .not("phone_hash", "is", null);

      if (!persons || persons.length === 0) {
        processed++;
        continue;
      }

      for (const person of persons) {
        // Check if phone_hash matches a registered profile
        const { data: matchedProfile } = await serviceClient
          .from("profiles")
          .select("id")
          .eq("phone_hash", person.phone_hash)
          .maybeSingle();

        const profileId = matchedProfile?.id ?? null;

        const { error: insertError } = await serviceClient
          .from("settlement_participants")
          .upsert(
            {
              settlement_id: settlementId,
              phone_hash: person.phone_hash,
              profile_id: profileId,
              status: "pending",
              role: "participant",
              source_owner_id: userId,
            },
            { onConflict: "settlement_id,phone_hash", ignoreDuplicates: true }
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
