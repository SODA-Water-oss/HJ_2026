const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

type ParseRequest =
  | { mode: "text"; input: string }
  | { mode: "audio"; audioBase64: string; mimeType: string };

type ParsedExpense = {
  type: "expense" | "income";
  amount: number;
  category: string;
  merchant: string;
  note?: string | null;
};

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const apiKey = Deno.env.get("GEMINI_API_KEY");
    if (!apiKey) {
      throw new Error("Missing GEMINI_API_KEY.");
    }

    const payload = (await request.json()) as ParseRequest;
    const parsed = await parseWithGemini(apiKey, payload);

    return json({ items: parsed });
  } catch (error) {
    return json(
      { error: error instanceof Error ? error.message : "Unknown error." },
      400
    );
  }
});

async function parseWithGemini(
  apiKey: string,
  payload: ParseRequest
): Promise<ParsedExpense[]> {
  const parts: Record<string, unknown>[] = [
    {
      text: [
        "你是一个智能记账助手。请从用户输入中提取每一笔收支信息。",
        "只输出合法 JSON，结构如下：",
        '{"items":[{"type":"expense"或"income","amount":数字,"category":"类别","merchant":"商家名称","note":"备注(可选)"}]}',
        "所有字段必须使用中文，不要输出 markdown。",
        "支出类别从：餐饮,交通,购物,娱乐,住房,日用,服饰,通讯,医疗,教育,其他 中选择。",
        "收入类别从：工资,奖金,兼职,投资收益,理财,礼金,退款,其他 中选择。",
        "商家名称通常是金额前面的词，去掉金额和标点。",
        "支持多笔，每笔输出一项。",
      ].join("\n"),
    },
  ];

  if (payload.mode === "text") {
    parts.push({ text: `Input: ${payload.input}` });
  } else {
    parts.push({
      inline_data: {
        mime_type: payload.mimeType,
        data: payload.audioBase64,
      },
    });
  }

  const response = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-pro:generateContent?key=${apiKey}`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        contents: [{ role: "user", parts }],
        generationConfig: {
          responseMimeType: "application/json",
        },
      }),
    }
  );

  if (!response.ok) {
    throw new Error(`Gemini request failed: ${response.status}`);
  }

  const data = await response.json();
  const text = data?.candidates?.[0]?.content?.parts?.[0]?.text;
  if (typeof text !== "string") {
    throw new Error("Gemini returned no parsable text.");
  }

  const cleaned = text.replace(/```json|```/g, "").trim();
  const parsed = JSON.parse(cleaned) as { items?: ParsedExpense[] } | ParsedExpense[];

  // 兼容 Gemini 可能直接返回数组或 {items: [...]} 两种格式
  const items = Array.isArray(parsed) ? parsed : parsed.items;
  if (!Array.isArray(items) || items.length === 0) {
    throw new Error("Gemini returned no items.");
  }

  return items
    .map((item) => ({
      type: ["expense", "income"].includes(item.type) ? item.type : "expense",
      amount: Number.isFinite(item.amount) && item.amount > 0 ? item.amount : 0,
      category: item.category || "其他",
      merchant: item.merchant || "未知",
      note: item.note ?? null,
    }))
    .filter((item) => item.amount > 0);
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
