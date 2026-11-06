# Daffodils Guest House — Goa

Official website and booking-app development for Daffodils Guest House, Calangute, Goa.

## Development preview

- [Booking Manager dashboard](./booking-dashboard.html) — first admin UI prototype for the property's eight rooms. At this stage, booking records are stored only in the browser used to open the dashboard.
- [Booking app setup guide](./BOOKING-APP-SETUP.md) — backend setup, admin access, testing and OTA integration roadmap.
- [Supabase database schema](./supabase/schema.sql) — shared rooms and bookings tables, admin row-level security policies, pending direct booking requests, and prevention of overlapping active reservations.

## Important status

The existing public website is on `main`. These booking-app files are on the `booking-app-mvp` development branch and are not yet published on the public website. The shared database is not deployed, admin authentication is not configured, and no OTA account/API connection is active yet. Do not use the prototype for live guest records or as a source of confirmed availability.

## Planned next steps

1. Create and configure the Supabase project and secure admin account.
2. Connect the public booking enquiry form and dashboard to the shared database.
3. Add notifications and booking status management.
4. Complete approved channel-manager/API onboarding for supported OTAs and test inventory synchronization.
