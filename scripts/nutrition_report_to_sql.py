#!/usr/bin/env python3
"""Convert a pasted SR25 nutrition report into a SQL file for public.foods.

Usage:
    python scripts/nutrition_report_to_sql.py            # paste, then Ctrl-Z (Windows) / Ctrl-D
    python scripts/nutrition_report_to_sql.py report.txt
    python scripts/nutrition_report_to_sql.py report.txt --base-unit ml

Source is the "Relatório completo" page of the Tabela de Composição
Química dos Alimentos (SR25), UNIFESP. Paste the whole page: the food
name comes from the "Relatório completo:" line, and every row is read as

    <nome>  <unidade>  <valor por 100 g>  <outras porções...>

Only the first value column is used; the per-portion columns are ignored.

The output goes to migrations/nutrition/<nome>.sql and is applied by hand
in the Supabase SQL editor like everything else in migrations/.

Two things this script refuses to guess:
  - a nutrient name it does not recognise is reported and left out, never
    mapped to something close;
  - a unit that disagrees with public.nutrients is converted only between
    mass units (g/mg/ug). Anything else is an error, because silently
    accepting it would be a 1000x mistake in the charts.

The nutrient catalog (id -> unit) is parsed straight out of migrations/,
so this script cannot drift from the database.
"""
import argparse
import re
import sys
import unicodedata
import uuid
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
MIGRATIONS_DIR = REPO_ROOT / 'migrations'
DEFAULT_OUT_DIR = MIGRATIONS_DIR / 'nutrition'

# Stable namespace so re-running a report updates the same food row.
FOOD_NAMESPACE = uuid.UUID('6f9619ff-8b86-d011-b42d-00c04fc964ff')

# ('id', 'Nome', 'category', 'unit', 123, false)
CATALOG_ROW = re.compile(
    r"^\s*\('([A-Za-z0-9]+)',\s*'(.+?)',\s*'([A-Za-z]+)',\s*"
    r"'([a-z]+)',\s*(\d+),\s*(?:true|false)\)",
    re.MULTILINE,
)

# <nome> <unidade> <valor> [outras colunas]. The unit token anchors the
# split, so this works whether the paste kept tabs or collapsed them to
# spaces. "Valor energético (kcal)" is safe because the unit has to stand
# alone - "(kcal)" carries the parenthesis.
DATA_ROW = re.compile(
    r'^(?P<name>.+?)[ \t]+'
    r'(?P<unit>g|mg|mcg|µg|ug|kcal|kJ|kj|IU|UI|ml|mL|L|%)[ \t]+'
    r'(?P<value>-?\d+(?:[.,]\d+)?)(?:[ \t].*)?$'
)

REPORT_UNITS = {
    'g': 'g', 'mg': 'mg', 'mcg': 'ug', 'µg': 'ug', 'ug': 'ug',
    'kcal': 'kcal', 'kj': 'kj', 'iu': 'iu', 'ui': 'iu',
    'ml': 'ml', 'l': 'l', '%': 'percent',
}

# Grams per unit, for the only conversions worth doing automatically.
MASS_IN_GRAMS = {'g': 1.0, 'mg': 1e-3, 'ug': 1e-6}

SECTIONS = {
    'principais', 'minerais', 'vitaminas', 'lipidios',
    'aminoacidos', 'outros', 'carboidratos',
}

# Rows that also switch the current fatty-acid subgroup, which is what
# disambiguates the chain names repeated across groups.
FAT_SUBGROUPS = {
    'gorduras saturadas': 'sat',
    'gorduras monoinsaturadas': 'mono',
    'gorduras poliinsaturadas': 'poly',
    'gorduras poli-insaturadas': 'poly',
    'gorduras trans': 'trans',
}

