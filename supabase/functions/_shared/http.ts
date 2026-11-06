import { createClient } from 'npm:@supabase/supabase-js@2';

export const corsHeaders = (request: Request) => {
  const configured = Deno.env.get('ALLOWED_ORIGINS')?.split(',').map((x) => x.trim()).filter(Boolean) ?? [];
  const origin = request.headers.get('origin') ?? '';
  const allowed = configured.includes(origin);
  return {
    allowed,
    headers: {
      'Access-Control-Allow-Origin': allowed ? origin : 'null',
      'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
      'Access-Control-Allow-Methods': 'POST, OPTIONS',
      'Vary': 'Origin',
      'Content-Type': 'application/json; charset=utf-8',
    },
  };
};

export function json(request: Request, body: unknown, status = 200) {
  const cors = corsHeaders(request);
  return new Response(JSON.stringify(body), { status, headers: cors.headers });
}

export function backend() {
  const url = Deno.env.get('SUPABASE_URL');
  const key = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!url || !key) throw new Error('Backend is not configured');
  return createClient(url, key, { auth: { persistSession: false, autoRefreshToken: false } });
}
