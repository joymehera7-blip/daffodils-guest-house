import { backend, corsHeaders, json } from '../_shared/http.ts';

Deno.serve(async (request: Request) => {
  const cors = corsHeaders(request);
  if (request.method === 'OPTIONS') return new Response('ok', { headers: cors.headers });
  if (!cors.allowed) return json(request, { error: 'Origin not allowed' }, 403);
  if (request.method !== 'POST') return json(request, { error: 'Method not allowed' }, 405);
  try {
    const body = await request.json();
    const guestName = String(body.guest_name ?? '').trim();
    const phone = String(body.phone ?? '').trim();
    const checkIn = String(body.check_in ?? '');
    const checkOut = String(body.check_out ?? '');
    const guests = Number(body.guests);
    const roomNumber = body.room_number ? String(body.room_number) : null;
    if (guestName.length < 2 || guestName.length > 120 || phone.length < 5 || phone.length > 40 ||
      !/^\d{4}-\d{2}-\d{2}$/.test(checkIn) || !/^\d{4}-\d{2}-\d{2}$/.test(checkOut) ||
      !Number.isInteger(guests) || guests < 1 || guests > 8) {
      return json(request, { error: 'Please check your name, phone, dates, and guest count.' }, 400);
    }
    const { data, error } = await backend().rpc('create_booking_request', {
      p_guest_name: guestName, p_phone: phone, p_check_in: checkIn,
      p_check_out: checkOut, p_guests: guests, p_room_number: roomNumber,
    });
    if (error) {
      const message = error.message?.includes('No room is available')
        ? 'No room is available for those dates. Please try other dates or contact the guest house.'
        : error.code === '22023' || error.code === 'P0001'
          ? error.message
          : 'We could not save the request right now. Please contact the guest house directly.';
      return json(request, { error: message }, error.code === 'P0001' ? 409 : 400);
    }
    return json(request, data, 201);
  } catch {
    return json(request, { error: 'We could not save the request. Please try again or contact the guest house.' }, 400);
  }
});
