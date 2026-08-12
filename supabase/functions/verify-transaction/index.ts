import { createClient } from "npm:@supabase/supabase-js@2.45.4";
import { encodeBase64 } from "https://deno.land/std@0.224.0/encoding/base64.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

interface VerifyRequest {
  product_id: string;
  transaction_id: string;
  original_transaction_id: string;
  expiration_date?: string;
  purchase_date: string;
  is_active: boolean;
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // 1. 鉴权
    const authHeader = request.headers.get("Authorization") ?? "";
    const jwt = authHeader.replace("Bearer ", "");
    if (!jwt) throw new Error("Missing user authorization.");

    const supabaseURL = requiredEnv("SUPABASE_URL");
    const serviceRoleKey = requiredEnv("SERVICE_ROLE_KEY");
    const supabase = createClient(supabaseURL, serviceRoleKey);

    const { data: userData, error: userError } = await supabase.auth.getUser(jwt);
    if (userError || !userData.user) throw new Error("Invalid user session.");
    const userId = userData.user.id;

    // 2. 解析请求体
    const body = (await request.json()) as VerifyRequest;
    if (!body.product_id || !body.original_transaction_id) {
      throw new Error("Missing transaction info.");
    }

    // 3. （可选）调用 Apple App Store Server API 二次校验
    // 如果环境变量配置了 Apple 私钥，则进行服务端校验；否则信任 StoreKit 2 的本地验证结果
    let isActive = body.is_active;
    const appleVerified = await verifyWithApple(body.original_transaction_id);
    if (appleVerified !== null) {
      isActive = appleVerified;
    }

    const now = new Date().toISOString();
    const expirationDate = body.expiration_date
      ? new Date(body.expiration_date).toISOString()
      : null;

    // 4. 写入 subscriptions 表
    const { error: upsertError } = await supabase
      .from("subscriptions")
      .upsert(
        {
          user_id: userId,
          product_id: body.product_id,
          original_transaction_id: body.original_transaction_id,
          transaction_id: body.transaction_id,
          expires_at: expirationDate,
          is_active: isActive,
          updated_at: now,
        },
        { onConflict: "original_transaction_id" }
      );
    if (upsertError) throw new Error(upsertError.message);

    // 5. 更新 profiles.is_premium
    const { error: profileError } = await supabase
      .from("profiles")
      .update({ is_premium: isActive, updated_at: now })
      .eq("id", userId);
    if (profileError) throw new Error(profileError.message);

    return json({ success: true, is_premium: isActive });
  } catch (error) {
    return json(
      { error: error instanceof Error ? error.message : "Unknown error." },
      400
    );
  }
});

/**
 * 调用 Apple App Store Server API v2 校验原始交易 ID。
 * 返回 true/false 表示是否有效；如果未配置 Apple 密钥，返回 null，由调用方使用客户端结果。
 */
async function verifyWithApple(originalTransactionId: string): Promise<boolean | null> {
  const issuerId = Deno.env.get("APPLE_ISSUER_ID");
  const keyId = Deno.env.get("APPLE_KEY_ID");
  const privateKey = Deno.env.get("APPLE_PRIVATE_KEY");
  const bundleId = Deno.env.get("APPLE_BUNDLE_ID");

  if (!issuerId || !keyId || !privateKey || !bundleId) {
    console.log("Apple App Store Server API 未配置，跳过服务端校验");
    return null;
  }

  const token = await generateJWT(issuerId, keyId, privateKey);
  const url = `https://api.storekit.itunes.apple.com/inApps/v1/subscriptions/${originalTransactionId}`;

  try {
    const response = await fetch(url, {
      headers: { Authorization: `Bearer ${token}` },
    });

    if (!response.ok) {
      // 沙盒环境下 production 接口会返回 404，可回落到 sandbox
      if (response.status === 404) {
        const sandboxUrl = `https://api.storekit-sandbox.itunes.apple.com/inApps/v1/subscriptions/${originalTransactionId}`;
        const sandboxResponse = await fetch(sandboxUrl, {
          headers: { Authorization: `Bearer ${token}` },
        });
        if (!sandboxResponse.ok) {
          console.error("Apple sandbox API error:", sandboxResponse.status);
          return null;
        }
        const data = await sandboxResponse.json();
        return parseSubscriptionStatus(data);
      }
      console.error("Apple API error:", response.status);
      return null;
    }

    const data = await response.json();
    return parseSubscriptionStatus(data);
  } catch (error) {
    console.error("Apple API request failed:", error);
    return null;
  }
}

function parseSubscriptionStatus(data: unknown): boolean {
  if (typeof data !== "object" || data === null) return false;
  const d = data as Record<string, unknown>;
  const dataArr = d.data;
  if (!Array.isArray(dataArr) || dataArr.length === 0) return false;

  const item = dataArr[0] as Record<string, unknown>;
  // lastTransactions 中最近一条状态为 1 表示活跃订阅
  const lastTransactions = item.lastTransactions;
  if (!Array.isArray(lastTransactions) || lastTransactions.length === 0) return false;

  const last = lastTransactions[lastTransactions.length - 1] as Record<string, unknown>;
  return last.status === 1;
}

/**
 * 生成访问 App Store Server API 的 JWT
 */
async function generateJWT(issuerId: string, keyId: string, privateKey: string): Promise<string> {
  const header = { alg: "ES256", kid: keyId, typ: "JWT" };
  const now = Math.floor(Date.now() / 1000);
  const payload = {
    iss: issuerId,
    iat: now,
    exp: now + 1200, // 20 分钟
    aud: "appstoreconnect-v1",
    bid: Deno.env.get("APPLE_BUNDLE_ID"),
  };

  const encodedHeader = base64UrlEncode(JSON.stringify(header));
  const encodedPayload = base64UrlEncode(JSON.stringify(payload));
  const signingInput = `${encodedHeader}.${encodedPayload}`;

  const keyData = privateKey
    .replace(/-----BEGIN PRIVATE KEY-----/g, "")
    .replace(/-----END PRIVATE KEY-----/g, "")
    .replace(/\s/g, "");
  const binaryKey = Uint8Array.from(atob(keyData), (c) => c.charCodeAt(0));

  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8",
    binaryKey.buffer,
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"]
  );

  const signature = await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" },
    cryptoKey,
    new TextEncoder().encode(signingInput)
  );

  const encodedSignature = base64UrlEncode(new Uint8Array(signature));
  return `${signingInput}.${encodedSignature}`;
}

function base64UrlEncode(input: string | Uint8Array): string {
  let bytes: Uint8Array;
  if (typeof input === "string") {
    bytes = new TextEncoder().encode(input);
  } else {
    bytes = input;
  }
  return encodeBase64(bytes)
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "");
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
