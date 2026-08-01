-- Reorganiza as categorias de compras para a taxonomia nova
-- (ver lib/services/purchase_categorizer.dart):
--
--   Alimentação -> Comida          (não existem as duas)
--   Farmácia    -> Saúde           (são a mesma coisa)
--   Higiene     -> Pessoal         (higiene pessoal; limpeza vira categoria própria)
--   Lazer       -> Lazer, beleza e brinquedos
--   novas       -> Limpeza, Frutas, Dieta de Engorda
--
-- As compras das categorias aposentadas são movidas para a substituta
-- antes de apagá-las, então nada fica sem categoria.
--
-- Rodar manualmente no SQL editor do Supabase.

begin;

-- Chave sem acento/caixa, para casar "Alimentação" com "Alimentacao".
create or replace function pg_temp.cat_key(text) returns text as $$
  select translate(lower(btrim($1)),
                   'áàâãéêíìîóòôõúùûç',
                   'aaaaeeiiioooouuuc');
$$ language sql immutable;

-- 1. Move as compras para a categoria substituta do mesmo dono, quando
--    ela já existe.
with pairs as (
  select old.id as old_id, novo.id as novo_id
    from public.purchase_categories old
    join public.purchase_categories novo
      on novo.user_id = old.user_id
     and pg_temp.cat_key(novo.name) = case pg_temp.cat_key(old.name)
           when 'alimentacao' then 'comida'
           when 'farmacia'    then 'saude'
           when 'higiene'     then 'pessoal'
         end
   where pg_temp.cat_key(old.name) in ('alimentacao', 'farmacia', 'higiene')
)
update public.purchases p
   set category_id = pairs.novo_id
  from pairs
 where p.category_id = pairs.old_id;

-- 2. Apaga as aposentadas que ficaram sem nenhuma compra.
delete from public.purchase_categories c
 where pg_temp.cat_key(c.name) in ('alimentacao', 'farmacia', 'higiene')
   and not exists (
     select 1 from public.purchases p where p.category_id = c.id
   );

-- 3. As que sobraram (donos que não tinham a substituta) viram ela.
update public.purchase_categories c
   set name = case pg_temp.cat_key(c.name)
                when 'alimentacao' then 'Comida'
                when 'farmacia'    then 'Saude'
                when 'higiene'     then 'Pessoal'
              end
 where pg_temp.cat_key(c.name) in ('alimentacao', 'farmacia', 'higiene');

-- 4. Renomeia Lazer, mantendo a cor que já estava lá.
update public.purchase_categories
   set name = 'Lazer, beleza e brinquedos'
 where pg_temp.cat_key(name) = 'lazer';

-- 5. Cria as categorias novas para quem ainda não tem, com as cores
--    padrão de PurchaseCategorizer.categoryColors.
insert into public.purchase_categories (user_id, name, color_value)
select donos.user_id, novas.name, novas.color_value
  from (select distinct user_id from public.purchase_categories) donos
 cross join (values
         ('Limpeza',                      4279548070), -- 0xFF14B8A6
         ('Frutas',                       4294538006), -- 0xFFF97316
         ('Dieta de Engorda', 4290321436)  -- 0xFFB91C1C
       ) as novas(name, color_value)
 where not exists (
   select 1
     from public.purchase_categories c
    where c.user_id = donos.user_id
      and pg_temp.cat_key(c.name) = pg_temp.cat_key(novas.name)
 );

commit;

-- OPCIONAL: as compras antigas continuam na categoria que já tinham, ou
-- seja, o que estava em Comida não se divide sozinho em Comida/Frutas/
-- Dieta de Engorda. Para reclassificar, tire a categoria das
-- compras afetadas e rode "Categorizar automaticamente" no app (ele só
-- mexe em compras sem categoria, e mostra o resumo antes de confirmar).
--
-- update public.purchases p
--    set category_id = null
--   from public.purchase_categories c
--  where c.id = p.category_id
--    and pg_temp.cat_key(c.name) in ('comida', 'casa');