# SR25 label (accent-free, lowercase) -> nutrient id.
NAME_TO_ID = {
    # Principais
    'agua': 'water',
    'valor energetico (kcal)': 'calories',
    'valor energetico (kj)': 'kilojoules',
    'proteina': 'protein',
    'gorduras totais': 'fat',
    'lipidios totais': 'fat',
    'cinzas': 'ash',
    'carboidratos (por diferenca)': 'carbohydrates',
    'carboidrato disponivel': 'carbohydrates',
    'fibra alimentar': 'fiber',
    'fibra alimentar soluvel': 'solubleFiber',
    'fibra alimentar insoluvel': 'insolubleFiber',
    'amido': 'starch',
    'acucares totais': 'sugar',
    'acucares adicionados': 'addedSugar',
    'monossacarideos': 'monosaccharides',
    'glicose': 'glucose',
    'frutose': 'fructose',
    'galactose': 'galactose',
    'sacarose': 'sucrose',
    'lactose': 'lactose',
    'maltose': 'maltose',

    # Minerais
    'calcio': 'calcium',
    'ferro': 'iron',
    'magnesio': 'magnesium',
    'fosforo': 'phosphorus',
    'potassio': 'potassium',
    'sodio': 'sodium',
    'zinco': 'zinc',
    'cobre': 'copper',
    'manganes': 'manganese',
    'selenio': 'selenium',
    'iodo': 'iodine',
    'cromo': 'chromium',
    'molibdenio': 'molybdenum',
    'fluor': 'fluoride',
    'fluoreto': 'fluoride',
    'cloreto': 'chloride',

    # Vitaminas
    'vitamina c, acido ascorbico total': 'vitaminC',
    'vitamina c': 'vitaminC',
    'tiamina': 'vitaminB1',
    'riboflavina': 'vitaminB2',
    'niacina': 'vitaminB3',
    'acido pantotenico': 'vitaminB5',
    'vitamina b6': 'vitaminB6',
    'biotina': 'vitaminB7',
    'acido folico, total': 'vitaminB9',
    'folato, total': 'vitaminB9',
    'acido folico': 'folicAcid',
    'folato, alimento': 'foodFolate',
    'folato, equivalente a medida diaria': 'folateDfe',
    'colina, total': 'choline',
    'betaina': 'betaine',
    'vitamina b12': 'vitaminB12',
    'vitamina b-12, adicionada': 'addedVitaminB12',
    'vitamina a (atividade equivalente de retinol)': 'vitaminA',
    'retinol': 'retinol',
    'vitamina a (si)': 'vitaminAIu',
    'vitamina e (alfatocoferol)': 'vitaminE',
    'vitamina e, adicionada': 'addedVitaminE',
    'beta-tocoferol': 'betaTocopherol',
    'gama-tocoferol': 'gammaTocopherol',
    'delta-tocoferol': 'deltaTocopherol',
    'tocotrienol, alpha': 'alphaTocotrienol',
    'tocotrienol, alfa': 'alphaTocotrienol',
    'tocotrienol, beta': 'betaTocotrienol',
    'tocotrienol, gamma': 'gammaTocotrienol',
    'tocotrienol, gama': 'gammaTocotrienol',
    'tocotrienol, delta': 'deltaTocotrienol',
    'vitamina d (d2 + d3)': 'vitaminD',
    'vitamina d2 (ergocalciferol)': 'vitaminD2',
    'vitamina d3 (colecalciferol)': 'vitaminD3',
    'vitamina k (filoquinona)': 'vitaminK',
    'dihidrofiloquinona': 'dihydrophylloquinone',

    # Carotenoides
    'betacaroteno': 'betaCarotene',
    'alfacaroteno': 'alphaCarotene',
    'beta-criptoxantina': 'betaCryptoxanthin',
    'licopeno': 'lycopene',
    'luteina + zeaxantina': 'luteinZeaxanthin',

    # Lipidios
    'gorduras saturadas': 'saturatedFat',
    'acido graxo butirico': 'butyricAcid',
    'acido graxo caproico': 'caproicAcid',
    'acido graxo caprilico': 'caprylicAcid',
    'acido graxo caprico': 'capricAcid',
    'acido graxo laurico': 'lauricAcid',
    'acido graxo miristico': 'myristicAcid',
    'acido graxo heptadecanoico': 'heptadecanoicAcid',
    'acido graxo estearico': 'stearicAcid',
    'acido graxo araquidico': 'arachidicAcid',
    'gorduras monoinsaturadas': 'monounsaturatedFat',
    'acido graxo palmitoleico': 'palmitoleicAcid',
    'acido graxo palmitico, cis': 'palmitoleicAcidCis',
    'acido graxo palmitoleico, cis': 'palmitoleicAcidCis',
    'acido graxo oleico': 'oleicAcid',
    'acido graxo oleico, cis': 'oleicAcidCis',
    'acido graxo oleico, trans': 'oleicAcidTrans',
    'acido graxo gadoleico': 'gadoleicAcid',
    'acido graxo erucico': 'erucicAcid',
    'gorduras poliinsaturadas': 'polyunsaturatedFat',
    'gorduras poli-insaturadas': 'polyunsaturatedFat',
    'acido graxo linoleico': 'linoleicAcid',
    'acido graxo linoleico, cis, n-6': 'linoleicAcidCis',
    'acido graxo linoleico, conjugado': 'conjugatedLinoleicAcid',
    'acido graxo linoleico, isomeros juntos': 'linoleicAcidIsomers',
    'acido graxo linolenico': 'ala',
    'acido graxo alfa linoleico': 'ala',
    'acido graxo alfa linolenico': 'ala',
    'acido graxo parinarico': 'parinaricAcid',
    'acido graxo aracdonico': 'arachidonicAcid',
    'acido graxo araquidonico': 'arachidonicAcid',
    'acido eicosapentaenoico (epa)': 'epa',
    'acido docosapentaenoico (dpa)': 'dpa',
    'acido decosahexaenoico (dha)': 'dha',
    'acido docosahexaenoico (dha)': 'dha',
    'gorduras trans': 'transFat',
    'gorduras trans, monoenoico': 'transMonoenoicFat',
    'gorduras trans, polienoico': 'transPolyenoicFat',
    'colesterol': 'cholesterol',
    'estigmasterol': 'stigmasterol',
    'campesterol': 'campesterol',
    'beta-sisterol': 'betaSitosterol',
    'beta-sitosterol': 'betaSitosterol',

    # Aminoacidos
    'triptofano': 'tryptophan',
    'treonina': 'threonine',
    'isoleucina': 'isoleucine',
    'leucina': 'leucine',
    'lisina': 'lysine',
    'metionina': 'methionine',
    'cisteina': 'cysteine',
    'cistina': 'cysteine',
    'fenilalanina': 'phenylalanine',
    'tirosina': 'tyrosine',
    'valina': 'valine',
    'arginina': 'arginine',
    'histidina': 'histidine',
    'alanina': 'alanine',
    'aspartato': 'asparticAcid',
    'acido aspartico': 'asparticAcid',
    'glutamato': 'glutamicAcid',
    'acido glutamico': 'glutamicAcid',
    'glicina': 'glycine',
    'prolina': 'proline',
    'serina': 'serine',

    # Outros
    'alcool': 'alcohol',
    'cafeina': 'caffeine',
    'teobromina': 'theobromine',
}

