begin;
create table public.admin_owners (user_id uuid primary key references auth.users on delete cascade);
alter table public.admin_owners enable row level security;
revoke all on public.admin_owners from public,anon,authenticated;

create function public.console_owner() returns boolean language sql stable security definer set search_path='' as $$
 select coalesce(auth.jwt()->>'aal'='aal2',false) and exists(select from public.admin_owners where user_id=auth.uid())
$$;
create function public.console_is_listed() returns boolean language sql stable security definer set search_path='' as $$
 select exists(select from public.admin_owners where user_id=auth.uid())
$$;
create table public.billing_settings (id boolean primary key default true check(id), enabled boolean not null default false);
insert into public.billing_settings default values;
alter table public.billing_settings enable row level security;
revoke all on public.billing_settings from public,anon,authenticated;
grant select on public.billing_settings to service_role;
create table public.plus_prices (
 term text primary key check(term in ('monthly','yearly')), amount_paise integer not null check(amount_paise between 100 and 1000000)
);
insert into public.plus_prices values ('monthly',5900),('yearly',39900);
create table public.billing_orders (
 id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users, provider text not null check(provider in ('cashfree','razorpay')),
 term text not null references public.plus_prices, amount_paise int not null check(amount_paise>0), gateway_order text, payment_id text,
 status text not null default 'pending' check(status in ('pending','paid')), paid_at timestamptz, access_from timestamptz, access_until timestamptz,
 created_at timestamptz not null default now(), unique(provider,payment_id)
);
create table public.billing_refunds (
 id uuid primary key default gen_random_uuid(), order_id uuid not null references public.billing_orders, amount_paise int not null check(amount_paise>0),
 reason text not null, status text not null default 'pending' check(status in ('pending','processed','failed')), gateway_id text, processed_at timestamptz, created_at timestamptz default now()
);
create table public.billing_settlements (
 order_id uuid primary key references public.billing_orders, reference text not null,
 fees_paise integer not null check(fees_paise>=0), deposit_paise integer not null check(deposit_paise>=0), settled_on date not null
);
create table public.plan_overrides (
 user_id uuid primary key references auth.users, plan text not null check(plan in ('Free','Plus')), until_at timestamptz not null
);
create table public.support_tickets (
 id uuid primary key default gen_random_uuid(), user_id uuid not null default auth.uid() references auth.users,
 description text not null check(length(trim(description)) between 5 and 2000), status text not null default 'Open' check(status in ('Open','In progress','Resolved')),
 created_at timestamptz not null default now()
);
create table public.console_audit (
 id bigint generated always as identity primary key, actor uuid not null, action text not null, target text, reason text, details jsonb, created_at timestamptz default now()
);
do $$ declare t text; begin
 foreach t in array array['plus_prices','billing_settlements','billing_orders','billing_refunds','plan_overrides','support_tickets','console_audit'] loop
 execute format('alter table public.%I enable row level security',t);
 execute format('revoke all on public.%I from public,anon,authenticated',t);
 execute format('grant select on public.%I to authenticated',t);
 execute format('create policy admin_read on public.%I for select to authenticated using(public.console_owner())',t);
 end loop;
end $$;
create policy read_catalog on public.plus_prices for select to authenticated using(true);
create policy own_orders on public.billing_orders for select to authenticated using(user_id=auth.uid());
create policy own_tickets on public.support_tickets for select to authenticated using(user_id=auth.uid());
grant insert(description) on public.support_tickets to authenticated;
create policy submit_ticket on public.support_tickets for insert to authenticated with check(user_id=auth.uid());

create function public.console_plan(uid uuid) returns text language sql stable security definer set search_path='' as $$
 select case when uid=auth.uid() or public.console_owner() then coalesce(
 (select plan from public.plan_overrides where user_id=uid and until_at>now()),
 (select 'Plus' from public.billing_orders o where user_id=uid and access_from<=now() and access_until>now()
 and amount_paise>(select coalesce(sum(r.amount_paise),0) from public.billing_refunds r where r.order_id=o.id and r.status='processed') limit 1),'Free') end
$$;
create function public.console_users(search_text text default '',page_offset integer default 0)
returns table(user_id uuid,email text,plan text,joined_at timestamptz) language plpgsql stable security definer set search_path='' as $$
begin
 if not public.console_owner() then raise exception 'Owner access required'; end if;
 return query select u.id,u.email::text,public.console_plan(u.id),u.created_at from auth.users u
 where u.email ilike '%'||search_text||'%' or u.id::text=search_text order by u.created_at desc,u.id limit 50 offset greatest(page_offset,0);
