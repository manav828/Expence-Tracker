import { supabaseUrl, publicKey } from "./config.js";
const customer =
  location.pathname.startsWith("/membership") ||
  new URLSearchParams(location.search).get("view") === "membership";
const $ = (s) => document.querySelector(s);
const content = $("#content"),
  dialog = $("dialog");
let token = "",
  refreshToken = "",
  expires = 0,
  user = null,
  section = "",
  offset = 0,
  search = "",
  days = 30,
  revision = 0;
const money = (p) =>
  new Intl.NumberFormat("en-IN", { style: "currency", currency: "INR" }).format(
    Number(p) / 100,
  );
const date = (v) =>
  v ? new Date(v).toLocaleString("en-IN", { timeZone: "Asia/Kolkata" }) : "—";
function el(tag, text, cls) {
  const n = document.createElement(tag);
  if (text != null) n.textContent = text;
  if (cls) n.className = cls;
  return n;
}
function notice(msg = "") {
  const n = $("#notice");
  n.textContent = msg;
  n.hidden = !msg;
}
async function request(path, body, method) {
  if (
    refreshToken &&
    Date.now() > expires - 60000 &&
    !path.startsWith("/auth/v1/token")
  ) {
    const next = await request("/auth/v1/token?grant_type=refresh_token", {
      refresh_token: refreshToken,
    });
    session(next);
  }
  const r = await fetch(supabaseUrl + path, {
    method: method || (body ? "POST" : "GET"),
    headers: {
      apikey: publicKey,
      Authorization: "Bearer " + (token || publicKey),
      "Content-Type": "application/json",
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  const raw = await r.text();
  const result = raw ? JSON.parse(raw) : null;
  if (!r.ok)
    throw Error(
      result?.message ||
        result?.error_description ||
        result?.error ||
        "Request failed",
    );
  return result;
}
const rpc = (name, args = {}) => request("/rest/v1/rpc/" + name, args);
const rows = (table, query = "") =>
  request("/rest/v1/" + table + "?select=*" + query);
const billing = (action, params) =>
  request("/functions/v1/console-billing", { action, ...params });
const action = (kind, item) => rpc("console_action", { kind, item });
function button(text, fn, cls) {
  const b = el("button", text, cls);
  b.type = "button";
  b.onclick = async () => {
    b.disabled = true;
    try {
      await fn();
    } catch (e) {
      notice(e.message);
    } finally {
      b.disabled = false;
    }
  };
  return b;
}
function table(head, data) {
  const wrap = el("div", null, "sheet");
  if (!data.length) {
    wrap.append(el("p", "No matching records.", "card"));
    return wrap;
  }
  const t = el("table"),
    h = el("tr");
  for (const s of head) h.append(el("th", s));
  t.createTHead().append(h);
  const body = t.createTBody();
  for (const row of data) {
    const tr = el("tr");
    for (const val of row) {
      const cell = el("td");
      if (val instanceof Node) cell.append(val);
      else {
        cell.textContent = val ?? "—";
        if (String(val ?? "").length > 42) cell.className = "wrap";
      }
      tr.append(cell);
    }
    body.append(tr);
  }
  wrap.append(t);
  return wrap;
}
function metric(title, value) {
  const c = el("div", null, "metric");
  c.append(el("span", title), el("b", value));
  return c;
}
function select(values, chosen, change) {
  const s = el("select");
  for (const x of values) {
    const o = el("option", x);
    o.value = x;
    s.append(o);
  }
  s.value = chosen;
  s.onchange = () => change(s.value);
  return s;
}
function form(title, fields, save, label = "Save") {
  dialog.querySelector("h2").textContent = title;
  $("#fields").replaceChildren();
  $("#formError").textContent = "";
  $("#submit").textContent = label;
  for (const [key, name, type, val] of fields) {
    const l = el("label", name);
    let i;
    if (Array.isArray(type)) i = select(type, val || type[0], () => {});
    else {
      i = el(type === "textarea" ? "textarea" : "input");
      if (type !== "textarea") i.type = type;
      if (type === "password") i.autocomplete = "new-password";
      i.value = val ?? "";
      if (type === "number") {
        i.min = ["fees", "deposit"].includes(key) ? "0" : "0.01";
        i.step = "0.01";
      }
    }
    i.name = key;
    i.required = true;
    l.append(i);
    $("#fields").append(l);
  }
  $("#editor").onsubmit = async (e) => {
    e.preventDefault();
    $("#submit").disabled = true;
    $("#cancel").disabled = true;
    try {
      await save(Object.fromEntries(new FormData(e.target)));
      dialog.close();
      await refresh();
    } catch (err) {
      if (dialog.open) $("#formError").textContent = err.message;
      else notice(err.message);
    } finally {
      $("#submit").disabled = false;
      $("#cancel").disabled = false;
    }
  };
  dialog.showModal();
}
$("#cancel").onclick = () => dialog.close();
dialog.addEventListener("close", () => {
  for (const input of dialog.querySelectorAll('input[type="password"]')) {
    input.value = "";
  }
});
const localTime = (d) =>
  new Date(d.getTime() - d.getTimezoneOffset() * 60000)
    .toISOString()
    .slice(0, 16);
const future = (n) => localTime(new Date(Date.now() + n * 86400000));
function session(s) {
  token = s.access_token;
  refreshToken = s.refresh_token;
  expires = Date.now() + s.expires_in * 1000;
}
async function signin() {
  const box = el("form", null, "card login");
  const email = el("input"),
    pass = el("input");
  email.type = "email";
  email.autocomplete = "username";
  pass.type = "password";
  pass.autocomplete = "current-password";
  for (const [name, i] of [
    ["Account email", email],
    ["Password", pass],
  ]) {
    i.required = true;
    const l = el("label", name);
    l.append(i);
    box.append(l);
  }
  const submit = el("button", "Sign in", "primary");
  box.append(submit);
  content.replaceChildren(box);
  box.onsubmit = async (e) => {
    e.preventDefault();
    submit.disabled = true;
    try {
      const s = await request("/auth/v1/token?grant_type=password", {
        email: email.value,
        password: pass.value,
      });
      session(s);
      user = s.user;
      pass.value = "";
      if (customer) {
        await enter();
        return;
      }
      const factors = user.factors || [];
      let factor = factors.find(
        (f) => f.factor_type === "totp" && f.status === "verified",
      );
      if (!factor) {
        if (!(await rpc("console_is_listed")))
          throw Error("This account has no admin access.");
        factor = await request("/auth/v1/factors", {
          factor_type: "totp",
          friendly_name: "ExpenCircle " + Date.now(),
        });
      }
      const l = el("label", "Authenticator code"),
        code = el("input");
      code.inputMode = "numeric";
      code.autocomplete = "one-time-code";
      l.append(code);
      box.replaceChildren();
      if (factor.totp)
        box.append(
          el("p", "Add this setup key to your authenticator."),
          el("p", factor.totp.secret, "mono"),
        );
      box.append(
        l,
        button(
          "Verify",
          async () => {
            const ch = await request(
              "/auth/v1/factors/" + factor.id + "/challenge",
              {},
            );
            const v = await request(
              "/auth/v1/factors/" + factor.id + "/verify",
              { challenge_id: ch.id, code: code.value },
            );
            session(v);
            await enter();
          },
          "primary",
        ),
      );
      box.onsubmit = (e) => e.preventDefault();
    } catch (err) {
      notice(err.message);
    } finally {
      submit.disabled = false;
    }
  };
}
const pages = customer
  ? ["Membership", "Support"]
  : [
      "Overview",
      "Users",
      "Plans & pricing",
      "Payments",
      "Refunds",
      "Payment integration",
      "Settlements",
      "Messages",
      "Support",
      "Activity",
      "Settings",
    ];
async function enter() {
  if (!customer && !(await rpc("console_owner")))
    throw Error("Verified owner access required.");
  $("#identity").textContent = user.email;
  $("#logout").hidden = false;
  $("#workspace").textContent = customer ? "ACCOUNT" : "ADMIN WORKSPACE";
  $("nav").replaceChildren(
    ...pages.map((s) =>
      button(s, async () => {
        section = s;
        offset = 0;
        await refresh();
      }),
    ),
  );
  section = pages[0];
  await refresh();
}
$("#logout").onclick = async () => {
  try {
    await request("/auth/v1/logout?scope=local", {});
  } finally {
    if (customer && !refreshToken)
      localStorage.removeItem(
        "sb-" + new URL(supabaseUrl).hostname.split(".")[0] + "-auth-token",
      );
    location.reload();
  }
};
function pager(count) {
  const bar = el("div", null, "toolbar");
  if (offset)
    bar.append(
      button("Previous", () => {
        offset = Math.max(0, offset - 50);
        return refresh();
      }),
    );
  bar.append(el("span", "Page " + (offset / 50 + 1)));
  if (count === 50)
    bar.append(
      button("Next", () => {
        offset += 50;
        return refresh();
      }),
    );
  return bar;
}
async function refresh() {
  const seq = ++revision;
  notice();
  $("#title").textContent = section;
  $("#eyebrow").textContent = customer
    ? "EXPENCIRCLE ACCOUNT"
    : "EXPENCIRCLE ADMIN";
  for (const b of $("nav").children)
    b.classList.toggle("active", b.textContent === section);
  content.textContent = "Loading…";
  const out = el("div");
  try {
    await render(out);
    if (seq === revision) content.replaceChildren(out);
  } catch (e) {
    if (seq === revision) {
      content.replaceChildren(button("Try again", refresh));
      notice(e.message);
    }
  }
}
async function render(out) {
  const slice = "&limit=50&offset=" + offset;
  if (section === "Payment integration") {
    await renderPaymentIntegration(out);
    return;
  }
  if (section === "Overview") {
    const s = await rpc("console_sales", { days });
    const bar = el("div", null, "toolbar");
    bar.append(
      el("h2", "Sales overview"),
      select(["7", "30", "90"], String(days), (v) => {
        days = Number(v);
        refresh();
      }),
    );
    bar.lastChild.setAttribute("aria-label", "Period in days");
    out.append(bar);
    const gross = s.daily.reduce((a, d) => a + Number(d.paise), 0),
      grid = el("div", null, "grid");
    grid.append(
      metric("Gross collected · " + days + " days", money(gross)),
      metric("Completed refunds", money(s.refunded || 0)),
      metric("After refunds", money(gross - (s.refunded || 0))),
      metric("Active paying users", s.paid_users),
      metric("Recorded bank deposits", money(s.deposited || 0)),
      metric("Recorded gateway fees", money(s.fees || 0)),
    );
    out.append(grid);
    const chart = el("div", null, "card");
    chart.append(
      el("h2", "Daily collections · INR"),
      el("small", "Paid orders by date · India time"),
    );
    const max = Math.max(1, ...s.daily.map((d) => d.paise));
    for (const d of s.daily) {
      const row = el("div", null, "chartrow"),
        b = el("div", null, "bar");
      b.style.width = (100 * d.paise) / max + "%";
      row.append(el("span", d.day), b, el("b", money(d.paise)));
      chart.append(row);
    }
    if (!s.daily.length)
      chart.append(el("p", "No payments collected in this period."));
    out.append(
      chart,
      el("h2", "Plan sales"),
      table(
        ["Term", "Paid orders", "Gross collected"],
        s.terms.map((t) => [t.term, t.sales, money(t.paise)]),
      ),
      el("h2", "On-time prepaid renewals"),
      table(
        ["Terms due", "Renewed by expiry", "Renewal rate"],
        [
          [
            s.due_terms,
            s.renewed_terms,
            s.due_terms
              ? ((100 * s.renewed_terms) / s.due_terms).toFixed(1) + "%"
              : "—",
          ],
        ],
      ),
      el("h2", "Checkout activity"),
      table(
        ["Orders started", "Those orders paid", "Conversion"],
        [
          [
            s.started,
            s.converted,
            s.started
              ? ((100 * s.converted) / s.started).toFixed(1) + "%"
              : "—",
          ],
        ],
      ),
      button(s.pending_refunds + " pending refunds", () => {
        section = "Refunds";
        offset = 0;
        return refresh();
      }),
    );
    return;
  }
  if (section === "Settings") {
    const access = await rpc("membership_access");
    out.append(
      el("h2", "Web membership rollout"),
      el(
        "p",
        access.enabled
          ? "Checkout and Plus limits are enabled."
          : "Checkout and Plus limits are paused.",
      ),
      button(access.enabled ? "Pause rollout" : "Enable rollout", async () => {
        if (
          confirm(
            "Change checkout availability and web Plus limits for all accounts?",
          )
        ) {
          await action("rollout", { enabled: !access.enabled });
          await refresh();
        }
      }),
    );
    return;
  }
  if (section === "Users") {
    const list = await rpc("console_users", {
      search_text: search,
      page_offset: offset,
    });
    const bar = el("form", null, "toolbar"),
      q = el("input");
    q.placeholder = "Find by email or user ID";
    q.value = search;
    bar.append(q, el("button", "Search"));
    bar.onsubmit = (e) => {
      e.preventDefault();
      search = q.value.trim();
      offset = 0;
      refresh();
    };
    out.append(
      bar,
      table(
        ["Email", "Access", "Joined (IST)", "", ""],
        list.map((u) => [
          u.email,
          u.plan,
          date(u.joined_at),
          button("Profile", () => profile(u)),
          button("Change access", () =>
            form(
              u.email,
              [
                ["plan", "Access", ["Plus", "Free"], u.plan],
                ["until", "Override expires", "datetime-local", future(30)],
                ["reason", "Reason", "textarea"],
              ],
              async (f) =>
                action("access", {
                  ...f,
                  until: new Date(f.until).toISOString(),
                  id: u.user_id,
                }),
              "Apply override",
            ),
          ),
        ]),
      ),
      pager(list.length),
    );
    return;
  }
  if (section === "Plans & pricing") {
    const plans = await rows("plus_prices", "&order=term");
    out.append(
      table(
        ["Plus access", "Prepaid price", ""],
        plans.map((p) => [
          p.term,
          money(p.amount_paise),
          button("Edit price", () =>
            form(
              "Price for new purchases",
              [["amount", "Price in rupees", "number", p.amount_paise / 100]],
              (f) =>
                action("price", {
                  id: p.term,
                  paise: Math.round(f.amount * 100),
                }),
            ),
          ),
        ]),
      ),
    );
    return;
  }
  if (section === "Payments" || section === "Membership") {
    if (customer) {
      const plan = await rpc("console_plan", { uid: user.id });
      out.append(metric("Current access", plan));
      const access = await rpc("membership_access");
      const offers = !access.enabled
        ? []
        : await rows("plus_prices", "&order=term");
      for (const p of offers)
        out.append(
          button("Plus " + p.term + " · " + money(p.amount_paise), () =>
            form(
              "Buy prepaid Plus",
              [["phone", "Mobile number for checkout", "tel"]],
              (f) => checkout(p.term, f.phone),
              "Continue to payment",
            ),
          ),
        );
      out.append(
        el(
          "p",
          access.enabled
            ? "Prepaid access ends after one month or one year. Renew manually."
            : "Membership checkout is currently closed.",
        ),
      );
    }
    const list = await rows("billing_orders", "&order=created_at.desc" + slice);
    out.append(
      table(
        [
          "Order",
          "Term",
          "Amount",
          "Status",
          "Paid through (IST)",
          "Gateway",
          "",
        ],
        list.map((o) => [
          o.id,
          o.term,
          money(o.amount_paise),
          o.status,
          date(o.access_until),
          o.provider,
          o.status === "pending"
            ? button("Check payment", async () => {
                const r = await billing("verify", { order: o.id });
                await refresh();
                notice("Payment status: " + r.status);
              })
            : customer
              ? ""
              : button("Request refund", () =>
                  form(
                    "Refund " + money(o.amount_paise),
                    [
                      [
                        "amount",
                        "Refund amount (₹)",
                        "number",
                        o.amount_paise / 100,
                      ],
                      ["reason", "Reason", "textarea"],
                    ],
                    (f) =>
                      billing("refund", {
                        order: o.id,
                        paise: Math.round(f.amount * 100),
                        reason: f.reason,
                      }),
                    "Submit refund",
                  ),
                ),
        ]),
      ),
      pager(list.length),
    );
    return;
  }
  if (section === "Settlements") {
    const list = await rows(
      "billing_settlements",
      "&order=settled_on.desc" + slice,
    );
    out.append(
      button(
        "Record settlement",
        () =>
          form(
            "Record bank settlement",
            [
              ["id", "ExpenCircle paid order ID", "text"],
              ["reference", "Gateway settlement reference", "text"],
              ["fees", "Fees including fee tax (INR)", "number"],
              ["deposit", "Amount deposited for this order (INR)", "number"],
              [
                "date",
                "Bank settlement date",
                "date",
                new Date().toISOString().slice(0, 10),
              ],
            ],
            (f) =>
              action("settlement", {
                ...f,
                fees: Math.round(f.fees * 100),
                deposit: Math.round(f.deposit * 100),
              }),
          ),
        "primary",
      ),
      table(
        ["Bank date", "Reference", "Order", "Recorded fees", "Deposit"],
        list.map((x) => [
          x.settled_on,
          x.reference,
          x.order_id,
          money(x.fees_paise),
          money(x.deposit_paise),
        ]),
      ),
      pager(list.length),
    );
    return;
  }
  if (section === "Refunds") {
    const list = await rows(
      "billing_refunds",
      "&order=created_at.desc" + slice,
    );
    out.append(
      table(
        ["Order", "Amount", "Reason", "Status", "Requested (IST)", "", ""],
        list.map((r) => [
          r.order_id,
          money(r.amount_paise),
          r.reason,
          r.status,
          date(r.created_at),
          r.status === "pending"
            ? button("Check gateway", async () => {
                await billing("check_refund", {
                  order: r.order_id,
                  refund: r.id,
                });
                await refresh();
              })
            : "",
          r.status === "pending" && !r.gateway_id
            ? button("Retry submission", async () => {
                await billing("retry_refund", {
                  order: r.order_id,
                  refund: r.id,
                });
                await refresh();
              })
            : "",
        ]),
      ),
      pager(list.length),
    );
    return;
  }
  if (section === "Support") {
    if (customer)
      out.append(
        button(
          "Report an issue",
          () =>
            form(
              "Report an issue",
              [["description", "What happened?", "textarea"]],
              (f) => request("/rest/v1/support_tickets", f),
              "Send report",
            ),
          "primary",
        ),
      );
    const list = await rows(
      "support_tickets",
      "&order=created_at.desc" + slice,
    );
    out.append(
      table(
        ["Ticket", "User", "Issue", "Status", "Opened (IST)", ""],
        list.map((t) => [
          t.id,
          t.user_id,
          t.description,
          t.status,
          date(t.created_at),
          customer
            ? ""
            : button("Update", () =>
                form(
                  "Update support ticket",
                  [
                    [
                      "status",
                      "Status",
                      ["Open", "In progress", "Resolved"],
                      t.status,
                    ],
                  ],
                  (f) => action("ticket", { id: t.id, ...f }),
                ),
              ),
        ]),
      ),
      pager(list.length),
    );
    return;
  }
  if (section === "Messages") {
    out.append(
      button(
        "Compose message",
        () =>
          form(
            "Publish to the notification bell",
            [
              ["title", "Title", "text"],
              ["message", "Message", "textarea"],
              ["category", "Category", ["promo", "update", "tip"]],
              ["audience", "Audience", ["Everyone", "Free", "Plus"]],
              ["starts", "Publish at", "datetime-local", future(0)],
              ["expires", "Expires", "datetime-local", future(7)],
            ],
            async (f) => {
              const count = await rpc("console_audience_size", {
                segment: f.audience,
              });
              if (
                !confirm(
                  count +
                    " signed-in accounts match. Publish “" +
                    f.title +
                    "” to " +
                    f.audience +
                    "?",
                )
              )
                throw Error("Publication cancelled.");
              await action("publish", {
                ...f,
                starts: new Date(f.starts).toISOString(),
                expires: new Date(f.expires).toISOString(),
              });
            },
            "Review and publish",
          ),
        "primary",
      ),
    );
    const list = await rows(
      "app_notifications",
      "&order=created_at.desc" + slice,
    );
    out.append(
      table(
        ["Title", "Message", "Audience", "Starts (IST)", "Expires (IST)", ""],
        list.map((n) => [
          n.title,
          n.message,
          n.audience,
          date(n.starts_at),
          date(n.expires_at),
          n.is_active
            ? button("Withdraw", async () => {
                if (confirm("Withdraw this notification?")) {
                  await action("withdraw", { id: n.id });
                  await refresh();
                }
              })
            : "Withdrawn",
        ]),
      ),
      pager(list.length),
    );
    return;
  }
  const list = await rows("console_audit", "&order=id.desc" + slice);
  out.append(
    table(
      ["Time (IST)", "Action", "Target", "Details"],
      list.map((a) => [
        date(a.created_at),
        a.action,
        a.target,
        a.reason || JSON.stringify(a.details || {}),
      ]),
    ),
    pager(list.length),
  );
}
async function renderPaymentIntegration(out) {
  const gateways = await rpc("console_gateway_status");
  const intro = el("div", null, "card");
  intro.append(
    el("h2", "Checkout provider"),
    el(
      "p",
      "Save credentials for either provider, then select which one takes new payments.",
    ),
    el("small", "WEBHOOK URL"),
    el("p", supabaseUrl + "/functions/v1/console-payment-events", "mono"),
  );
  out.append(intro);

  const cards = el("div", null, "grid");
  for (const [provider, name] of [
    ["cashfree", "Cashfree"],
    ["razorpay", "Razorpay"],
  ]) {
    const saved = gateways.find((gateway) => gateway.provider === provider);
    const card = el("div", null, "card");
    const label = saved?.active
      ? "Active for new payments"
      : saved
        ? "Credentials saved"
        : "Setup required";
    card.append(el("small", label), el("h2", name));
    if (saved)
      card.append(
        el(
          "p",
          (saved.mode === "live" ? "Live" : "Sandbox") +
            " · Updated " +
            date(saved.updated_at),
        ),
      );
    card.append(
      button(
        saved ? "Replace credentials" : "Add credentials",
        () => {
          const cashfree = provider === "cashfree";
          const fields = [
            [
              "mode",
              "Environment",
              ["sandbox", "live"],
              saved?.mode || "sandbox",
            ],
            ["keyId", cashfree ? "App ID" : "Key ID", "text"],
            ["secret", cashfree ? "Secret key" : "Key secret", "password"],
          ];
          if (!cashfree) fields.push(["webhook", "Webhook secret", "password"]);
          form(name + " credentials", fields, async (values) => {
            try {
              await rpc("console_save_gateway", {
                gateway_provider: provider,
                gateway_mode: values.mode,
                key_id: values.keyId,
                api_secret: values.secret,
                webhook_secret: values.webhook || null,
              });
            } catch (error) {
              const expected = [
                "Check the credentials and selected environment",
                "Use a separate Supabase project to change environments after creating orders",
                "Owner access required",
              ];
              throw Error(
                expected.includes(error.message)
                  ? error.message
                  : "Could not save gateway credentials. Verify the admin setup and try again.",
              );
            }
          });
        },
        saved ? "" : "primary",
      ),
    );
    if (saved && !saved.active) {
      card.append(
        button("Use for new payments", async () => {
          if (
            !confirm("Use " + name + " (" + saved.mode + ") for new payments?")
          )
            return;
          await rpc("console_activate_gateway", { gateway_provider: provider });
          await refresh();
        }),
      );
    }
    cards.append(card);
  }
  out.append(cards);
}

async function profile(u) {
  const dbFilter = "&user_id=eq." + encodeURIComponent(u.user_id);
  const [orders, overrides, tickets] = await Promise.all([
    rows("billing_orders", dbFilter + "&order=created_at.desc&limit=25"),
    rows("plan_overrides", dbFilter),
    rows("support_tickets", dbFilter + "&order=created_at.desc&limit=25"),
  ]);
  $("#title").textContent = u.email;
  const out = el("div");
  out.append(
    button("Back to users", refresh),
    el("p", u.user_id, "mono"),
    metric("Current access", u.plan),
  );
  if (overrides.length) {
    const o = overrides[0];
    out.append(
      el("p", "Override: " + o.plan + " through " + date(o.until_at)),
      button("Remove override", () =>
        form(
          "Restore purchased access",
          [["reason", "Reason", "textarea"]],
          (f) => action("restore", { id: u.user_id, ...f }),
        ),
      ),
    );
  }
  out.append(
    el("h2", "Recent payments"),
    table(
      ["Order", "Provider", "Amount", "Status", "Paid through"],
      orders.map((o) => [
        o.id,
        o.provider,
        money(o.amount_paise),
        o.status,
        date(o.access_until),
      ]),
    ),
    el("h2", "Support history"),
    table(
      ["Description", "Status", "Opened"],
      tickets.map((t) => [t.description, t.status, date(t.created_at)]),
    ),
  );
  content.replaceChildren(out);
}
async function sdk(src) {
  const script = el("script");
  await new Promise((resolve, reject) => {
    script.onload = resolve;
    script.onerror = () => reject(Error("Checkout could not load"));
    script.src = src;
    document.head.append(script);
  });
}
async function checkout(term, phone) {
  const c = await billing("checkout", { term, phone });
  dialog.close();
  if (c.provider === "cashfree") {
    if (!window.Cashfree)
      await sdk("https://sdk.cashfree.com/js/v3/cashfree.js");
    await window
      .Cashfree({ mode: c.mode })
      .checkout({ paymentSessionId: c.session, redirectTarget: "_modal" });
  } else {
    if (!window.Razorpay)
      await sdk("https://checkout.razorpay.com/v1/checkout.js");
    await new Promise((resolve) =>
      new window.Razorpay({
        key: c.key,
        order_id: c.order,
        name: "ExpenCircle Plus",
        handler: resolve,
        modal: { ondismiss: resolve },
      }).open(),
    );
  }
  await billing("verify", { order: c.id });
}
document.title = customer ? "ExpenCircle · Membership" : "ExpenCircle · Admin";
async function start() {
  if (customer) {
    const storageKey =
      "sb-" + new URL(supabaseUrl).hostname.split(".")[0] + "-auth-token";
    try {
      const saved = JSON.parse(localStorage.getItem(storageKey) || "null");
      if (saved?.access_token && saved.expires_at > Date.now() / 1000 + 60) {
        token = saved.access_token;
        user = await request("/auth/v1/user");
        await enter();
        return;
      }
    } catch {
      token = "";
    }
  }
  await signin();
}
start();
