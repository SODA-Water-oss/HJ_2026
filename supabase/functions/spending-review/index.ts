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
    const geminiKey = Deno.env.get("GEMINI_API_KEY");
    if (!geminiKey) throw new Error("Missing GEMINI_API_KEY.");

    // 1. 鉴权
    const authHeader = request.headers.get("Authorization") ?? "";
    const jwt = authHeader.replace("Bearer ", "");
    if (!jwt) throw new Error("Missing user authorization.");

    const supabase = createClient(supabaseURL, serviceRoleKey);
    const { data: userData, error: userError } = await supabase.auth.getUser(jwt);
    if (userError || !userData.user) throw new Error("Invalid user session.");
    const userId = userData.user.id;

    // 2. 查询近 30 天收支
    const since = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString();
    const { data: records, error: recordsError } = await supabase
      .from("records")
      .select("type, amount, category, merchant, date")
      .eq("user_id", userId)
      .gte("date", since)
      .limit(500);
    if (recordsError) throw new Error(recordsError.message);

    // 3. 汇总趣味维度
    const summary = buildSummary(records ?? []);

    // 4. 调 Gemini 生成点评
    const review = await generateReview(geminiKey, summary);

    return json({ review });
  } catch (error) {
    return json(
      { error: error instanceof Error ? error.message : "Unknown error." },
      400
    );
  }
});

function buildSummary(records: Array<{ type: string; amount: number; category: string; merchant: string; date: string }>) {
  let expense = 0, income = 0, count = 0;
  let maxExpense = { amount: 0, merchant: "" };
  const catExpense: Record<string, number> = {};

  for (const r of records) {
    const amount = Number(r.amount) || 0;
    count++;
    if (r.type === "income") {
      income += amount;
    } else {
      expense += amount;
      catExpense[r.category || "其他"] = (catExpense[r.category || "其他"] || 0) + amount;
      if (amount > maxExpense.amount) {
        maxExpense = { amount, merchant: r.merchant || "" };
      }
    }
  }

  // 消费最多的类别
  const topCategory = Object.entries(catExpense).sort((a, b) => b[1] - a[1])[0]?.[0] ?? "无";
  const diningRatio = expense > 0 ? Math.round(((catExpense["餐饮"] ?? 0) / expense) * 100) : 0;
  const avgExpense = count > 0 ? Math.round(expense / count) : 0;

  return {
    days: 30,
    expense: Math.round(expense),
    income: Math.round(income),
    recordCount: count,
    maxExpenseMerchant: maxExpense.merchant || "无",
    maxExpenseAmount: maxExpense.amount,
    topCategory,
    diningRatio,
    avgExpense,
  };
}

async function generateReview(apiKey: string, summary: Record<string, unknown>): Promise<string> {
  const prompt = [
    "你是一位幽默风趣的财务生活观察员。根据用户近 30 天的收支数据，写一段 80-120 字的中文点评。",
    "硬性要求：",
    "1. 幽默风趣，让用户会心一笑，可用 1-2 个 emoji",
    "2. 语气温暖友好，善意调侃消费习惯；绝不可以伤害用户、贬低、嘲讽或人身攻击",
    "3. 如果数据少（没有记录或记录很少），就鼓励用户开始记账，同样要轻松有趣",
    "4. 直接输出点评文本，不要任何前缀或引号",
    "5. 用「你」称呼用户",
    "",
    "数据如下：",
    JSON.stringify(summary),
  ].join("\n");

  const response = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-pro:generateContent?key=${apiKey}`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        contents: [{ role: "user", parts: [{ text: prompt }] }],
        generationConfig: { temperature: 0.9, maxOutputTokens: 300 },
      }),
    }
  );

  if (!response.ok) {
    throw new Error(`Gemini request failed: ${response.status}`);
  }

  const data = await response.json();
  const text = data?.candidates?.[0]?.content?.parts?.[0]?.text;
  if (typeof text !== "string" || text.trim().length === 0) {
    throw new Error("Gemini returned no text.");
  }
  return text.trim();
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
