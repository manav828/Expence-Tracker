import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

interface ServiceAccount {
  project_id: string;
  client_email: string;
  private_key: string;
}

interface ReminderPayload {
  group_id: string;
  group_name: string;
  from_member_id: string;
  to_member_id: string;
  recipient_user_id: string;
  from_name: string;
  to_name: string;
  amount: number;
}

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

function base64UrlEncode(input: Uint8Array | string): string {
  const bytes = typeof input === 'string' ? new TextEncoder().encode(input) : input;
  let binary = '';
  for (let i = 0; i < bytes.length; i++) {
    binary += String.fromCharCode(bytes[i]);
  }
  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

function pemToDer(pem: string): ArrayBuffer {
  const clean = pem
    .replace('-----BEGIN PRIVATE KEY-----', '')
    .replace('-----END PRIVATE KEY-----', '')
    .replace(/\s+/g, '');
  const binary = atob(clean);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes.buffer;
}

async function getFcmAccessToken(sa: ServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const header = base64UrlEncode(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const claimSet = base64UrlEncode(
    JSON.stringify({
      iss: sa.client_email,
      scope: 'https://www.googleapis.com/auth/firebase.messaging',
      aud: 'https://oauth2.googleapis.com/token',
      iat: now,
      exp: now + 3600,
    }),
  );

  const signingInput = `${header}.${claimSet}`;
  const key = await crypto.subtle.importKey(
    'pkcs8',
    pemToDer(sa.private_key),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );

  const sig = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    key,
    new TextEncoder().encode(signingInput),
  );
  const jwt = `${signingInput}.${base64UrlEncode(new Uint8Array(sig))}`;

  const tokenRes = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt,
    }),
  });

  if (!tokenRes.ok) {
    const errText = await tokenRes.text();
    throw new Error(`Google OAuth token exchange failed (${tokenRes.status}): ${errText}`);
  }

  const tokenJson = await tokenRes.json();
  return tokenJson.access_token as string;
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL');
    const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY');
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
    const saRaw = Deno.env.get('FIREBASE_SERVICE_ACCOUNT_JSON');

    if (!supabaseUrl || !supabaseAnonKey || !supabaseServiceKey) {
      return new Response(JSON.stringify({ error: 'Missing Supabase environment variables' }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    if (!saRaw) {
      return new Response(JSON.stringify({ error: 'FIREBASE_SERVICE_ACCOUNT_JSON secret not configured' }), {
        status: 501,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // Verify caller identity using their JWT
    const userClient = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: userData, error: userErr } = await userClient.auth.getUser();
    if (userErr || !userData.user) {
      return new Response(JSON.stringify({ error: 'Invalid user token' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const payload = (await req.json()) as ReminderPayload;
    if (!payload.group_id || !payload.recipient_user_id || !payload.amount) {
      return new Response(JSON.stringify({ error: 'Missing required fields' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const adminClient = createClient(supabaseUrl, supabaseServiceKey);

    // Ensure caller is a verified member or creator of the split group
    const { data: callerMember } = await adminClient
      .from('split_members')
      .select('id')
      .eq('group_id', payload.group_id)
      .eq('user_id', userData.user.id)
      .limit(1);

    const { data: callerGroup } = await adminClient
      .from('split_groups')
      .select('id')
      .eq('id', payload.group_id)
      .eq('user_id', userData.user.id)
      .limit(1);

    if ((!callerMember || callerMember.length === 0) && (!callerGroup || callerGroup.length === 0)) {
      return new Response(JSON.stringify({ error: 'Forbidden: caller is not a member of this group' }), {
        status: 403,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // Fetch recipient's registered FCM tokens
    const { data: tokenRows, error: tokenErr } = await adminClient
      .from('user_device_tokens')
      .select('id, fcm_token')
      .eq('user_id', payload.recipient_user_id);

    if (tokenErr) {
      throw tokenErr;
    }

    if (!tokenRows || tokenRows.length === 0) {
      return new Response(
        JSON.stringify({ sent: 0, reason: 'no_device_tokens' }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    const serviceAccount = JSON.parse(saRaw) as ServiceAccount;
    const accessToken = await getFcmAccessToken(serviceAccount);
    const fcmUrl = `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`;

    const formattedAmount = Number(payload.amount).toFixed(2).replace(/\.00$/, '');
    const senderLabel = payload.to_name === 'You'
      ? (userData.user.user_metadata?.full_name || userData.user.email || 'A group member')
      : payload.to_name;

    const title = `Payment Reminder • ${payload.group_name}`;
    const body = `${senderLabel} reminded you to settle ₹${formattedAmount} in ${payload.group_name}.`;

    let sentCount = 0;
    const staleTokenIds: string[] = [];

    for (const row of tokenRows) {
      const fcmRes = await fetch(fcmUrl, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${accessToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          message: {
            token: row.fcm_token,
            notification: {
              title,
              body,
            },
            data: {
              type: 'settlement_reminder',
              group_id: payload.group_id,
              group_name: payload.group_name,
              amount: String(payload.amount),
            },
            android: {
              priority: 'high',
              notification: {
                channel_id: 'expencircle_push_reminders',
              },
            },
          },
        }),
      });

      if (fcmRes.ok) {
        sentCount++;
      } else {
        const errBody = await fcmRes.text();
        console.error(`FCM send failed for token ${row.id}:`, errBody);
        if (errBody.includes('UNREGISTERED') || errBody.includes('NOT_FOUND')) {
          staleTokenIds.push(row.id);
        }
      }
    }

    if (staleTokenIds.length > 0) {
      await adminClient.from('user_device_tokens').delete().in('id', staleTokenIds);
    }

    return new Response(
      JSON.stringify({
        sent: sentCount,
        total_tokens: tokenRows.length,
        ...(sentCount === 0 ? { reason: 'delivery_failed' } : {}),
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  } catch (err) {
    console.error('send-settlement-reminder error:', err);
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});
