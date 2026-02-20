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

    const { subscription_ids } = await req.json();
    if (!subscription_ids || !Array.isArray(subscription_ids) || subscription_ids.length === 0) {
      return new Response(
        JSON.stringify({ processed: 0, participants_created: 0 }),
        { headers: { ...corsHeaders(), "Content-Type": "application/json" } }
      );
    }

    const serviceClient = createServiceClient();
    let processed = 0;
    let participantsCreated = 0;

    for (const subId of subscription_ids) {
      // Fetch subscribers for this subscription
      const { data: subscribers, error: subError } = await serviceClient
        .from("subscription_subscribers")
        .select("person_id")
        .eq("subscription_id", subId);

      if (subError || !subscribers || subscribers.length === 0) {
        processed++;
        continue;
      }

      const personIds = subscribers.map((s: any) => s.person_id).filter(Boolean);

      // Fetch phone hashes for subscriber persons
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
          .from("subscription_participants")
          .upsert(
            {
              subscription_id: subId,
              phone_hash: person.phone_hash,
              profile_id: profileId,
              status: "pending",
              role: "participant",
              source_owner_id: userId,
            },
            { onConflict: "subscription_id,phone_hash", ignoreDuplicates: true }
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
