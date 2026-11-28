import { createClient } from "npm:@supabase/supabase-js@2.49.8";

import { getGatewayConfig } from "../_shared/gateway_config.ts";

// Deploy with --no-verify-jwt. Authentication here uses the gateway signature.
Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response(null, { status: 405 });
  const raw = await req.text();
  const cash = req.headers.has("x-webhook-signature");
  const provider = cash ? "cashfree" : "razorpay";
  const supplied = cash
    ? req.headers.get("x-webhook-signature")
    : req.headers.get("x-razorpay-signature");
  if (!supplied) return new Response(null, { status: 401 });
  const db = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );
  let secret: string;
  try {
    secret = (await getGatewayConfig(db, provider)).webhookSecret;
  } catch {
    return new Response(null, { status: 503 });
  }
  if (!secret) return new Response(null, { status: 401 });
  const enc = new TextEncoder();
  const key = await crypto.subtle.importKey(
    "raw",
    enc.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["verify"],
  );
  try {
    const sig = cash
      ? Uint8Array.from(atob(supplied), (x) => x.charCodeAt(0))
      : Uint8Array.from(supplied.match(/../g) ?? [], (x) => parseInt(x, 16));
    const payload = cash
      ? (req.headers.get("x-webhook-timestamp") ?? "") + raw
      : raw;
    if (!(await crypto.subtle.verify("HMAC", key, sig, enc.encode(payload))))
      return new Response(null, { status: 401 });
  } catch {
    return new Response(null, { status: 401 });
  }
  const event = JSON.parse(raw);
  const refund = cash ? event.data?.refund : event.payload?.refund?.entity;
  if (refund) {
    const state = cash ? refund.refund_status : refund.status;
    const status = ["SUCCESS", "processed"].includes(state)
      ? "processed"
      : ["FAILED", "CANCELLED", "failed"].includes(state)
        ? "failed"
        : null;
    if (status) {
      const rid = cash ? refund.refund_id : refund.receipt;
      if (!rid || !/^[0-9a-f-]{36}$/i.test(rid))
        return new Response("Untracked refund");
      const { error } = await db
        .from("billing_refunds")
        .update({ status, gateway_id: cash ? rid : refund.id })
        .eq("id", rid)
        .eq("status", "pending");
      if (error) return new Response(null, { status: 500 });
    }
    return new Response("OK");
  }
  const payment = cash ? event.data?.payment : event.payload?.payment?.entity;
  if (
    !payment ||
    (cash
      ? payment.payment_status !== "SUCCESS"
      : payment.status !== "captured")
  )
    return new Response("Ignored");
  const orderId = cash ? event.data.order.order_id : payment.order_id;
  const { data: o, error } = await db
    .from("billing_orders")
    .select("id,amount_paise")
    .eq("provider", provider)
    .eq("gateway_order", orderId)
    .maybeSingle();
  if (error || !o) return new Response("Order unavailable", { status: 503 });
  const amount = cash
    ? Math.round(payment.payment_amount * 100)
    : payment.amount;
  if (
    (cash ? payment.payment_currency : payment.currency) !== "INR" ||
    amount !== o.amount_paise
  )
    return new Response("Mismatch", { status: 400 });
  const { error: save } = await db.rpc("billing_capture", {
    order_key: o.id,
    payment_key: String(cash ? payment.cf_payment_id : payment.id),
    paid_paise: amount,
  });
  return new Response(save ? "Retry" : "OK", { status: save ? 500 : 200 });
});
