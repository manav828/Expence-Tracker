import { PGlite } from "npm:@electric-sql/pglite@0.3.15";
import assert from "node:assert/strict";

Deno.test(
  "owner authorization, access overrides, captured sales and refunds",
  async () => {
    const db = new PGlite(),
      a = "10000000-0000-4000-8000-000000000001",
      b = "20000000-0000-4000-8000-000000000002";
    await db.exec(`create role anon; create role authenticated;create role service_role bypassrls; create schema auth;
create table auth.users(id uuid primary key,email text,created_at timestamptz default now());
create function auth.uid() returns uuid language sql stable as $$select nullif(current_setting('qa.uid',true),'')::uuid$$;
create function auth.jwt() returns jsonb language sql stable as $$select jsonb_build_object('aal',current_setting('qa.aal',true))$$;
grant usage on schema auth to authenticated,anon;
insert into auth.users(id,email) values ('${a}','a@example.com'),('${b}','b@example.com');`);
    let schema = await Deno.readTextFile("supabase_schema.sql");
    await db.exec(
      schema.slice(
        schema.indexOf("CREATE TABLE IF NOT EXISTS public.app_notifications"),
      ),
    );
    await db.exec(
      await Deno.readTextFile(
        "supabase/migrations/20261128000200_admin_console.sql",
      ),
    );
    await db.exec(
      `insert into admin_owners values('${a}'); set role authenticated;set qa.uid='${b}';set qa.aal='aal2';`,
    );
    await assert.rejects(db.query("select * from console_users()"));
    await assert.rejects(db.exec(`insert into admin_owners values('${b}')`));
    await db.exec(
      "insert into support_tickets(description) values('My billing issue')",
    );
    assert.equal(
      (await db.query("select * from support_tickets")).rows.length,
      1,
    );
    await db.exec(`set qa.uid='${a}';set qa.aal='aal1'`);
    await assert.rejects(db.query("select * from console_users()"));
    await db.exec("set qa.aal='aal2'");
    assert.equal(
      (await db.query("select * from console_users()")).rows.length,
      2,
    );
    await db.query("select console_action('access',$1::jsonb)", [
      JSON.stringify({
        id: b,
        plan: "Plus",
        until: "2099-01-01",
        reason: "Support credit",
      }),
    ]);
    assert.equal(
      (await db.query("select console_plan($1) p", [b])).rows[0].p,
      "Plus",
    );
    await db.query("select console_action('restore',$1::jsonb)", [
      JSON.stringify({ id: b, reason: "Expired credit" }),
    ]);
    await db.exec("reset role");
    const id = (
      await db.query(
        "insert into billing_orders(user_id,term,provider,amount_paise) values($1,'monthly','cashfree',5900) returning id",
        [b],
      )
    ).rows[0].id;
    await db.query("select billing_capture($1,'qa',5900)", [id]);
    await db.query("select billing_capture($1,'qa',5900)", [id]);
    await db.exec("set role authenticated");
    assert.equal(
      (await db.query("select console_sales(30) s")).rows[0].s.paid_users,
      1,
    );
    const rid = (
      await db.query(
        "select console_reserve_refund($1,5900,'Refund test') id",
        [id],
      )
    ).rows[0].id;
    await assert.rejects(
      db.query("select console_reserve_refund($1,5900,'Duplicate test')", [id]),
    );
    await db.exec("reset role");
    await db.query(
      "update billing_refunds set status='processed' where id=$1",
      [rid],
    );
    await db.exec("set role authenticated");
    const sales = (await db.query("select console_sales(30) s")).rows[0].s;
    assert.equal(sales.refunded, 5900);
    assert.equal(sales.paid_users, 0);

    // PGlite lacks the hosted Vault extension. Stub its SQL interface here.
    await db.exec(`reset role; create schema vault;
      create table vault.secrets(id uuid primary key default gen_random_uuid(), value text, name text unique);
      create view vault.decrypted_secrets as select id, value as decrypted_secret from vault.secrets;
      create function vault.create_secret(value text, name text) returns uuid language sql as
        $$insert into vault.secrets(value,name) values($1,$2) returning id$$;
      create function vault.update_secret(secret_id uuid, value text) returns void language sql as
        $$update vault.secrets set value=$2 where id=$1$$;`);
    const gatewayMigration = await Deno.readTextFile(
      "supabase/migrations/20261128000300_gateway_credentials.sql",
    );
    await db.exec(gatewayMigration.replace(/^create extension .*;$/m, ""));
    const saveGateway =
      "select console_save_gateway('cashfree','sandbox','fixture-id',$1,null)";
    await db.exec(`set role authenticated; set qa.uid='${b}';`);
    await assert.rejects(
      db.query(saveGateway, ["fixture-secret"]),
      /Owner access required/,
    );
    await assert.rejects(
      db.query("select console_gateway_status()"),
      /Owner access required/,
    );
    await db.exec(`set qa.uid='${a}'; set qa.aal='aal1';`);
    await assert.rejects(
      db.query(saveGateway, ["fixture-secret"]),
      /Owner access required/,
    );
    await db.exec("set qa.aal='aal2'");
    await db.query(saveGateway, ["fixture-secret"]);
    await assert.rejects(db.query("select billing_gateway_config('cashfree')"));
    await db.query("select console_activate_gateway('cashfree')");
    await db.query(saveGateway, ["replacement-secret"]);
    await db.query(
      "select console_save_gateway('razorpay','sandbox','rzp_test_fixture','fixture-key','fixture-webhook')",
    );
    await db.query("select console_activate_gateway('razorpay')");
    const status = (await db.query("select console_gateway_status() result"))
      .rows[0].result;
    assert.equal(
      status.filter((gateway) => gateway.active)[0].provider,
      "razorpay",
    );
    assert.equal(status.length, 2);
    assert.doesNotMatch(JSON.stringify(status), /secret|fixture/);
    assert.doesNotMatch(
      JSON.stringify((await db.query("select * from console_audit")).rows),
      /fixture-secret|replacement-secret|fixture-webhook/,
    );
    await assert.rejects(
      db.query(
        "select console_save_gateway('cashfree','live','fixture-id','fixture-secret',null)",
      ),
      /separate Supabase project/,
    );
    await db.exec("reset role; set role service_role");
    const chosen = (await db.query("select billing_gateway_config() result"))
      .rows[0].result;
    assert.equal(chosen.webhookSecret, "fixture-webhook");
    const old = (
      await db.query("select billing_gateway_config('cashfree') result")
    ).rows[0].result;
    assert.equal(old.apiSecret, "replacement-secret");
    await db.close();
  },
);