# Labels SR25 reuses across fatty-acid subgroups: 16:0 under saturadas is
# palmitic, 16:1 under monoinsaturadas is palmitoleic even though some
# report versions print "palmitico" for both.
NAME_TO_ID_BY_SUBGROUP = {
    ('acido graxo palmitico', 'sat'): 'palmiticAcid',
    ('acido graxo palmitico', 'mono'): 'palmitoleicAcid',
}

# Labels that are only distinguishable by the unit column.
NAME_TO_ID_BY_UNIT = {
    ('vitamina d', 'iu'): 'vitaminDIu',
    ('vitamina d', 'ug'): 'vitaminD',
    ('vitamina a', 'iu'): 'vitaminAIu',
    ('vitamina a', 'ug'): 'vitaminA',
}

WINDOWS_RESERVED = {
    'con', 'prn', 'aux', 'nul',
    *(f'com{i}' for i in range(1, 10)),
    *(f'lpt{i}' for i in range(1, 10)),
}


def strip_accents(text):
    decomposed = unicodedata.normalize('NFD', text)
    return ''.join(c for c in decomposed if not unicodedata.combining(c))


def normalize(text):
    """Accent-free, lowercase, single-spaced, no trailing punctuation."""
    text = strip_accents(text).lower().replace(' ', ' ')
    text = re.sub(r'\s+', ' ', text).strip()
    return text.rstrip('.:').strip()


def load_catalog():
    """id -> unit, replaying migrations in order so later ones win."""
    catalog = {}
    for path in sorted(MIGRATIONS_DIR.glob('*.sql')):
        for match in CATALOG_ROW.finditer(path.read_text(encoding='utf-8')):
            catalog[match.group(1)] = match.group(4)
    if not catalog:
        sys.exit(f'error: no nutrient catalog found in {MIGRATIONS_DIR}')
    return catalog


