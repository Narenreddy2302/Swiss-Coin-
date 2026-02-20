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

    // Find all subscription participations for this user
    let query = serviceClient
      .from("subscription_participants")
      .select("id, subscription_id, status, role")
      .eq("profile_id", userId);

    if (since) {
      query = query.gte("updated_at", since);
    }

    const { data: participations, error: partError } = await query;

    if (partError || !participations || participations.length === 0) {
      return new Response(
        JSON.stringify({ shared_subscriptions: [] }),
        { headers: { ...corsHeaders(), "Content-Type": "application/json" } }
      );
    }

    const sharedSubscriptions = [];

    for (const participation of participations) {
      const subId = participation.subscription_id;

      // Fetch full subscription data
      const { data: sub } = await serviceClient
        .from("subscriptions")
        .select("*")
        .eq("id", subId)
        .maybeSingle();

      if (!sub) continue;

      // Fetch subscribers
      const { data: subscribers } = await serviceClient
        .from("subscription_subscribers")
        .select("person_id")
        .eq("subscription_id", subId);

      // Fetch payments
      const { data: payments } = await serviceClient
        .from("subscription_payments")
        .select("id, amount, payment_date, payer_id, note")
        .eq("subscription_id", subId);

      // Fetch settlements
      const { data: settlements } = await serviceClient
        .from("subscription_settlements")
        .select("id, amount, settlement_date, from_person_id, to_person_id, note")
        .eq("subscription_id", subId);

      // Fetch reminders
      const { data: reminders } = await serviceClient
        .from("subscription_reminders")
        .select("id, amount, due_date, to_person_id, note")
        .eq("subscription_id", subId);

      // Collect all person IDs
      const personIds = new Set<string>();
      for (const s of subscribers || []) {
        if (s.person_id) personIds.add(s.person_id);
      }
      for (const p of payments || []) {
        if (p.payer_id) personIds.add(p.payer_id);
      }
      for (const s of settlements || []) {
        if (s.from_person_id) personIds.add(s.from_person_id);
        if (s.to_person_id) personIds.add(s.to_person_id);
      }
      for (const r of reminders || []) {
        if (r.to_person_id) personIds.add(r.to_person_id);
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
      if (sub.owner_id) {
        const { data: creatorProfile } = await serviceClient
          .from("profiles")
          .select("id, display_name, avatar_url")
          .eq("id", sub.owner_id)
          .maybeSingle();

        if (creatorProfile) {
          creator = {
            id: creatorProfile.id,
            display_name: creatorProfile.display_name,
            photo_url: creatorProfile.avatar_url,
          };
        }
      }

      sharedSubscriptions.push({
        participation: {
          id: participation.id,
          status: participation.status,
          role: participation.role,
        },
        subscription: {
          id: sub.id,
          name: sub.name,
          amount: sub.amount,
          currency: sub.currency,
          frequency: sub.cycle,
          start_date: sub.start_date,
          end_date: sub.end_date,
          note: sub.notes,
          owner_id: sub.owner_id,
          is_shared: sub.is_shared,
          deleted_at: sub.deleted_at,
        },
        subscribers: (subscribers || []).map((s: any) => ({
          person_id: s.person_id,
        })),
        payments: (payments || []).map((p: any) => ({
          id: p.id,
          amount: p.amount,
          date: p.payment_date,
          payer_id: p.payer_id,
          note: p.note,
        })),
        settlements: (settlements || []).map((s: any) => ({
          id: s.id,
          amount: s.amount,
          date: s.settlement_date,
          from_person_id: s.from_person_id,
          to_person_id: s.to_person_id,
          note: s.note,
        })),
        reminders: (reminders || []).map((r: any) => ({
          id: r.id,
          amount: r.amount,
          due_date: r.due_date,
          to_person_id: r.to_person_id,
          note: r.note,
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
      JSON.stringify({ shared_subscriptions: sharedSubscriptions }),
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
