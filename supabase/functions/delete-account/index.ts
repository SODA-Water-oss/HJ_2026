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

    // 1. 鉴权当前用户
    const authHeader = request.headers.get("Authorization") ?? "";
    const jwt = authHeader.replace("Bearer ", "");
    if (!jwt) throw new Error("Missing user authorization.");

    const supabase = createClient(supabaseURL, serviceRoleKey);
    const { data: userData, error: userError } = await supabase.auth.getUser(jwt);
    if (userError || !userData.user) throw new Error("Invalid user session.");
    const userId = userData.user.id;

    // 2. 删除该用户在业务表中的所有数据
    // 注意：删除顺序不影响，因为所有表都有 user_id 外键关联到 auth.users
    const tables = [
      "records",
      "user_settings",
      "bill_reminders",
      "user_logs",
      "feedbacks",
      "parse_usage",
      "profiles",
    ];

    for (const table of tables) {
      const { error } = await supabase
        .from(table)
        .delete()
        .eq("user_id", userId);
      if (error) {
        // 兼容旧数据库没有 feedbacks / parse_usage 表的情况
        if (error.message.includes("does not exist")) {
          console.warn(`Table ${table} does not exist, skipping.`);
          continue;
        }
        console.error(`Failed to delete from ${table}:`, error.message);
        throw new Error(`Failed to delete ${table}`);
      }
    }

    // 3. 删除 auth 用户（这会级联删除所有设置了 on delete cascade 的数据）
    const { error: deleteAuthError } = await supabase.auth.admin.deleteUser(userId);
    if (deleteAuthError) {
      console.error("Failed to delete auth user:", deleteAuthError.message);
      throw new Error("Failed to delete user account");
    }

    return json({ success: true, message: "Account deleted successfully." });
  } catch (error) {
    return json(
      { error: error instanceof Error ? error.message : "Unknown error." },
      400
    );
  }
});

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
