import { backend, corsHeaders, json } from '../_shared/http.ts';

Deno.serve(async (request: Request) => {
  const cors = corsHeaders(request);
  if (request.method === 'OPTIONS') return new Response('ok', { headers: cors.headers });
  if (!cors.allowed) return json(request, { error: 'Origin not allowed' }, 403);
  if (request.method !== 'POST') return json(request, { error: 'Method not allowed' }, 405);
  try {
    const body = await request.json();
    const checkIn = String(body.check_in ?? '');
    const checkOut = String(body.check_out ?? '');
    const roomNumber = body.room_number ? String(body.room_number) : null;
    if (!/^\d{4}-\d{2}-\d{2}$/.test(checkIn) || !/^\d{4}-\d{2}-\d{2}$/.test(checkOut) || checkOut <= checkIn) {
      return json(request, { error: 'Choose valid check-in and check-out dates.' }, 400);
    }
    const { data, error } = await backend().rpc('check_room_availability', {
      p_check_in: checkIn, p_check_out: checkOut, p_room_number: roomNumber,
    });
    if (error) return json(request, { error: 'Could not check availability.' }, 500);
    return json(request, { available_rooms: data ?? [] });
  } catch {
    return json(request, { error: 'Could not check availability.' }, 400);
  }
});
