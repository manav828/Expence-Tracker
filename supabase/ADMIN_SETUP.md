# ExpenCircle web admin

The web build contains the owner console at `/admin` and customer membership and support at `/membership`. Flutter Settings also links to the customer portal. For a plain local static server, open `/console/index.html` for the admin or append `?view=membership` for customers. The console configuration in `web/console/config.js` contains the project's public URL and publishable key. Point both it and Flutter at the same environment.

## Activate in a test project

1. Apply the app schema (including `app_notifications`), then `supabase/migrations/20261128000200_admin_console.sql` and `supabase/migrations/20261128000300_gateway_credentials.sql`, in order. Use separate Supabase projects for sandbox and live billing.
2. Create or choose an existing password-authenticated owner account, verify its identity in Supabase Authentication, and enable TOTP in Supabase Auth. Insert that account's UUID from the trusted SQL editor:

   ```sql
   insert into public.admin_owners(user_id) values ('<verified-owner-uuid>');
   ```

3. Sign in at `/admin`. On first use, enter the displayed setup key into an authenticator. Enter its six-digit code. Privileged queries require both the owner allowlist and an MFA-verified session. Removing the owner's row revokes console access.
4. In the web admin, open **Payment integration**, select **Add credentials** for your provider and enter the sandbox credentials. Cashfree uses App ID and Secret key. Razorpay uses Key ID, Key secret and the webhook secret configured in Razorpay. Save the credentials, then select **Use for new payments**. Credentials are stored encrypted in Supabase Vault. To keep previous payments and refunds accessible, use replacement keys for the same merchant account and environment. Import existing Edge-secret credentials using their original environment.
5. Deploy the functions in the linked test project:

   ```sh
   supabase functions deploy console-billing
   supabase functions deploy console-payment-events --no-verify-jwt
   ```

   The event receiver authenticates the raw payload with the gateway signature. Register `https://<project>.supabase.co/functions/v1/console-payment-events` on the provider dashboard. Enable successful payment events and refund status events. In Razorpay configure automatic capture and the same webhook secret stored above.
6. Open Settings in the admin and enable the web rollout **in the test project**. Verify purchase, cancellation of checkout, delayed callback, refund and a user-specific override before enabling it in production.

## Billing behavior

The catalog starts with prepaid Plus at ₹59 per month and ₹399 per year. Checkout uses one-time orders. Customers renew manually. A confirmed payment extends access from the later of today and the last paid-through date. Full refunds remove the refunded order's access. Partial refunds keep the term active. A manual Free or Plus override takes precedence until its expiry or removal. Price edits apply to new orders.

The dashboard uses paid order amounts and completed refunds. Complimentary grants have no order. Record individual order allocations from gateway settlement statements under Settlements to track actual deposits and fees. The date filter uses India time.

Pending payments can be verified against the original gateway in Payments. A refund reserves its amount before submission. After a network timeout, check its status or retry the existing reservation using its original idempotency key. If changing the active provider, keep its existing configuration and webhook connection so previous orders can still be reconciled and refunded.

Rollout starts paused. The switch covers customer checkout and the web Plus limits. Existing recurring reminders remain available. Personal ledger data is outside the admin console.
