import { createClient } from "npm:@supabase/supabase-js@2.49.8";

import {
  getGatewayConfig,
  type GatewayConfig,
} from "../_shared/gateway_config.ts";

const env = (name: string) => {
  const value = Deno.env.get(name);
  if (!value) throw new Error("Missing configuration: " + name);
  return value;
};
const headers = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, apikey, content-type, x-client-info",
  "Content-Type": "application/json",
};
async function gateway(
  config: GatewayConfig,
  path: string,
  body?: object,
  key?: string,
) {
  if (!config.keyId || !config.apiSecret)
    throw new Error("Payment gateway credentials are missing");
  const cash = config.provider === "cashfree";
  const root = cash
    ? config.mode === "sandbox"
      ? "https://sandbox.cashfree.com/pg"
      : "https://api.cashfree.com/pg"
    : "https://api.razorpay.com/v1";
  const auth: Record<string, string> = cash
    ? {
        "x-api-version": "2023-08-01",
        "x-client-id": config.keyId,
        "x-client-secret": config.apiSecret,
      }
    : {
        Authorization: "Basic " + btoa(config.keyId + ":" + config.apiSecret),
      };
  if (key) auth[cash ? "x-idempotency-key" : "X-Refund-Idempotency"] = key;
  const res = await fetch(root + path, {
    method: body ? "POST" : "GET",
    headers: { ...auth, "Content-Type": "application/json" },
    body: body ? JSON.stringify(body) : undefined,
  });
  if (!res.ok)
    throw new Error(
      "Gateway request unsuccessful (" +
        res.status +
        "). Check the transaction before retrying.",
    );
  return await res.json();
}
Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { headers });
  const reply = (value: object, status = 200) =>
    new Response(JSON.stringify(value), { status, headers });
  try {
    const url = env("SUPABASE_URL");
    const userDb = createClient(url, env("SUPABASE_ANON_KEY"), {
      global: {
        headers: { Authorization: req.headers.get("authorization") ?? "" },
      },
    });
    const {
      data: { user },
    } = await userDb.auth.getUser(
      (req.headers.get("authorization") ?? "").replace(/^Bearer /i, ""),
    );
    if (!user) return reply({ error: "Sign in required" }, 401);
    const db = createClient(url, env("SUPABASE_SERVICE_ROLE_KEY"));
    const input = await req.json();
    const owner = (await userDb.rpc("console_owner")).data === true;
    if (input.action === "checkout") {
      const { data: settings, error: settingsError } = await db
        .from("billing_settings")
        .select("enabled")
        .eq("id", true)
        .single();
      if (settingsError || !settings.enabled)
        return reply({ error: "Membership checkout is currently closed" }, 409);
      const config = await getGatewayConfig(db);
      const provider = config.provider;
      if (provider === "cashfree" && !/^\d{10}$/.test(input.phone ?? ""))
        throw new Error("Enter a 10-digit phone number for Cashfree checkout");
      const { data: price, error } = await db
        .from("plus_prices")
        .select()
        .eq("term", input.term)
        .single();
      if (error) throw error;
      const { data: o, error: e } = await db
        .from("billing_orders")
        .insert({
          provider,
          term: price.term,
          user_id: user.id,
          amount_paise: price.amount_paise,
        })
        .select()
        .single();
      if (e) throw e;
      let checkout;
      let gatewayId;
      if (provider === "cashfree") {
        const order = await gateway(
          config,
          "/orders",
          {
            order_id: o.id,
            order_amount: o.amount_paise / 100,
            order_currency: "INR",
            customer_details: {
              customer_id: user.id,
              customer_phone: input.phone,
              customer_email: user.email,
            },
          },
          o.id,
        );
        checkout = {
          session: order.payment_session_id,
          mode: config.mode === "sandbox" ? "sandbox" : "production",
        };
        gatewayId = order.order_id;
      } else {
        const order = await gateway(config, "/orders", {
          amount: o.amount_paise,
          currency: "INR",
          receipt: o.id,
        });
        checkout = { key: config.keyId, order: order.id };
        gatewayId = order.id;
      }
      const { error: save } = await db
        .from("billing_orders")
        .update({ gateway_order: gatewayId })
        .eq("id", o.id);
      if (save) throw save;
      return reply({ provider, id: o.id, ...checkout });
    }
    const { data: o, error } = await db
      .from("billing_orders")
      .select()
      .eq("id", input.order)
      .single();
    if (error || (!owner && o.user_id !== user.id))
      return reply({ error: "Order unavailable" }, 404);
    if (input.action === "verify") {
      if (o.status === "paid") return reply({ status: "paid" });
      if (!o.gateway_order) return reply({ status: "pending" });
      const cash = o.provider === "cashfree";
      const config = await getGatewayConfig(db, o.provider);
      const result = await gateway(
        config,
        "/orders/" + encodeURIComponent(o.gateway_order) + "/payments",
      );
      const payments = cash ? result : result.items;
      const payment = payments.find((p: any) =>
        cash
          ? p.payment_status === "SUCCESS" &&
            p.payment_currency === "INR" &&
            Math.round(p.payment_amount * 100) === o.amount_paise
          : p.status === "captured" &&
            p.currency === "INR" &&
            p.amount === o.amount_paise &&
            p.order_id === o.gateway_order,
      );
      if (!payment) return reply({ status: "pending" });
      const { error: save } = await db.rpc("billing_capture", {
        order_key: o.id,
        payment_key: String(cash ? payment.cf_payment_id : payment.id),
        paid_paise: o.amount_paise,
      });
      if (save) throw save;
      return reply({ status: "paid" });
    }
    if (!owner) return reply({ error: "Owner required" }, 403);
    const config = await getGatewayConfig(db, o.provider);
    const cash = o.provider === "cashfree";
    const path = cash
      ? "/orders/" + o.gateway_order + "/refunds"
      : "/payments/" + o.payment_id + "/refund";
    if (input.action === "refund" || input.action === "retry_refund") {
      let id, amount, reason;
      if (input.action === "refund") {
        const { data: reservedId, error: reserve } = await userDb.rpc(
          "console_reserve_refund",
          { order_key: o.id, paise: input.paise, note: input.reason },
        );
        if (reserve) throw reserve;
        id = reservedId;
        amount = input.paise;
        reason = input.reason;
      } else {
        const { data: r, error } = await db
          .from("billing_refunds")
          .select()
          .eq("order_id", o.id)
          .eq("id", input.refund)
          .eq("status", "pending")
          .is("gateway_id", null)
          .single();
        if (error) throw error;
        id = r.id;
        amount = r.amount_paise;
        reason = r.reason;
      }
      const result = await gateway(
        config,
        path,
        cash
          ? {
              refund_amount: amount / 100,
              refund_id: id,
              refund_note: reason,
            }
          : { amount, receipt: id },
        id,
      );
      const { error: e } = await db
        .from("billing_refunds")
        .update({ gateway_id: cash ? id : result.id })
        .eq("id", id);
      if (e) throw e;
      return reply({ status: "pending", id });
    }
    if (input.action === "check_refund") {
      const { data: r, error: e } = await db
        .from("billing_refunds")
        .select()
        .eq("id", input.refund)
        .eq("order_id", o.id)
        .single();
      if (e) throw e;
      let result;
      if (cash) result = await gateway(config, path + "/" + r.id);
      else if (r.gateway_id)
        result = await gateway(config, "/refunds/" + r.gateway_id);
      else
        result = (
          await gateway(config, "/payments/" + o.payment_id + "/refunds")
        ).items.find((x: any) => x.receipt === r.id);
      if (!result) return reply({ status: "pending" });
      const state = cash ? result.refund_status : result.status;
      const status = ["SUCCESS", "processed"].includes(state)
        ? "processed"
        : ["FAILED", "CANCELLED", "failed"].includes(state)
          ? "failed"
          : "pending";
      const { error: save } = await db
        .from("billing_refunds")
        .update({ status, gateway_id: cash ? r.id : result.id })
        .eq("id", r.id)
        .eq("status", "pending");
      if (save) throw save;
      return reply({ status });
    }
    return reply({ error: "Unknown operation" }, 400);
  } catch (e) {
    return reply(
      {
        error:
          e instanceof Error
            ? e.message
            : "Unable to complete billing operation",
      },
      400,
    );
  }
});