def parse_food_name(text):
    match = re.search(r'Relat[óo]rio completo:\s*(.+)', text)
    if match:
        return match.group(1).strip()
    return None


def parse_base_portion(text):
    """The first "(100.00 g)" in the header, which labels column one."""
    head = text.split('Principais')[0]
    match = re.search(r'\((\d+(?:[.,]\d+)?)\s*(g|ml|mL)\)', head)
    if not match:
        return None, None
    return float(match.group(1).replace(',', '.')), match.group(2).lower()


def resolve_id(name_norm, unit, subgroup):
    by_subgroup = NAME_TO_ID_BY_SUBGROUP.get((name_norm, subgroup))
    if by_subgroup:
        return by_subgroup
    by_unit = NAME_TO_ID_BY_UNIT.get((name_norm, unit))
    if by_unit:
        return by_unit
    return NAME_TO_ID.get(name_norm)


def convert_amount(amount, from_unit, to_unit, label):
    if from_unit == to_unit:
        return amount
    if from_unit in MASS_IN_GRAMS and to_unit in MASS_IN_GRAMS:
        return amount * MASS_IN_GRAMS[from_unit] / MASS_IN_GRAMS[to_unit]
    sys.exit(
        f'error: "{label}" is reported in {from_unit} but the catalog '
        f'stores it in {to_unit}, and those are not inter-convertible.\n'
        f'       Fix the unit in migrations/ or drop the row.'
    )


def parse_report(text, catalog):
    """Returns (rows, unknown, duplicates, converted)."""
    rows = []
    seen = {}
    unknown = []
    duplicates = []
    converted = []
    subgroup = None

    for raw_line in text.splitlines():
        line = raw_line.rstrip()
        if not line.strip():
            continue

        stripped = normalize(line)
        if stripped in SECTIONS:
            if stripped != 'lipidios':
                subgroup = None
            continue

        match = DATA_ROW.match(line.strip())
        if not match:
            continue

        label = match.group('name').strip()
        name_norm = normalize(label)
        report_unit = REPORT_UNITS.get(normalize(match.group('unit')))
        if report_unit is None:
            continue

        if name_norm in FAT_SUBGROUPS:
            subgroup = FAT_SUBGROUPS[name_norm]

        nutrient_id = resolve_id(name_norm, report_unit, subgroup)
        if nutrient_id is None:
            unknown.append(label)
            continue
        if nutrient_id not in catalog:
            sys.exit(
                f'error: "{label}" maps to "{nutrient_id}", which is not in '
                f'public.nutrients.\n       Add it to migrations/ first.'
            )

        amount = float(match.group('value').replace(',', '.'))
        catalog_unit = catalog[nutrient_id]
        if report_unit != catalog_unit:
            amount = convert_amount(amount, report_unit, catalog_unit, label)
            converted.append(f'{label}: {report_unit} -> {catalog_unit}')

        # SR25 prints some values twice under different labels (alpha
        # linolenic and linolenic, for one). First wins.
        if nutrient_id in seen:
            duplicates.append(f'{label} (already set by "{seen[nutrient_id]}")')
            continue

        seen[nutrient_id] = label
        rows.append((nutrient_id, amount, label))

    return rows, unknown, duplicates, converted


def sql_str(value):
    return "'" + value.replace("'", "''") + "'"


def format_amount(value):
    text = f'{value:.6f}'.rstrip('0').rstrip('.')
    return text if text else '0'


def slugify(name):
    slug = re.sub(r'[^a-z0-9]+', '_', normalize(name)).strip('_')
    slug = slug or 'alimento'
    if slug in WINDOWS_RESERVED:
        slug += '_food'
    return slug[:80]


