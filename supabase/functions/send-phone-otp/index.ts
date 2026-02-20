/**
 * send-phone-otp
 *
 * Sends a 6-digit verification code to the user's phone via Twilio Verify.
 * Called after Apple Sign-In when user enters their phone number.
 *
 * Request body:
 *   { "phone": "+1234567890" }
 *
 * Response:
 *   { "success": true, "status": "pending" }
 *   { "success": false, "error": "..." }
 */

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { getUserId, corsHeaders } from "../_shared/supabase-client.ts";

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

    if (!phone) {
      return new Response(
        JSON.stringify({ success: false, error: "Phone number is required" }),
        {
          status: 400,
          headers: { ...corsHeaders(), "Content-Type": "application/json" },
        }
      );
    }

    // Validate E.164 format
    const e164Regex = /^\+[1-9]\d{6,14}$/;
    if (!e164Regex.test(phone)) {
      return new Response(
        JSON.stringify({ success: false, error: "Invalid phone number format" }),
        {
          status: 400,
          headers: { ...corsHeaders(), "Content-Type": "application/json" },
        }
      );
    }

    // Send verification code via Twilio Verify API
    const twilioUrl = `https://verify.twilio.com/v2/Services/${TWILIO_VERIFY_SID}/Verifications`;
    
    const twilioResponse = await fetch(twilioUrl, {
      method: "POST",
      headers: {
        "Content-Type": "application/x-www-form-urlencoded",
        "Authorization": "Basic " + btoa(`${TWILIO_ACCOUNT_SID}:${TWILIO_AUTH_TOKEN}`),
      },
      body: new URLSearchParams({
        To: phone,
        Channel: "sms",
      }),
    });

    const twilioData = await twilioResponse.json();

    if (!twilioResponse.ok) {
      console.error("Twilio error:", twilioData);
      
      // Handle specific Twilio errors
      if (twilioData.code === 60200) {
        return new Response(
          JSON.stringify({ success: false, error: "Invalid phone number" }),
          {
            status: 400,
            headers: { ...corsHeaders(), "Content-Type": "application/json" },
          }
        );
      }
      
      if (twilioData.code === 60203) {
        return new Response(
          JSON.stringify({ success: false, error: "Too many attempts. Please try again later." }),
          {
            status: 429,
            headers: { ...corsHeaders(), "Content-Type": "application/json" },
          }
        );
      }

      return new Response(
        JSON.stringify({ success: false, error: "Failed to send verification code" }),
        {
          status: 500,
          headers: { ...corsHeaders(), "Content-Type": "application/json" },
        }
      );
    }

    // Success
    return new Response(
      JSON.stringify({
        success: true,
        status: twilioData.status, // "pending"
      }),
      {
        headers: { ...corsHeaders(), "Content-Type": "application/json" },
      }
    );

  } catch (error) {
    console.error("send-phone-otp error:", error);
    return new Response(
      JSON.stringify({ success: false, error: "Internal server error" }),
      {
        status: 500,
        headers: { ...corsHeaders(), "Content-Type": "application/json" },
      }
    );
  }
});
