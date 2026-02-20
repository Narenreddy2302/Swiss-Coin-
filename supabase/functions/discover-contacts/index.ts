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

    const { hashed_phones } = await req.json();
    if (!hashed_phones || !Array.isArray(hashed_phones) || hashed_phones.length === 0) {
      return new Response(
        JSON.stringify({ matches: [] }),
        { headers: { ...corsHeaders(), "Content-Type": "application/json" } }
      );
    }

    const serviceClient = createServiceClient();

    // Query profiles where phone_hash matches any of the provided hashes
    // Exclude the caller's own profile
    const { data: profiles, error } = await serviceClient
      .from("profiles")
      .select("id, phone_hash, display_name, avatar_url")
      .in("phone_hash", hashed_phones)
      .neq("id", userId)
      .is("deleted_at", null);

    if (error) {
      throw error;
    }

    const matches = (profiles || []).map((p: any) => ({
      phone_hash: p.phone_hash,
      profile_id: p.id,
      display_name: p.display_name,
      photo_url: p.avatar_url,
    }));

    return new Response(
      JSON.stringify({ matches }),
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
