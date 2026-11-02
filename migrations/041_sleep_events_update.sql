-- Sleep screen: tapping "Dormi"/"Acordei" again while the last event is
-- already of that type moves that event to the new time instead of adding
-- a second one. 009 never granted UPDATE, so under RLS that update matched
-- no rows and silently did nothing.
create policy "Users can update their own sleep events"
  on public.sleep_events for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