end $$;

alter table public.app_notifications add column if not exists audience text not null default 'Everyone' check(audience in ('Everyone','Free','Plus'));
drop policy if exists "Anyone signed in or anon can read active notifications" on public.app_notifications;
create policy visible_announcements on public.app_notifications for select using (
 public.console_owner() or (is_active and starts_at<=now() and (expires_at is null or expires_at>now()) and
 (audience='Everyone' or (auth.uid() is not null and audience=public.console_plan(auth.uid())))));
revoke insert,update,delete,truncate on public.app_notifications from public,anon,authenticated;
create function public.console_action(kind text, item jsonb) returns void language plpgsql security definer set search_path='' as $$
declare target text:=item->>'id'; note text:=trim(item->>'reason');
begin
 if not public.console_owner() then raise exception 'Owner access required'; end if;
 case kind
 when 'access' then
 if coalesce(length(note),0)<3 or (item->>'until')::timestamptz<=now() then raise exception 'Future expiry and reason required'; end if;
 insert into public.plan_overrides values(target::uuid,item->>'plan',(item->>'until')::timestamptz)
 on conflict(user_id) do update set plan=excluded.plan,until_at=excluded.until_at;
 when 'settlement' then
 if not exists(select from public.billing_orders where id=target::uuid and status='paid') then raise exception 'Paid order required'; end if;
 insert into public.billing_settlements values(target::uuid,item->>'reference',(item->>'fees')::int,(item->>'deposit')::int,(item->>'date')::date)
 on conflict(order_id) do update set reference=excluded.reference,fees_paise=excluded.fees_paise,deposit_paise=excluded.deposit_paise,settled_on=excluded.settled_on;
 when 'rollout' then update public.billing_settings set enabled=(item->>'enabled')::boolean where id;
 when 'restore' then
 if coalesce(length(note),0)<3 then raise exception 'Reason required'; end if;
 delete from public.plan_overrides where user_id=target::uuid;
 when 'price' then update public.plus_prices set amount_paise=(item->>'paise')::int where term=target;
 when 'ticket' then update public.support_tickets set status=item->>'status' where id=target::uuid;
 when 'publish' then
 if coalesce(length(trim(item->>'title')),0)=0 or coalesce(length(trim(item->>'message')),0)=0 or
 (item->>'expires')::timestamptz<=(item->>'starts')::timestamptz then raise exception 'Check message and schedule'; end if;
 target:=gen_random_uuid()::text;
 insert into public.app_notifications(id,title,message,category,audience,starts_at,expires_at)
 values(target,item->>'title',item->>'message',item->>'category',item->>'audience',(item->>'starts')::timestamptz,(item->>'expires')::timestamptz);
 when 'withdraw' then update public.app_notifications set is_active=false where id=target;
 else raise exception 'Unknown action'; end case;
 insert into public.console_audit(actor,action,target,reason,details) values(auth.uid(),kind,target,note,item);
end $$;

create function public.billing_capture(order_key uuid, payment_key text, paid_paise integer) returns void language plpgsql security definer set search_path='' as $$
declare o public.billing_orders; start_date timestamptz;
begin
 select * into strict o from public.billing_orders where id=order_key for update;
 if o.amount_paise<>paid_paise then raise exception 'Amount mismatch'; end if;
 if o.status='paid' then return; end if;
 perform pg_advisory_xact_lock(hashtextextended(o.user_id::text,1));
 select greatest(now(),coalesce(max(access_until),now())) into start_date from public.billing_orders b where b.user_id=o.user_id and status='paid'
 and b.amount_paise>(select coalesce(sum(r.amount_paise),0) from public.billing_refunds r where r.order_id=b.id and r.status='processed');
 update public.billing_orders set status='paid',paid_at=now(),access_from=start_date,
 access_until=start_date+case o.term when 'yearly' then interval '1 year' else interval '1 month' end,payment_id=payment_key where id=o.id;
end $$;
revoke all on function public.billing_capture(uuid,text,integer) from public,anon,authenticated;
grant execute on function public.billing_capture(uuid,text,integer) to service_role;

