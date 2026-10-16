-- Water and electricity meter readings. `value` is the cumulative number
-- on the meter's display (m3 for water, kWh for energy), never the
-- consumption: usage is derived from consecutive readings, and the very
-- first row of each kind is just the starting point (zero usage).
create table public.utility_readings (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references public.profiles(id) on delete cascade not null,
  kind text not null check (kind in ('water', 'energy')),
  value numeric not null check (value >= 0),
  recorded_at timestamptz not null default now(),
  created_at timestamptz default now()
);

alter table public.utility_readings enable row level security;

create policy "Users can view their own utility readings"
  on public.utility_readings for select
  using (auth.uid() = user_id);

create policy "Users can create their own utility readings"
  on public.utility_readings for insert
  with check (auth.uid() = user_id);

create policy "Users can delete their own utility readings"
  on public.utility_readings for delete
  using (auth.uid() = user_id);

create index utility_readings_user_kind_recorded_idx
  on public.utility_readings (user_id, kind, recorded_at);

-- Current tariff, one row per user. Null means "not set yet", in which
-- case the app shows usage without a price.
create table public.utility_prices (
  user_id uuid references public.profiles(id) on delete cascade primary key,
  water_price_m3 numeric check (water_price_m3 >= 0),
  energy_price_kwh numeric check (energy_price_kwh >= 0),
  updated_at timestamptz default now()
);

alter table public.utility_prices enable row level security;

create policy "Users can view their own utility prices"
  on public.utility_prices for select
  using (auth.uid() = user_id);

create policy "Users can create their own utility prices"
  on public.utility_prices for insert
  with check (auth.uid() = user_id);

create policy "Users can update their own utility prices"
  on public.utility_prices for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
