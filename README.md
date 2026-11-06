# Daffodils Guest House

Official website for Daffodils Guest House, Gaura Vaddo, Calangute, Goa.

## Booking backend upgrade

The repository now includes a Supabase/PostgreSQL backend scaffold alongside the GitHub Pages website:

- `booking.html` checks availability against the shared database and submits booking requests to a server-side Edge Function.
- `admin.html` is a staff-only dashboard using Supabase Auth and row-level security. It supports request status updates, room date blocks, and CSV export.
- `supabase/migrations/20261106000000_booking_backend.sql` creates the room inventory, bookings, blocked dates, overlap protection, and staff access rules.
- `supabase/functions/availability` and `supabase/functions/booking-request` expose public booking operations without exposing the service-role secret in the browser.

Requests are saved as **pending**, which reserves the assigned room until staff cancels or confirms the request. Availability assignment is serialized in PostgreSQL and an exclusion constraint guards against overlapping active room reservations. Guest requests are not auto-confirmed and no payment is collected.

## Configure and deploy

1. Create a Supabase project and run `supabase/migrations/20261106000000_booking_backend.sql` in its SQL Editor (or use the Supabase CLI linked to the project).
2. In Authentication, create the property owner's account. Copy that user's UUID and grant dashboard access in SQL Editor:

   ```sql
   insert into public.staff_users (user_id) values ('AUTH_USER_UUID');
   ```

3. Set `supabase-config.js` to the project URL and **anon/publishable key**. This key is intended for browser use; never use a service-role key in the file.
4. Install the Supabase CLI and log in, link the project, then deploy:

   ```sh
   supabase login
   supabase link --project-ref YOUR_PROJECT_ID
   supabase secrets set ALLOWED_ORIGINS=https://YOUR_GITHUB_PAGES_HOST
   supabase functions deploy availability --no-verify-jwt
   supabase functions deploy booking-request --no-verify-jwt
   ```

   For a custom domain, add its exact origin to `ALLOWED_ORIGINS` (comma-separated for multiple origins). Do not use `*` in production. Supabase provides `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` to Edge Functions; keep the service-role secret server-side only.
5. Publish the static site on GitHub Pages. Open `booking.html` to test a request and `admin.html` to sign in as the staff user.

## Important production notes

- Configure Supabase Auth email/password and secure recovery settings. Grant access only to trusted staff; use strong unique passwords and MFA where available.
- Public endpoints should be protected with hosting/WAF rate limits and monitoring before advertising. This starter does not include bot protection, email/SMS delivery, payment processing, or OTA integrations.
- Pending requests hold inventory until a staff member cancels them; handle requests promptly. Add an expiry workflow before unattended automated bookings.
- This is a deployable integration scaffold, not a fully launched service: the Supabase project, secrets, migration, staff account, and function deployment must be configured by the owner.
- Booking.com/MakeMyTrip are not connected. OTA access requires their approved partner/API credentials and a separate connector; do not scrape these services.