create function public.console_reserve_refund(order_key uuid,paise int,note text) returns uuid language plpgsql security definer set search_path='' as $$
declare o public.billing_orders; reserved int; rid uuid;
begin
 if not public.console_owner() then raise exception 'Owner access required'; end if;
 select * into strict o from public.billing_orders where id=order_key for update;
 select coalesce(sum(amount_paise),0) into reserved from public.billing_refunds where order_id=o.id and status<>'failed';
 if o.status<>'paid' or paise<=0 or paise>o.amount_paise-reserved or coalesce(length(trim(note)),0)<3 then raise exception 'Invalid refund amount or reason'; end if;
 insert into public.billing_refunds(order_id,amount_paise,reason) values(o.id,paise,note) returning id into rid;
 insert into public.console_audit(actor,action,target,reason) values(auth.uid(),'refund',rid::text,note);
 return rid;
end $$;
create function public.console_sales(days integer) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare since_date date:=(now() at time zone 'Asia/Kolkata')::date-least(greatest(days,1),366)+1;
begin
 if not public.console_owner() then raise exception 'Owner access required'; end if;
 return (select jsonb_build_object('daily',coalesce(jsonb_agg(to_jsonb(d) order by d.day),'[]'::jsonb)) from (
 select (paid_at at time zone 'Asia/Kolkata')::date as day,sum(amount_paise) paise,count(*) sales from public.billing_orders
 where status='paid' and paid_at>=since_date::timestamp at time zone 'Asia/Kolkata' group by 1) d)
 ||jsonb_build_object('paid_users',(select count(distinct user_id) from public.billing_orders o where access_from<=now() and access_until>now() and amount_paise>(select coalesce(sum(amount_paise),0) from public.billing_refunds where order_id=o.id and status='processed')),
 'deposited',(select coalesce(sum(deposit_paise),0) from public.billing_settlements where settled_on>=since_date),
 'fees',(select coalesce(sum(fees_paise),0) from public.billing_settlements where settled_on>=since_date),
 'due_terms',(select count(*) from public.billing_orders b where access_until>=since_date::timestamp at time zone 'Asia/Kolkata' and access_until<=now()
 and amount_paise>(select coalesce(sum(amount_paise),0) from public.billing_refunds where order_id=b.id and status='processed')),
 'renewed_terms',(select count(*) from public.billing_orders b where access_until>=since_date::timestamp at time zone 'Asia/Kolkata' and access_until<=now()
 and amount_paise>(select coalesce(sum(amount_paise),0) from public.billing_refunds where order_id=b.id and status='processed')
 and exists(select from public.billing_orders next_term where next_term.user_id=b.user_id and next_term.access_from=b.access_until
 and next_term.amount_paise>(select coalesce(sum(amount_paise),0) from public.billing_refunds where order_id=next_term.id and status='processed'))),
 'terms',(select coalesce(jsonb_agg(to_jsonb(t)),'[]'::jsonb) from (select term,count(*) sales,sum(amount_paise) paise from public.billing_orders where status='paid' and paid_at>=since_date::timestamp at time zone 'Asia/Kolkata' group by term) t),
 'started',(select count(*) from public.billing_orders where created_at>=since_date::timestamp at time zone 'Asia/Kolkata'),
 'converted',(select count(*) from public.billing_orders where status='paid' and created_at>=since_date::timestamp at time zone 'Asia/Kolkata'),
 'refunded',(select coalesce(sum(amount_paise),0) from public.billing_refunds where status='processed' and processed_at>=since_date::timestamp at time zone 'Asia/Kolkata'),
 'open_tickets',(select count(*) from public.support_tickets where status<>'Resolved'),'pending_refunds',(select count(*) from public.billing_refunds where status='pending'));
end $$;
create function public.record_refund_time() returns trigger language plpgsql set search_path='' as $$
begin
 if new.status='processed' and old.processed_at is null then new.processed_at:=now(); end if;
 return new;
end $$;
create trigger set_refund_time before update on public.billing_refunds for each row execute function public.record_refund_time();
grant all on public.billing_orders,public.billing_refunds,public.plus_prices to service_role;
create function public.console_audience_size(segment text) returns bigint language plpgsql stable security definer set search_path='' as $$
begin
 if not public.console_owner() then raise exception 'Owner access required'; end if;
 return (select count(*) from auth.users where segment='Everyone' or public.console_plan(id)=segment);
end $$;
create index billing_orders_user on public.billing_orders(user_id,access_until);
create index billing_refunds_order on public.billing_refunds(order_id);
create unique index billing_gateway_order on public.billing_orders(provider,gateway_order);
create function public.membership_access() returns jsonb language sql stable security definer set search_path='' as $$
 select jsonb_build_object('plan',coalesce(public.console_plan(auth.uid()),'Free'),'enabled',(select enabled from public.billing_settings where id))
$$;
commit;
