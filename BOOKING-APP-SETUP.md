# Daffodils Guest House — Booking app setup

## Current development
- `booking-dashboard.html` is the first admin-dashboard prototype (browser-local storage only).
- `supabase/schema.sql` is the shared database schema foundation for eight rooms, booking requests, admin-only access, and protection against overlapping active bookings.
- The live public website on the `main` branch has not been replaced.

## Important before using real guest data
The dashboard prototype is not a production booking system. Do not enter real guest personal information until a secure backend and admin authentication are configured. Browser-local records are not shared between devices and can be cleared by the browser.

## Configure the shared database
1. Create a Supabase project for Daffodils Guest House.
2. Open the Supabase SQL Editor and run `supabase/schema.sql`.
3. In Supabase Authentication, create the property administrator account.
4. Have a trusted project administrator set the user's `app_metadata.role` to `admin` using the Supabase server-side Admin API. Never put the service-role key in browser code.
5. Use the project's public URL and anon key only in the frontend. Keep the service-role key on a secure server.
6. Connect the website and dashboard to the database through a server-side API or carefully restricted Supabase client. Public guest submissions must call `request_booking`; the function creates a pending request, not a confirmed reservation.
7. Test two requests for the same room and overlapping dates. The second must be rejected. Test admin sign-in and booking status updates before publishing.

## OTA / channel-manager connections
Booking.com, MakeMyTrip, Goibibo, Agoda and Cleartrip are not connected by this repository change. Each connection depends on the property's eligibility, partner approval, credentials, and supported channel-manager/API access. A channel manager is usually the practical route to synchronize inventory and rates across multiple OTAs. Do not promise real-time synchronization until a provider connection has been approved, configured, and tested.

## Suggested rollout
1. Configure Supabase and admin authentication.
2. Connect the public enquiry form and admin dashboard to the shared database.
3. Add email/WhatsApp notifications and booking status management.
4. Select a supported channel manager and complete its partner onboarding.
5. Test inventory synchronization before accepting OTA reservations through the app.
