import type { SupabaseClient } from "npm:@supabase/supabase-js@2.49.8";

export type GatewayConfig = {
  provider: "cashfree" | "razorpay";
  mode: "sandbox" | "live";
  keyId: string;
  apiSecret: string;
  webhookSecret: string;
};

export async function getGatewayConfig(
  db: SupabaseClient,
  provider?: string,
): Promise<GatewayConfig> {
  const { data, error } = await db.rpc("billing_gateway_config", {
    gateway_provider: provider ?? null,
  });
  if (error) throw new Error("Payment configuration is unavailable");
  if (data) return data as GatewayConfig;

  // Preserve existing deployments until their owner saves credentials in Admin.
  const legacy = provider ?? Deno.env.get("BILLING_PROVIDER");
  if (legacy !== "cashfree" && legacy !== "razorpay") {
    throw new Error("Select a payment gateway in Admin");
  }
  const mode = Deno.env.get("BILLING_MODE") === "live" ? "live" : "sandbox";
  const cashfree = legacy === "cashfree";
  const apiSecret =
    Deno.env.get(cashfree ? "CASHFREE_SECRET" : "RAZORPAY_SECRET") ?? "";
  const keyId =
    Deno.env.get(cashfree ? "CASHFREE_APP_ID" : "RAZORPAY_KEY_ID") ?? "";
  return {
    provider: legacy,
    mode,
    keyId,
    apiSecret,
    webhookSecret: cashfree
      ? apiSecret
      : (Deno.env.get("RAZORPAY_WEBHOOK_SECRET") ?? ""),
  };
}
