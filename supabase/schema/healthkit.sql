-- PACE LAB / HealthKit sync. Apply ONLY to a dedicated PACE LAB Supabase project.
-- Health data is never shipped in GitHub and is never readable by anonymous users.
create table if not exists public.health_workouts (
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  source_uuid uuid not null,
  activity_type integer not null,
  activity_kind text not null check (activity_kind in ('running','walking','cycling','strength','other')),
  started_at timestamptz not null,
  ended_at timestamptz not null,
  duration_seconds double precision not null check (duration_seconds >= 0 and duration_seconds <= 86400),
  distance_meters double precision check (distance_meters >= 0),
  active_energy_kcal double precision check (active_energy_kcal >= 0),
  hr_average_bpm double precision check (hr_average_bpm > 0 and hr_average_bpm < 260),
  hr_max_bpm double precision check (hr_max_bpm > 0 and hr_max_bpm < 260),
  hr_at_end_bpm double precision check (hr_at_end_bpm > 0 and hr_at_end_bpm < 260),
  recovery_hr_1min double precision check (recovery_hr_1min > 0 and recovery_hr_1min < 260),
  recovery_hr_2min double precision check (recovery_hr_2min > 0 and recovery_hr_2min < 260),
  recovery_hr_3min double precision check (recovery_hr_3min > 0 and recovery_hr_3min < 260),
  apple_recovery_1min_delta double precision check (apple_recovery_1min_delta >= 0 and apple_recovery_1min_delta < 200),
  recovery_hr_5min double precision check (recovery_hr_5min > 0 and recovery_hr_5min < 260),
  recovery_state text not null default 'pending' check (recovery_state in ('pending','partial','complete')),
  -- Raw data points, with timestamps. May have gaps; never interpolate missing heart rates.
  heart_rate_series jsonb not null default '[]'::jsonb check (jsonb_typeof(heart_rate_series)='array'),
  recorded_at timestamptz not null default now(),
  primary key (user_id, source_uuid),
  constraint workout_times_valid check (ended_at >= started_at)
);
create index if not exists health_workouts_owner_start_idx on public.health_workouts(user_id, started_at desc);
alter table public.health_workouts enable row level security;
revoke all on public.health_workouts from public, anon;
grant select, insert, update, delete on public.health_workouts to authenticated;

create policy "select_own_health_workouts" on public.health_workouts for select to authenticated
  using ((select auth.uid()) = user_id);
create policy "insert_own_health_workouts" on public.health_workouts for insert to authenticated
  with check ((select auth.uid()) = user_id);
create policy "update_own_health_workouts" on public.health_workouts for update to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy "delete_own_health_workouts" on public.health_workouts for delete to authenticated
  using ((select auth.uid()) = user_id);
