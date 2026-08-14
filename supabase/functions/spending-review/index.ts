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
    const deepSeekKey = Deno.env.get("DEEPSEEK_API_KEY");
    if (!deepSeekKey) throw new Error("Missing DEEPSEEK_API_KEY.");

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
    const review = await generateReview(deepSeekKey, summary);

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
    "你是一个爱写手帐、说话俏皮的记账达人，正在给用户写一段 30 天收支手帐点评。",
    "根据下面的数据，写一段 55-85 字的中文点评。",
    "要求：",
    "1. 精简俏皮，像手帐一样用 emoji 图标代替文字点缀，至少用 3-4 个（如 🚗交通 🌺犒劳自己 💦冲动消费 🙎纠结 等），让文字生动不枯燥",
    "2. 幽默善意，可以调侃消费习惯，但绝不低俗、不嘲讽、不伤害用户",
    "3. 把数据自然带进去，不罗列数字，可适度夸张",
    "4. 结尾给一点点温暖的鼓励",
    "5. 直接输出点评文本，用「你」称呼，不要引号、不要任何前缀、不要分点编号",
    "",
    "数据如下：",
    JSON.stringify(summary),
  ].join("\n");

  // 使用 DeepSeek（OpenAI 兼容接口），国内访问稳定
  const response = await fetch("https://api.deepseek.com/v1/chat/completions", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Authorization": `Bearer ${apiKey}`,
    },
    body: JSON.stringify({
      model: "deepseek-chat",
      messages: [
        { role: "system", content: "你是花计2046的轻松生活点评助手。" },
        { role: "user", content: prompt },
      ],
      temperature: 0.9,
      max_tokens: 300,
    }),
  });

  if (!response.ok) {
    throw new Error(`DeepSeek request failed: ${response.status}`);
  }

  const data = await response.json();
  const text = data?.choices?.[0]?.message?.content;
  if (typeof text !== "string" || text.trim().length === 0) {
    throw new Error("DeepSeek returned no text.");
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
