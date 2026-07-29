-- Adds the remaining nutrients that appear in full SR25 reports: two more
-- saturated chains (17:0, 20:0), the cis/trans split of the mono and
-- polyunsaturated chains, the trans subtotals, the tocotrienols and
-- beta-tocopherol, and the plant sterols.
--
-- sort_order values fall between the ones set in migration 020 so each
-- new row lands next to the chain it belongs to.
--
-- Additive only: migration 020 remains the base catalog. Safe to re-run.
insert into public.nutrients (id, name, category, unit, sort_order, is_primary)
values
  -- Saturated chains missing from 020
  ('heptadecanoicAcid', 'Ácido heptadecanóico (17:0)', 'fattyAcid', 'g', 375, false),
  ('arachidicAcid', 'Ácido araquídico (20:0)', 'fattyAcid', 'g', 385, false),

  -- Monounsaturated: reports split some chains into cis and trans
  ('palmitoleicAcidCis', 'Ácido palmitoleico cis (16:1 c)', 'fattyAcid', 'g', 405, false),
  ('oleicAcidCis', 'Ácido oleico cis (18:1 c)', 'fattyAcid', 'g', 412, false),
  ('oleicAcidTrans', 'Ácido oleico trans (18:1 t)', 'fattyAcid', 'g', 414, false),

  -- Polyunsaturated isomers
  ('linoleicAcidCis', 'Ácido linoleico cis n-6 (18:2 n-6 c,c)', 'fattyAcid', 'g', 452, false),
  ('conjugatedLinoleicAcid', 'Ácido linoleico conjugado (CLA)', 'fattyAcid', 'g', 454, false),
  ('linoleicAcidIsomers', 'Ácido linoleico, isômeros juntos', 'fattyAcid', 'g', 456, false),

  -- Trans subtotals, reported alongside total trans fat
  ('transMonoenoicFat', 'Gorduras trans monoenoicas', 'fattyAcid', 'g', 522, false),
  ('transPolyenoicFat', 'Gorduras trans polienoicas', 'fattyAcid', 'g', 524, false),

  -- Remaining vitamin E family
  ('betaTocopherol', 'Beta-tocoferol', 'vitamin', 'mg', 1075, false),
  ('alphaTocotrienol', 'Tocotrienol alfa', 'vitamin', 'mg', 1092, false),
  ('betaTocotrienol', 'Tocotrienol beta', 'vitamin', 'mg', 1094, false),
  ('gammaTocotrienol', 'Tocotrienol gama', 'vitamin', 'mg', 1096, false),
  ('deltaTocotrienol', 'Tocotrienol delta', 'vitamin', 'mg', 1098, false),

  -- Plant sterols, reported next to cholesterol
  ('stigmasterol', 'Estigmasterol', 'sterol', 'mg', 610, false),
  ('campesterol', 'Campesterol', 'sterol', 'mg', 620, false),
  ('betaSitosterol', 'Beta-sitosterol', 'sterol', 'mg', 630, false)
on conflict (id) do update set
  name = excluded.name,
  category = excluded.category,
  unit = excluded.unit,
  sort_order = excluded.sort_order,
  is_primary = excluded.is_primary;
