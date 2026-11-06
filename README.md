# Daffodils Guest House

Official website for Daffodils Guest House, Gaura Vaddo, Calangute, Goa.

## Booking MVP

- `booking.html` — guest booking enquiry form with date validation, room preference, a local-demo availability check, and a WhatsApp handoff to the guest house.
- `admin.html` — local demo dashboard to view requests made in the same browser, mark requests confirmed/cancelled, block room dates, and export a CSV.
- `index.html` — existing property information and direct contact details.

## Important MVP limitations

This repository is a static GitHub Pages website. The booking and host dashboard are a front-end prototype: data is stored in the browser's `localStorage`, so it is **not shared across visitors, devices, or browsers**. WhatsApp enquiries are not automatically delivered to a server, and a request is not a confirmed reservation. The availability check is only against demo data in that browser. Do not rely on this prototype for live inventory or use it to promise a room.

There is no payment processing, user authentication, database, or Booking.com/MakeMyTrip integration yet. A production channel manager needs a secure backend and database, authentication for staff, server-side booking transactions to prevent double bookings, and approved partner/API access for each OTA. Never put OTA credentials or payment secrets in browser code.

## Try it

Deploy the repository with GitHub Pages, then visit `/booking.html` for the guest flow and `/admin.html` for the demo dashboard. To see the local demo, submit a request and open the dashboard in the same browser and device.
