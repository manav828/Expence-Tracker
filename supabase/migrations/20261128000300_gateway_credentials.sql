begin;

create extension if not exists supabase_vault with schema vault;

create table public.billing_gateway_configs (
  provider text primary key check (provider in ('cashfree', 'razorpay')),
  mode text not null check (mode in ('sandbox', 'live')),
  secret_id uuid not null,
  active boolean not null default false,
  updated_at timestamptz not null default now()
);

alter table public.billing_gateway_configs enable row level security;
revoke all on public.billing_gateway_configs from public, anon, authenticated;
create unique index billing_one_active_gateway on public.billing_gateway_configs(active) where active;

create function public.console_gateway_status() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.console_owner() then raise exception 'Owner access required'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object(
    'provider', provider, 'mode', mode, 'active', active, 'updated_at', updated_at
  ) order by provider) from public.billing_gateway_configs), '[]'::jsonb);
end $$;

create function public.console_save_gateway(
  gateway_provider text, gateway_mode text, key_id text, api_secret text,
  webhook_secret text
) returns void language plpgsql security definer set search_path = '' as $$
declare
  existing public.billing_gateway_configs;
  vault_id uuid;
  credentials text;
begin
  if not public.console_owner() then raise exception 'Owner access required'; end if;
  if gateway_provider is null or gateway_provider not in ('cashfree', 'razorpay')
    or gateway_mode is null or gateway_mode not in ('sandbox', 'live')
    or coalesce(length(trim(key_id)), 0) not between 1 and 1024
    or coalesce(length(trim(api_secret)), 0) not between 1 and 1024
    or (gateway_provider = 'razorpay' and (
      coalesce(length(trim(webhook_secret)), 0) not between 1 and 1024
      or (gateway_mode = 'sandbox' and left(trim(key_id), 9) <> 'rzp_test_')
      or (gateway_mode = 'live' and left(trim(key_id), 9) <> 'rzp_live_')
    )) then
    raise exception 'Check the credentials and selected environment';
  end if;

  perform pg_advisory_xact_lock(981003);
  select * into existing from public.billing_gateway_configs where provider = gateway_provider;
  if existing.mode <> gateway_mode and exists (
    select 1 from public.billing_orders where provider = gateway_provider
  ) then
    raise exception 'Use a separate Supabase project to change environments after creating orders';
  end if;
  credentials := jsonb_build_object(
    'keyId', trim(key_id), 'apiSecret', trim(api_secret),
    'webhookSecret', case when gateway_provider = 'cashfree' then trim(api_secret) else trim(webhook_secret) end
  )::text;
  if existing.secret_id is null then
    vault_id := vault.create_secret(credentials, 'expencircle_gateway_' || gateway_provider);
  else
    vault_id := existing.secret_id;
    perform vault.update_secret(vault_id, credentials);
  end if;

  insert into public.billing_gateway_configs values (
    gateway_provider, gateway_mode, vault_id, coalesce(existing.active, false), now()
  ) on conflict (provider) do update set
    mode = excluded.mode, active = excluded.active, updated_at = excluded.updated_at;
  insert into public.console_audit(actor, action, target, details) values (
    auth.uid(), 'gateway_credentials_saved', gateway_provider,
    jsonb_build_object('mode', gateway_mode)
  );
end $$;

create function public.console_activate_gateway(gateway_provider text) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if not public.console_owner() then raise exception 'Owner access required'; end if;
  perform pg_advisory_xact_lock(981003);
  if not exists (select 1 from public.billing_gateway_configs where provider = gateway_provider) then
    raise exception 'Save credentials before activating this gateway';
  end if;
  update public.billing_gateway_configs set active = false where active;
  update public.billing_gateway_configs set active = true where provider = gateway_provider;
  insert into public.console_audit(actor, action, target)
    values (auth.uid(), 'gateway_activated', gateway_provider);
end $$;

create function public.billing_gateway_config(gateway_provider text default null) returns jsonb
language sql stable security definer set search_path = '' as $$
  select jsonb_build_object('provider', c.provider, 'mode', c.mode) || s.decrypted_secret::jsonb
  from public.billing_gateway_configs c
  join vault.decrypted_secrets s on s.id = c.secret_id
  where (gateway_provider is null and c.active) or c.provider = gateway_provider
$$;

revoke all on function public.billing_gateway_config(text) from public, anon, authenticated;
grant execute on function public.billing_gateway_config(text) to service_role;
revoke all on function public.console_gateway_status(), public.console_save_gateway(text,text,text,text,text),
  public.console_activate_gateway(text) from public, anon, authenticated;
grant execute on function public.console_gateway_status(), public.console_save_gateway(text,text,text,text,text),
  public.console_activate_gateway(text) to authenticated;

commit;
