-- Daffodils booking backend: run this migration in Supabase SQL Editor or with Supabase CLI.
create extension if not exists btree_gist with schema extensions;

create table if not exists public.rooms (
  room_number text primary key check (room_number in ('101','102','103','104','201','202','203','204')),
  floor text not null check (floor in ('First floor','Second floor')),
  active boolean not null default true,
  created_at timestamptz not null default now()
);
insert into public.rooms (room_number,floor) values
 ('101','First floor'),('102','First floor'),('103','First floor'),('104','First floor'),
 ('201','Second floor'),('202','Second floor'),('203','Second floor'),('204','Second floor')
on conflict (room_number) do nothing;

create table if not exists public.bookings (
  id uuid primary key default gen_random_uuid(),
  booking_ref text not null unique,
  guest_name text not null check (char_length(guest_name) between 2 and 120),
  phone text not null check (char_length(phone) between 5 and 40),
  check_in date not null,
  check_out date not null,
  guests smallint not null check (guests between 1 and 8),
  room_number text not null references public.rooms(room_number),
  status text not null default 'pending' check (status in ('pending','confirmed','cancelled')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (check_out > check_in),
  constraint bookings_no_room_overlap exclude using gist (
    room_number with =,
    (daterange(check_in,check_out,'[)')) with &&
  ) where (status in ('pending','confirmed'))
);

create table if not exists public.blocked_dates (
  id uuid primary key default gen_random_uuid(),
  room_number text not null references public.rooms(room_number),
  start_date date not null,
  end_date date not null,
  note text not null default '' check (char_length(note) <= 120),
  created_at timestamptz not null default now(),
  check (end_date > start_date)
);
create index if not exists blocked_dates_room_range_idx on public.blocked_dates using gist (room_number, (daterange(start_date,end_date,'[)')));
create index if not exists bookings_created_at_idx on public.bookings (created_at desc);

create table if not exists public.staff_users (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

create or replace function public.touch_updated_at()
returns trigger language plpgsql set search_path = public as $$
begin new.updated_at = now(); return new; end;
$$;
drop trigger if exists bookings_touch_updated_at on public.bookings;
create trigger bookings_touch_updated_at before update on public.bookings
for each row execute function public.touch_updated_at();

create or replace function public.is_staff()
returns boolean language sql stable security definer set search_path = public, auth as $$
  select exists (select 1 from public.staff_users where user_id = auth.uid());
$$;
revoke all on function public.is_staff() from public;
grant execute on function public.is_staff() to authenticated;

-- Only the trusted Edge Function uses the service key to create public requests.
create or replace function public.create_booking_request(
  p_guest_name text, p_phone text, p_check_in date, p_check_out date,
  p_guests smallint, p_room_number text default null
) returns jsonb language plpgsql security definer set search_path = public, extensions as $$
declare
  chosen_room text;
  new_ref text;
  new_id uuid;
begin
  if p_guest_name is null or char_length(trim(p_guest_name)) not between 2 and 120 then
    raise exception 'Enter a name between 2 and 120 characters' using errcode = '22023';
  end if;
  if p_phone is null or char_length(trim(p_phone)) not between 5 and 40 then
    raise exception 'Enter a valid contact number' using errcode = '22023';
  end if;
  if p_check_in is null or p_check_out is null or p_check_in < current_date or p_check_out <= p_check_in then
    raise exception 'Choose valid future dates; check-out must follow check-in' using errcode = '22023';
  end if;
  if p_check_out - p_check_in > 60 then raise exception 'A stay cannot exceed 60 nights' using errcode = '22023'; end if;
  if p_guests is null or p_guests not between 1 and 8 then raise exception 'Guest count must be between 1 and 8' using errcode = '22023'; end if;
  if p_room_number is not null and p_room_number not in ('101','102','103','104','201','202','203','204') then
    raise exception 'Invalid room preference' using errcode = '22023';
  end if;

  -- Serialize assignment so concurrent public requests cannot select the same room/date range.
  perform pg_advisory_xact_lock(827462);
  select r.room_number into chosen_room
  from public.rooms r
  where r.active and (p_room_number is null or r.room_number = p_room_number)
    and not exists (
      select 1 from public.bookings b
      where b.room_number = r.room_number and b.status in ('pending','confirmed')
        and daterange(b.check_in,b.check_out,'[)') && daterange(p_check_in,p_check_out,'[)')
    )
    and not exists (
      select 1 from public.blocked_dates d
      where d.room_number = r.room_number
        and daterange(d.start_date,d.end_date,'[)') && daterange(p_check_in,p_check_out,'[)')
    )
  order by r.room_number limit 1;
  if chosen_room is null then raise exception 'No room is available for those dates' using errcode = 'P0001'; end if;

  new_id := gen_random_uuid();
  new_ref := 'DG-' || upper(substr(replace(new_id::text,'-',''),1,8));
  insert into public.bookings(id,booking_ref,guest_name,phone,check_in,check_out,guests,room_number)
  values (new_id,new_ref,trim(p_guest_name),trim(p_phone),p_check_in,p_check_out,p_guests,chosen_room);
  return jsonb_build_object('id',new_id,'booking_ref',new_ref,'room_number',chosen_room,'status','pending');
end;
$$;

create or replace function public.check_room_availability(p_check_in date,p_check_out date,p_room_number text default null)
returns table(room_number text) language sql stable security definer set search_path = public as $$
  select r.room_number from public.rooms r
  where r.active and p_check_in >= current_date and p_check_out > p_check_in
    and (p_room_number is null or r.room_number = p_room_number)
    and not exists (select 1 from public.bookings b where b.room_number=r.room_number and b.status in ('pending','confirmed') and daterange(b.check_in,b.check_out,'[)') && daterange(p_check_in,p_check_out,'[)'))
    and not exists (select 1 from public.blocked_dates d where d.room_number=r.room_number and daterange(d.start_date,d.end_date,'[)') && daterange(p_check_in,p_check_out,'[)'))
  order by r.room_number;
$$;

revoke all on function public.create_booking_request(text,text,date,date,smallint,text) from public, anon, authenticated;
revoke all on function public.check_room_availability(date,date,text) from public, anon, authenticated;
grant execute on function public.create_booking_request(text,text,date,date,smallint,text) to service_role;
grant execute on function public.check_room_availability(date,date,text) to service_role;

alter table public.rooms enable row level security;
alter table public.bookings enable row level security;
alter table public.blocked_dates enable row level security;
alter table public.staff_users enable row level security;
revoke all on public.rooms,public.bookings,public.blocked_dates,public.staff_users from anon,authenticated;
grant select on public.bookings,public.blocked_dates to authenticated;
grant update (status) on public.bookings to authenticated;
grant select,insert,delete on public.blocked_dates to authenticated;

create policy "Staff read bookings" on public.bookings for select to authenticated using (public.is_staff());
create policy "Staff update booking status" on public.bookings for update to authenticated using (public.is_staff()) with check (public.is_staff());
create policy "Staff read blocked dates" on public.blocked_dates for select to authenticated using (public.is_staff());
create policy "Staff add blocked dates" on public.blocked_dates for insert to authenticated with check (public.is_staff());
create policy "Staff remove blocked dates" on public.blocked_dates for delete to authenticated using (public.is_staff());
create policy "Staff read staff list" on public.staff_users for select to authenticated using (user_id = auth.uid());

-- After creating the owner account in Supabase Authentication, grant dashboard access:
-- insert into public.staff_users (user_id) values ('AUTH_USER_UUID');
