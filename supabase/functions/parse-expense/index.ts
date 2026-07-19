const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

type ParseRequest =
  | { mode: "text"; input: string }
  | { mode: "audio"; audioBase64: string; mimeType: string };

type ParsedExpense = {
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

    return json(parsed);
  } catch (error) {
    return json({ error: error instanceof Error ? error.message : "Unknown error." }, 400);
  }
});

async function parseWithGemini(apiKey: string, payload: ParseRequest): Promise<ParsedExpense> {
  const parts: Record<string, unknown>[] = [
    {
      text: [
        "Extract one expense from the user input.",
        "Return only valid JSON with these fields:",
        "amount as a number, category as a short label, merchant as a string, note as optional string.",
        "Use the user's language where practical. Do not include markdown.",
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
    },
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
  const parsed = JSON.parse(cleaned) as ParsedExpense;

  if (!Number.isFinite(parsed.amount) || parsed.amount <= 0) {
    throw new Error("Gemini returned an invalid amount.");
  }
  if (!parsed.category || !parsed.merchant) {
    throw new Error("Gemini returned incomplete expense data.");
  }

  return {
    amount: parsed.amount,
    category: parsed.category,
    merchant: parsed.merchant,
    note: parsed.note ?? null,
  };
}

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
