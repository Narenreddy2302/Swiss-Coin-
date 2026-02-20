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

    // Find all settlement participations for this user
    let query = serviceClient
      .from("settlement_participants")
      .select("id, settlement_id, status, role")
      .eq("profile_id", userId);

    if (since) {
      query = query.gte("updated_at", since);
    }

    const { data: participations, error: partError } = await query;

    if (partError || !participations || participations.length === 0) {
      return new Response(
        JSON.stringify({ shared_settlements: [] }),
        { headers: { ...corsHeaders(), "Content-Type": "application/json" } }
      );
    }

    const sharedSettlements = [];

    for (const participation of participations) {
      const settId = participation.settlement_id;

      // Fetch full settlement data
      const { data: settlement } = await serviceClient
        .from("settlements")
        .select("*")
        .eq("id", settId)
        .maybeSingle();

      if (!settlement) continue;

      // Collect person IDs
      const personIds = new Set<string>();
      if (settlement.from_person_id) personIds.add(settlement.from_person_id);
      if (settlement.to_person_id) personIds.add(settlement.to_person_id);

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
      if (settlement.owner_id) {
        const { data: creatorProfile } = await serviceClient
          .from("profiles")
          .select("id, display_name, avatar_url")
          .eq("id", settlement.owner_id)
          .maybeSingle();

        if (creatorProfile) {
          creator = {
            id: creatorProfile.id,
            display_name: creatorProfile.display_name,
            photo_url: creatorProfile.avatar_url,
          };
        }
      }

      sharedSettlements.push({
        participation: {
          id: participation.id,
          status: participation.status,
          role: participation.role,
        },
        settlement: {
          id: settlement.id,
          amount: settlement.amount,
          currency: settlement.currency,
          date: settlement.settlement_date,
          note: settlement.note,
          is_full_settlement: settlement.is_full_settlement,
          owner_id: settlement.owner_id,
          from_person_id: settlement.from_person_id,
          to_person_id: settlement.to_person_id,
          deleted_at: settlement.deleted_at,
        },
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
      JSON.stringify({ shared_settlements: sharedSettlements }),
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
