-- Invites to share your Gastos and Compras lists with another user,
-- identified by email. Managed like the receipt_jobs queue: one row
-- per invite, and the invitee flips the status when responding.
create table public.list_invites (
  id uuid default gen_random_uuid() primary key,
  inviter_id uuid references public.profiles(id) on delete cascade not null,
  invitee_email text not null,
  -- Filled by the invitee when they respond, so accepted invites keep
  -- working even if the account's email changes later.
  invitee_id uuid references public.profiles(id) on delete cascade,
  status text not null default 'pending'
    check (status in ('pending', 'accepted', 'declined')),
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- One invite per inviter/email pair.
create unique index list_invites_inviter_email_idx
  on public.list_invites (inviter_id, lower(invitee_email));

-- Fast lookups by has_list_access() below.
create index list_invites_invitee_idx
  on public.list_invites (invitee_id, status);

alter table public.list_invites enable row level security;

create policy "Inviters can view their sent invites"
  on public.list_invites for select
  using (auth.uid() = inviter_id);

create policy "Invitees can view invites addressed to them"
  on public.list_invites for select
  using (
    auth.uid() = invitee_id
    or lower(invitee_email) = lower(auth.jwt() ->> 'email')
  );

create policy "Inviters can create invites"
  on public.list_invites for insert
  with check (
    auth.uid() = inviter_id
    and lower(invitee_email) <> lower(auth.jwt() ->> 'email')
  );

-- Responding claims the row: the invitee must set invitee_id to
-- themselves along with the new status.
create policy "Invitees can respond to their invites"
  on public.list_invites for update
  using (
    auth.uid() = invitee_id
    or lower(invitee_email) = lower(auth.jwt() ->> 'email')
  )
  with check (auth.uid() = invitee_id);

create policy "Inviters can delete their invites"
  on public.list_invites for delete
  using (auth.uid() = inviter_id);

-- True when the signed-in user owns `owner`'s lists or has an accepted
-- invite from them. security definer so table policies built on it
-- don't re-enter list_invites' own RLS.
create or replace function public.has_list_access(owner uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select auth.uid() = owner
    or exists (
      select 1
      from public.list_invites
      where inviter_id = owner
        and invitee_id = auth.uid()
        and status = 'accepted'
    );
$$;

-- Both sides of an invite can see each other's profile (display name
-- for the list tabs and the invite cards).
create policy "Users can view profiles linked by an invite"
  on public.profiles for select
  using (
    exists (
      select 1
      from public.list_invites
      where (
          inviter_id = profiles.id
          and (invitee_id = auth.uid()
               or lower(invitee_email) = lower(auth.jwt() ->> 'email'))
        )
        or (invitee_id = profiles.id and inviter_id = auth.uid())
    )
  );
