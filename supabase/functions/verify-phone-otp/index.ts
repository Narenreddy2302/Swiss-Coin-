/**
 * verify-phone-otp
 *
 * Verifies the 6-digit code sent to the user's phone via Twilio Verify.
 * On success, links the phone number to the user's profile.
 *
 * Request body:
 *   { "phone": "+1234567890", "code": "123456" }
 *
 * Response:
 *   { "success": true, "action": "phone_verified" | "accounts_merged" }
 *   { "success": false, "error": "..." }
 */

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import {
  createServiceClient,
  getUserId,
  corsHeaders,
} from "../_shared/supabase-client.ts";
import { hashPhoneNumber } from "../_shared/phone-hash.ts";

const TWILIO_ACCOUNT_SID = Deno.env.get("TWILIO_ACCOUNT_SID")!;
const TWILIO_AUTH_TOKEN = Deno.env.get("TWILIO_AUTH_TOKEN")!;
const TWILIO_VERIFY_SID = Deno.env.get("TWILIO_VERIFY_SID")!;

serve(async (req: Request) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders() });
  }

  try {
    // Require authenticated user
    const userId = getUserId(req);
    if (!userId) {
      return new Response(
        JSON.stringify({ success: false, error: "Unauthorized" }),
        {
          status: 401,
          headers: { ...corsHeaders(), "Content-Type": "application/json" },
        }
      );
    }

    // Validate Twilio credentials are configured
    if (!TWILIO_ACCOUNT_SID || !TWILIO_AUTH_TOKEN || !TWILIO_VERIFY_SID) {
      console.error("Twilio credentials not configured");
      return new Response(
        JSON.stringify({ success: false, error: "SMS service not configured" }),
        {
          status: 500,
          headers: { ...corsHeaders(), "Content-Type": "application/json" },
        }
      );
    }

    // Parse request body
    const body = await req.json();
    const phone: string | undefined = body.phone;
    const code: string | undefined = body.code;

    if (!phone || !code) {
      return new Response(
        JSON.stringify({ success: false, error: "Phone and code are required" }),
        {
          status: 400,
          headers: { ...corsHeaders(), "Content-Type": "application/json" },
        }
      );
    }

    // Validate code format (6 digits)
    if (!/^\d{6}$/.test(code)) {
      return new Response(
        JSON.stringify({ success: false, error: "Invalid code format" }),
        {
          status: 400,
          headers: { ...corsHeaders(), "Content-Type": "application/json" },
        }
      );
    }

    // Verify code via Twilio Verify API
    const twilioUrl = `https://verify.twilio.com/v2/Services/${TWILIO_VERIFY_SID}/VerificationCheck`;
    
    const twilioResponse = await fetch(twilioUrl, {
      method: "POST",
      headers: {
        "Content-Type": "application/x-www-form-urlencoded",
        "Authorization": "Basic " + btoa(`${TWILIO_ACCOUNT_SID}:${TWILIO_AUTH_TOKEN}`),
      },
      body: new URLSearchParams({
        To: phone,
        Code: code,
      }),
    });

    const twilioData = await twilioResponse.json();

    if (!twilioResponse.ok || twilioData.status !== "approved") {
      console.error("Twilio verification failed:", twilioData);
      
      // Handle specific errors
      if (twilioData.status === "pending") {
        return new Response(
          JSON.stringify({ success: false, error: "Incorrect code. Please try again." }),
          {
            status: 400,
            headers: { ...corsHeaders(), "Content-Type": "application/json" },
          }
        );
      }

      if (twilioData.code === 60202) {
        return new Response(
          JSON.stringify({ success: false, error: "Too many failed attempts. Request a new code." }),
          {
            status: 429,
            headers: { ...corsHeaders(), "Content-Type": "application/json" },
          }
        );
      }

      return new Response(
        JSON.stringify({ success: false, error: "Verification failed. Please try again." }),
        {
          status: 400,
          headers: { ...corsHeaders(), "Content-Type": "application/json" },
        }
      );
    }

    // Code verified! Now link the phone to the user's profile
    const serviceClient = createServiceClient();
    const phoneHash = await hashPhoneNumber(phone);

    // Check if phone_hash already exists on another active profile
    const { data: existingProfile } = await serviceClient
      .from("profiles")
      .select("id, display_name, phone_hash")
      .eq("phone_hash", phoneHash)
      .is("deleted_at", null)
      .neq("id", userId)
      .maybeSingle();

    if (existingProfile) {
      // Phone belongs to another account — need to merge
      // Call the merge function
      const { data: mergeResult, error: mergeError } = await serviceClient.rpc(
        "merge_accounts_by_phone",
        {
          p_survivor_id: userId,
          p_absorbed_id: existingProfile.id,
          p_phone: phone,
          p_phone_hash: phoneHash,
        }
      );

      if (mergeError || mergeResult?.error) {
        console.error("Merge failed:", mergeError || mergeResult?.error);
        return new Response(
          JSON.stringify({
            success: false,
            error: "Account linking failed. Please contact support.",
          }),
          {
            status: 500,
            headers: { ...corsHeaders(), "Content-Type": "application/json" },
          }
        );
      }

      // Sync phone to auth.users
      try {
        await serviceClient.auth.admin.updateUserById(userId, { phone });
      } catch (e) {
        console.warn("Failed to sync phone to auth.users:", e.message);
      }

      return new Response(
        JSON.stringify({
          success: true,
          action: "accounts_merged",
          merged_profile_name: existingProfile.display_name,
          data_transferred: mergeResult?.data_transferred,
        }),
        {
          headers: { ...corsHeaders(), "Content-Type": "application/json" },
        }
      );
    }

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
      console.error("Profile update failed:", updateError);
      return new Response(
        JSON.stringify({ success: false, error: "Failed to save phone number" }),
        {
          status: 500,
          headers: { ...corsHeaders(), "Content-Type": "application/json" },
        }
      );
    }

    // Sync phone to auth.users
    try {
      await serviceClient.auth.admin.updateUserById(userId, { phone });
    } catch (e) {
      console.warn("Failed to sync phone to auth.users:", e.message);
    }

    return new Response(
      JSON.stringify({
        success: true,
        action: "phone_verified",
      }),
      {
        headers: { ...corsHeaders(), "Content-Type": "application/json" },
      }
    );

  } catch (error) {
    console.error("verify-phone-otp error:", error);
    return new Response(
      JSON.stringify({ success: false, error: "Internal server error" }),
      {
        status: 500,
        headers: { ...corsHeaders(), "Content-Type": "application/json" },
      }
    );
  }
});
