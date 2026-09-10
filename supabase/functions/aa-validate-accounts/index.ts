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

    const body = await request.json();
    const rawAccounts = Array.isArray(body?.accounts)
      ? body.accounts
      : Array.isArray(body?.emails)
        ? body.emails
        : [];
    const accounts = [...new Set(rawAccounts
      .map((value: unknown) => String(value).trim().toLowerCase())
      .filter((value: string) => value.length > 0)
    )];
    if (accounts.length === 0) throw new HttpError(400, "Missing accounts.");

    const { data: profiles, error: profileError } = await supabase
      .from("profiles")
      .select("id, email")
      .in("email", accounts);
    if (profileError) throw new Error(profileError.message);

    const matchedAccounts = new Set<string>();
    for (const profile of profiles) {
      matchedAccounts.add(profile.email.toLowerCase());
    }
    const missing = accounts.filter((account) => !matchedAccounts.has(account));

    return json({ accounts, missing });
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
