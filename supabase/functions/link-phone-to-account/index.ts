/**
 * link-phone-to-account
 *
 * Two-step flow for linking a phone number to an Apple Sign-In account:
 *
 * Step 1 (confirm_merge = false):
 *   Check if the phone_hash already belongs to another active profile.
 *   - No conflict  → set phone + phone_hash on current profile → { action: "phone_set" }
 *   - Conflict found → return existing profile info → { action: "conflict" }
 *
 * Step 2 (confirm_merge = true):
 *   Call the atomic merge_accounts_by_phone() PostgreSQL function.
 *   → { action: "accounts_merged", data_transferred: { ... } }
 */

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import {
  createServiceClient,
  getUserId,
  corsHeaders,
} from "../_shared/supabase-client.ts";
import { hashPhoneNumber } from "../_shared/phone-hash.ts";

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders() });
  }

  try {
    const userId = getUserId(req);
    if (!userId) {
      return new Response(
        JSON.stringify({ error: "Unauthorized" }),
        {
          status: 401,
          headers: { ...corsHeaders(), "Content-Type": "application/json" },
        }
      );
    }

    const body = await req.json();
    const phone: string | undefined = body.phone;
    const phoneHash: string | undefined = body.phone_hash;
    const confirmMerge: boolean = body.confirm_merge === true;

    if (!phone || !phoneHash) {
      return new Response(
        JSON.stringify({ error: "phone and phone_hash are required" }),
        {
          status: 400,
          headers: { ...corsHeaders(), "Content-Type": "application/json" },
        }
      );
    }

    // Verify the phone_hash matches the phone (prevent spoofing)
    const expectedHash = await hashPhoneNumber(phone);
    if (expectedHash !== phoneHash) {
      return new Response(
        JSON.stringify({ error: "phone_hash does not match phone" }),
        {
          status: 400,
          headers: { ...corsHeaders(), "Content-Type": "application/json" },
        }
      );
    }

    const serviceClient = createServiceClient();

    // Check if phone_hash already exists on another active profile
    const { data: existingProfile } = await serviceClient
      .from("profiles")
      .select("id, display_name, phone_hash")
      .eq("phone_hash", phoneHash)
      .is("deleted_at", null)
      .neq("id", userId)
      .maybeSingle();

    if (!existingProfile) {
      // No conflict — set phone directly on current profile
      const { error: updateError } = await serviceClient
        .from("profiles")
        .update({
          phone_number: phone,
          phone_hash: phoneHash,
          phone_verified: true,
          updated_at: new Date().toISOString(),
        })
        .eq("id", userId);

      if (updateError) {
        return new Response(
          JSON.stringify({
            action: "error",
            merged: false,
            error: updateError.message,
          }),
          {
            status: 500,
            headers: { ...corsHeaders(), "Content-Type": "application/json" },
          }
        );
      }

      // Sync phone to auth.users so it appears in the Auth dashboard
      try {
        await serviceClient.auth.admin.updateUserById(userId, { phone });
      } catch (e) {
        console.warn("Failed to sync phone to auth.users:", e.message);
      }

      return new Response(
        JSON.stringify({
          action: "phone_set",
          merged: false,
        }),
        {
          headers: { ...corsHeaders(), "Content-Type": "application/json" },
        }
      );
    }

    // Conflict exists
    if (!confirmMerge) {
      // Step 1: just report the conflict — let client show confirmation UI
      return new Response(
        JSON.stringify({
          action: "conflict",
          merged: false,
          existing_profile_id: existingProfile.id,
          existing_display_name: existingProfile.display_name,
        }),
        {
          headers: { ...corsHeaders(), "Content-Type": "application/json" },
        }
      );
    }

    // Step 2: confirmed merge — call atomic merge function
    const { data: mergeResult, error: mergeError } = await serviceClient.rpc(
      "merge_accounts_by_phone",
      {
        p_survivor_id: userId,
        p_absorbed_id: existingProfile.id,
        p_phone: phone,
        p_phone_hash: phoneHash,
      }
    );

    if (mergeError) {
      return new Response(
        JSON.stringify({
          action: "error",
          merged: false,
          error: mergeError.message,
        }),
        {
          status: 500,
          headers: { ...corsHeaders(), "Content-Type": "application/json" },
        }
      );
    }

    // Check if the merge function returned an error
    if (mergeResult?.error) {
      return new Response(
        JSON.stringify({
          action: "error",
          merged: false,
          error: mergeResult.error,
        }),
        {
          status: 400,
          headers: { ...corsHeaders(), "Content-Type": "application/json" },
        }
      );
    }

    // Sync phone to auth.users for the survivor account
    try {
      await serviceClient.auth.admin.updateUserById(userId, { phone });
    } catch (e) {
      console.warn("Failed to sync phone to auth.users:", e.message);
    }

    return new Response(
      JSON.stringify({
        action: "accounts_merged",
        merged: true,
        data_transferred: mergeResult?.data_transferred,
      }),
      {
        headers: { ...corsHeaders(), "Content-Type": "application/json" },
      }
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