def build_sql(food_name, food_id, base_amount, base_unit, rows, unknown):
    lines = [
        f'-- {food_name}',
        '-- Fonte: Tabela de Composicao Quimica dos Alimentos (SR25), UNIFESP.',
        '-- Gerado por scripts/nutrition_report_to_sql.py - nao editar a mao.',
        '--',
        f'-- Valores por {format_amount(base_amount)} {base_unit}. O id vem de um',
        '-- uuid5 do nome, entao reaplicar este arquivo atualiza a mesma linha',
        '-- em vez de duplicar o alimento.',
    ]
    if unknown:
        lines.append('--')
        lines.append('-- Nutrientes do relatorio sem correspondencia no catalogo,')
        lines.append('-- portanto NAO importados:')
        lines.extend(f'--   {name}' for name in unknown)
    lines.append('')

    lines.append(
        'insert into public.foods (id, user_id, name, base_amount, base_unit)')
    lines.append(
        f'values ({sql_str(food_id)}, null, {sql_str(food_name)}, '
        f'{format_amount(base_amount)}, {sql_str(base_unit)})'
    )
    lines.append('on conflict (id) do update set')
    lines.append('  name = excluded.name,')
    lines.append('  base_amount = excluded.base_amount,')
    lines.append('  base_unit = excluded.base_unit;')
    lines.append('')

    if not rows:
        lines.append('-- Nenhum nutriente reconhecido no relatorio.')
        return '\n'.join(lines) + '\n'

    lines.append(
        'insert into public.food_nutrients (food_id, nutrient_id, amount)')
    lines.append('values')
    for index, (nutrient_id, amount, label) in enumerate(rows):
        separator = ',' if index < len(rows) - 1 else ''
        lines.append(
            f'  ({sql_str(food_id)}, {sql_str(nutrient_id)}, '
            f'{format_amount(amount)}){separator}  -- {label}'
        )
    lines.append('on conflict (food_id, nutrient_id) do update set')
    lines.append('  amount = excluded.amount;')
    return '\n'.join(lines) + '\n'


def main():
    parser = argparse.ArgumentParser(
        description='Convert an SR25 nutrition report into SQL.')
    parser.add_argument('input', nargs='?',
                        help='report file; omit to read stdin')
    parser.add_argument('--name', help='override the food name')
    parser.add_argument('--base-amount', type=float,
                        help='portion the first value column refers to')
    parser.add_argument('--base-unit', choices=['g', 'ml'],
                        help="'ml' for liquids catalogued per 100 ml")
    parser.add_argument('-o', '--out-dir', default=str(DEFAULT_OUT_DIR),
                        help=f'output directory (default {DEFAULT_OUT_DIR})')
    parser.add_argument('--strict', action='store_true',
                        help='exit non-zero if any nutrient was unrecognised')
    args = parser.parse_args()

    if args.input:
        text = Path(args.input).read_text(encoding='utf-8')
    else:
        if sys.stdin.isatty():
            print('Cole o relatorio e finalize com Ctrl-Z + Enter '
                  '(Windows) ou Ctrl-D.', file=sys.stderr)
        text = sys.stdin.read()

    if not text.strip():
        sys.exit('error: empty input')

    food_name = args.name or parse_food_name(text)
    if not food_name:
        sys.exit('error: no food name found. Include the "Relatório '
                 'completo: ..." line or pass --name.')

    detected_amount, detected_unit = parse_base_portion(text)
    base_amount = args.base_amount or detected_amount or 100.0
    base_unit = args.base_unit or detected_unit or 'g'

    catalog = load_catalog()
    rows, unknown, duplicates, converted = parse_report(text, catalog)

    if not rows:
        sys.exit('error: no nutrient rows recognised. Check that the paste '
                 'kept its columns (nome / unidade / valor).')

    food_id = str(uuid.uuid5(FOOD_NAMESPACE, normalize(food_name)))
    sql = build_sql(food_name, food_id, base_amount, base_unit, rows, unknown)

    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    out_path = out_dir / f'{slugify(food_name)}.sql'
    out_path.write_text(sql, encoding='utf-8')

    print(f'{food_name}  ->  {out_path}')
    print(f'  {len(rows)} nutrientes por '
          f'{format_amount(base_amount)} {base_unit}')
    for note in converted:
        print(f'  convertido: {note}')
    for note in duplicates:
        print(f'  duplicado, ignorado: {note}')
    if unknown:
        print(f'  {len(unknown)} sem correspondencia (nao importados):',
              file=sys.stderr)
        for name in unknown:
            print(f'    {name}', file=sys.stderr)
    if unknown and args.strict:
        sys.exit(1)


if __name__ == '__main__':
    main()
