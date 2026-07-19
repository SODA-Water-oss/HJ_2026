import Stripe from "npm:stripe@16.12.0";
import { createClient } from "npm:@supabase/supabase-js@2.45.4";

Deno.serve(async (request) => {
  const stripe = new Stripe(requiredEnv("STRIPE_SECRET_KEY"), { apiVersion: "2024-06-20" });
  const signature = request.headers.get("stripe-signature");

  if (!signature) {
    return json({ error: "Missing Stripe signature." }, 400);
  }

  try {
    const body = await request.text();
    const event = await stripe.webhooks.constructEventAsync(
      body,
      signature,
      requiredEnv("STRIPE_WEBHOOK_SECRET"),
    );

    if (
      event.type === "customer.subscription.created" ||
      event.type === "customer.subscription.updated" ||
      event.type === "customer.subscription.deleted"
    ) {
      const subscription = event.data.object as Stripe.Subscription;
      const isPremium = subscription.status === "active" || subscription.status === "trialing";
      const customerId =
        typeof subscription.customer === "string" ? subscription.customer : subscription.customer.id;

      const supabase = createClient(
        requiredEnv("SUPABASE_URL"),
        requiredEnv("SUPABASE_SERVICE_ROLE_KEY"),
      );

      const { error } = await supabase
        .from("profiles")
        .update({ is_premium: isPremium })
        .eq("stripe_customer_id", customerId);

      if (error) {
        throw new Error(error.message);
      }
    }

    return json({ received: true });
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
    headers: { "Content-Type": "application/json" },
  });
}
