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

    // 2. 尝试获取/推测用户称呼（profiles.name > 昵称元数据 > 邮箱前缀），让点评更亲近
    const email = (userData.user.email ?? "").trim();
    const metaName = String(userData.user.user_metadata?.name ?? userData.user.user_metadata?.nickname ?? "").trim();
    const { data: profileRow } = await supabase
      .from("profiles")
      .select("name")
      .eq("id", userId)
      .maybeSingle();
    const profileName = String(profileRow?.name ?? "").trim();
    const userName = profileName || metaName || guessNameFromEmail(email);

    // 3. 查询最近收支（窗口近30天，但对外统一称“最近”，不暴露具体天数）
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
    const review = await generateReview(deepSeekKey, summary, userName);

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

// 从邮箱前缀推测一个自然称呼（拉丁字母首字母大写；纯数字/乱码则返回空）
function guessNameFromEmail(email: string): string {
  const prefix = (email.split("@")[0] ?? "").trim();
  if (!prefix) return "";
  const cleaned = prefix.replace(/[._\-]+/g, " ").replace(/\s+/g, " ").trim();
  if (!cleaned || /^[\d\s]+$/.test(cleaned)) return "";
  return cleaned
    .split(" ")
    .map((w) => w.charAt(0).toUpperCase() + w.slice(1))
    .join(" ");
}

async function generateReview(apiKey: string, summary: Record<string, unknown>, userName: string): Promise<string> {
  const prompt = [
    "你是一个爱写手帐、说话俏皮的记账达人，正在给用户写一段最近收支手帐点评。",
    userName
      ? `用户的称呼：${userName}（这是从邮箱/昵称推测的，未必是真名；如果合适就自然带进点评让语气更亲近，如果显得生硬就不要硬叫，直接用「你」）。`
      : "",
    "如果上面有用户称呼，点评中可自然地带上一两次（例如开头轻轻带一句），让语气更亲近；没有称呼则直接用「你」。",
    "根据下面的数据，写一段 30-45 字的中文点评（比之前更精简，只保留最有趣的一句精华）。",
    "要求：",
    "1. 主体全部使用正常中文文字，不要用 emoji 代替文字，也不要堆砌图标",
    "2. 最多在结尾加 1 个小表情表达态度，例如 🌱、✨、💪，不加也可以",
    "3. 精简俏皮、幽默善意，可以调侃消费习惯，但绝不低俗、不嘲讽、不伤害用户",
    "4. 数据自然融入，不罗列数字，可适度夸张；结尾给一点温暖鼓励",
    "5. 直接输出点评文本，用「你」称呼，不要引号、不要任何前缀、不要分点编号、不要解释",
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
