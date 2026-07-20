-- Gastos (purchases + categories) and Compras (shopping_items) become
-- shareable: an accepted invite in list_invites gives the invitee full
-- access to the inviter's rows. has_list_access() also covers the
-- plain "own rows" case, so these policies replace the originals.
-- Receipt jobs and the receipts storage bucket stay personal.

-- Purchases
drop policy "Users can view their own purchases" on public.purchases;
drop policy "Users can create their own purchases" on public.purchases;
drop policy "Users can update their own purchases" on public.purchases;
drop policy "Users can delete their own purchases" on public.purchases;

create policy "List members can view purchases"
  on public.purchases for select
  using (public.has_list_access(user_id));

create policy "List members can create purchases"
  on public.purchases for insert
  with check (public.has_list_access(user_id));

create policy "List members can update purchases"
  on public.purchases for update
  using (public.has_list_access(user_id));

create policy "List members can delete purchases"
  on public.purchases for delete
  using (public.has_list_access(user_id));

-- Purchase categories ("Importância")
drop policy "Users can view their own purchase categories"
  on public.purchase_categories;
drop policy "Users can create their own purchase categories"
  on public.purchase_categories;
drop policy "Users can update their own purchase categories"
  on public.purchase_categories;
drop policy "Users can delete their own purchase categories"
  on public.purchase_categories;

create policy "List members can view purchase categories"
  on public.purchase_categories for select
  using (public.has_list_access(user_id));

create policy "List members can create purchase categories"
  on public.purchase_categories for insert
  with check (public.has_list_access(user_id));

create policy "List members can update purchase categories"
  on public.purchase_categories for update
  using (public.has_list_access(user_id));

create policy "List members can delete purchase categories"
  on public.purchase_categories for delete
  using (public.has_list_access(user_id));

-- Shopping items ("Compras")
drop policy "Users can view their own shopping items"
  on public.shopping_items;
drop policy "Users can create their own shopping items"
  on public.shopping_items;
drop policy "Users can update their own shopping items"
  on public.shopping_items;
drop policy "Users can delete their own shopping items"
  on public.shopping_items;

create policy "List members can view shopping items"
  on public.shopping_items for select
  using (public.has_list_access(user_id));

create policy "List members can create shopping items"
  on public.shopping_items for insert
  with check (public.has_list_access(user_id));

create policy "List members can update shopping items"
  on public.shopping_items for update
  using (public.has_list_access(user_id));

create policy "List members can delete shopping items"
  on public.shopping_items for delete
  using (public.has_list_access(user_id));
