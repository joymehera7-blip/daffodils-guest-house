create extension if not exists btree_gist;

create table if not exists public.rooms (
  id text primary key,
  floor smallint not null check (floor in (1,2)),
  active boolean not null default true
);

insert into public.rooms (id, floor) values
('101',1),('102',1),('103',1),('104',1),
('201',2),('202',2),('203',2),('204',2)
on conflict (id) do nothing;

create table if not exists public.bookings (
  id uuid primary key default gen_random_uuid(),
  room_id text not null references public.rooms(id),
  guest_name text not null check (length(trim(guest_name)) between 2 and 120),
  phone text not null check (length(trim(phone)) between 7 and 25),
  guest_count smallint not null default 2 check (guest_count between 1 and 8),
  check_in date not null,
  check_out date not null,
  status text not null default 'pending' check (status in ('pending','confirmed','cancelled','rejected')),
  source text not null default 'direct' check (source in ('direct','phone','booking_com','makemytrip','goibibo','agoda','cleartrip','other')),
  created_at timestamptz not null default now(),
  constraint valid_stay_dates check (check_out > check_in),
  constraint no_overlapping_active_room_bookings
    exclude using gist (room_id with =, daterange(check_in, check_out, '[)') with &&)
    where (status in ('pending','confirmed'))
);

create index if not exists bookings_dates_idx on public.bookings (check_in, check_out);
create index if not exists bookings_status_idx on public.bookings (status);

alter table public.rooms enable row level security;
alter table public.bookings enable row level security;

-- Room names/floors are public; guests cannot change the room inventory.
drop policy if exists "Anyone can view active rooms" on public.rooms;
create policy "Anyone can view active rooms" on public.rooms
for select to anon, authenticated using (active = true);

-- Admin access is granted only to authenticated users whose JWT app_metadata.role is admin.
drop policy if exists "Admins can manage rooms" on public.rooms;
create policy "Admins can manage rooms" on public.rooms
for all to authenticated
using ((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin')
with check ((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin');

drop policy if exists "Admins can read bookings" on public.bookings;
create policy "Admins can read bookings" on public.bookings
for select to authenticated
using ((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin');

drop policy if exists "Admins can update bookings" on public.bookings;
create policy "Admins can update bookings" on public.bookings
for update to authenticated
using ((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin')
with check ((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin');

-- Public requests go through this function. It creates a pending request only.
-- The exclusion constraint safely rejects overlapping active dates, including concurrent requests.
create or replace function public.request_booking(
  p_room_id text,
  p_guest_name text,
  p_phone text,
  p_guest_count smallint,
  p_check_in date,
  p_check_out date
) returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare new_id uuid;
begin
  if p_check_in < current_date then raise exception 'Check-in cannot be in the past'; end if;
  if p_check_out <= p_check_in then raise exception 'Check-out must be after check-in'; end if;
  if p_guest_count < 1 or p_guest_count > 8 then raise exception 'Guest count must be between 1 and 8'; end if;
  if not exists (select 1 from rooms where id = p_room_id and active = true) then
    raise exception 'Room is not available for requests';
  end if;
  insert into bookings(room_id, guest_name, phone, guest_count, check_in, check_out, status, source)
  values (p_room_id, trim(p_guest_name), trim(p_phone), p_guest_count, p_check_in, p_check_out, 'pending', 'direct')
  returning id into new_id;
  return new_id;
end;
$$;

revoke all on function public.request_booking(text,text,text,smallint,date,date) from public;
grant execute on function public.request_booking(text,text,text,smallint,date,date) to anon, authenticated;
