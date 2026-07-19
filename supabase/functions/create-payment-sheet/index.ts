import Stripe from "npm:stripe@16.12.0";
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
    const stripeSecretKey = requiredEnv("STRIPE_SECRET_KEY");
    const supabaseURL = requiredEnv("SUPABASE_URL");
    const serviceRoleKey = requiredEnv("SUPABASE_SERVICE_ROLE_KEY");
    const priceId = requiredEnv("STRIPE_PRICE_ID");

    const authHeader = request.headers.get("Authorization") ?? "";
    const jwt = authHeader.replace("Bearer ", "");
    if (!jwt) {
      throw new Error("Missing user authorization.");
    }

    const supabase = createClient(supabaseURL, serviceRoleKey);
    const { data: userData, error: userError } = await supabase.auth.getUser(jwt);
    if (userError || !userData.user) {
      throw new Error("Invalid user session.");
    }

    const stripe = new Stripe(stripeSecretKey, { apiVersion: "2024-06-20" });
    const user = userData.user;

    const { data: profile, error: profileError } = await supabase
      .from("profiles")
      .select("id,email,stripe_customer_id")
      .eq("id", user.id)
      .single();

    if (profileError) {
      throw new Error(profileError.message);
    }

    let customerId = profile.stripe_customer_id as string | null;
    if (!customerId) {
      const customer = await stripe.customers.create({
        email: profile.email ?? user.email ?? undefined,
        metadata: { supabase_user_id: user.id },
      });
      customerId = customer.id;

      await supabase
        .from("profiles")
        .update({ stripe_customer_id: customerId })
        .eq("id", user.id);
    }

    const ephemeralKey = await stripe.ephemeralKeys.create(
      { customer: customerId },
      { apiVersion: "2024-06-20" },
    );

    const subscription = await stripe.subscriptions.create({
      customer: customerId,
      items: [{ price: priceId }],
      payment_behavior: "default_incomplete",
      payment_settings: { save_default_payment_method: "on_subscription" },
      expand: ["latest_invoice.payment_intent"],
      metadata: { supabase_user_id: user.id },
    });

    const invoice = subscription.latest_invoice;
    const paymentIntent =
      typeof invoice === "object" && invoice && "payment_intent" in invoice
        ? invoice.payment_intent
        : null;

    if (!paymentIntent || typeof paymentIntent !== "object" || !("client_secret" in paymentIntent)) {
      throw new Error("Stripe did not return a payment intent.");
    }

    return json({
      customerId,
      customerEphemeralKeySecret: ephemeralKey.secret,
      paymentIntentClientSecret: paymentIntent.client_secret,
    });
  } catch (error) {
    return json({ error: error instanceof Error ? error.message : "Unknown error." }, 400);
  }
});

function requiredEnv(name: string) {
  const value = Deno.env.get(name);
  if (!value) {
    throw new Error(`Missing ${name}.`);
  }
  return value;
}

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
