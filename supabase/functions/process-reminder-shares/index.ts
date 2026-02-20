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

    const { reminder_ids } = await req.json();
    if (!reminder_ids || !Array.isArray(reminder_ids) || reminder_ids.length === 0) {
      return new Response(
        JSON.stringify({ processed: 0, participants_created: 0 }),
        { headers: { ...corsHeaders(), "Content-Type": "application/json" } }
      );
    }

    const serviceClient = createServiceClient();
    let processed = 0;
    let participantsCreated = 0;

    for (const reminderId of reminder_ids) {
      // Fetch reminder to find to_person
      const { data: reminder, error: remError } = await serviceClient
        .from("reminders")
        .select("to_person_id, amount, currency, message")
        .eq("id", reminderId)
        .maybeSingle();

      if (remError || !reminder || !reminder.to_person_id) {
        processed++;
        continue;
      }

      // Fetch phone hash for the recipient person
      const { data: person } = await serviceClient
        .from("persons")
        .select("phone_hash")
        .eq("id", reminder.to_person_id)
        .not("phone_hash", "is", null)
        .maybeSingle();

      if (!person || !person.phone_hash) {
        processed++;
        continue;
      }

      // Check if phone_hash matches a registered profile
      const { data: matchedProfile } = await serviceClient
        .from("profiles")
        .select("id")
        .eq("phone_hash", person.phone_hash)
        .maybeSingle();

      const toProfileId = matchedProfile?.id ?? null;

      // Create shared reminder record
      const { error: insertError } = await serviceClient
        .from("shared_reminders")
        .insert({
          from_profile_id: userId,
          to_profile_id: toProfileId,
          phone_hash: person.phone_hash,
          amount: reminder.amount || 0,
          currency: reminder.currency,
          message: reminder.message,
        });

      if (!insertError) {
        participantsCreated++;
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
