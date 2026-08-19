import { createClient } from "npm:@supabase/supabase-js@2.45.4";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseURL = requiredEnv("SUPABASE_URL");
    const serviceRoleKey = requiredEnv("SERVICE_ROLE_KEY");
    const authHeader = request.headers.get("Authorization") ?? "";
    const jwt = authHeader.replace("Bearer ", "");
    if (!jwt) throw new HttpError(401, "Missing user authorization.");

    const supabase = createClient(supabaseURL, serviceRoleKey);
    const { data: userData, error: userError } = await supabase.auth.getUser(jwt);
    if (userError || !userData.user) throw new HttpError(401, "Invalid user session.");
    const userId = userData.user.id;

    const body = await request.json();
    const rawEmails = Array.isArray(body?.emails)
      ? body.emails
      : body?.email
        ? [body.email]
        : [];
    const emails = [...new Set(rawEmails
      .map((e: unknown) => String(e).trim().toLowerCase())
      .filter((e: string) => e.includes("@"))
    )];
    if (!body?.bill_id || emails.length === 0) {
      throw new HttpError(400, "Missing bill_id or email.");
    }

    const billId = String(body.bill_id);

    const { data: bill, error: billError } = await supabase
      .from("aa_bills")
      .select("id, creator_id")
      .eq("id", billId)
      .maybeSingle();
    if (billError || !bill) throw new HttpError(404, "Bill not found.");

    const { data: memberRows } = await supabase
      .from("aa_bill_members")
      .select("user_id")
      .eq("bill_id", billId);
    const isMember = (memberRows ?? []).some((m) => m.user_id === userId);
    if (bill.creator_id !== userId && !isMember) {
      throw new HttpError(403, "You are not a member of this bill.");
    }

    const { data: profiles, error: profileError } = await supabase
      .from("profiles")
      .select("id, email")
      .in("email", emails);
    if (profileError) throw new Error(profileError.message);
    if (!profiles || profiles.length === 0) {
      throw new HttpError(404, "No users found for the given emails.");
    }

    const rows = profiles.map((p) => ({
      bill_id: billId,
      user_id: p.id,
      email: p.email,
    }));

    const { data: members, error: insertError } = await supabase
      .from("aa_bill_members")
      .upsert(
        rows,
        { onConflict: "bill_id,user_id" }
      )
      .select()
    if (insertError) throw new Error(insertError.message);

    return json({ members });
  } catch (error) {
    if (error instanceof HttpError) {
      return json({ error: error.message }, error.status);
    }
    return json({ error: error instanceof Error ? error.message : "Unknown error." }, 400);
  }
});

class HttpError extends Error {
  status: number;
  constructor(status: number, message: string) {
    super(message);
    this.status = status;
  }
}

function requiredEnv(name: string): string {
  const value = Deno.env.get(name);
  if (!value) throw new Error(`Missing ${name}.`);
  return value;
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
