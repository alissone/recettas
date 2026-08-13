#!/usr/bin/env python3
"""Convert one or more scraped supermarket product pages into SQL for
public.foods.

Usage:
    python scripts/product_page_to_sql.py pages.txt
    python scripts/product_page_to_sql.py pages.txt --strict
    python scripts/product_page_to_sql.py            # paste, then Ctrl-Z (Windows) / Ctrl-D

The input is the raw markdown dump of a product page (e.g. the page an
"page to markdown" browser extension produces for an Extra Mercado product,
or similar sites with the same layout). Paste as many pages as you like
into one file, back to back - each one is detected on its own and written
to its own SQL file.

A page is recognised by its title line and the "Source:" line right after
it:

    # <Product Name> | <Site Name>

    Source: https://...

Everything from that title up to the next one (or end of input) is treated
as a single product. Within it the script reads:
  - "Marca" from the "Característica Geral" table, as public.foods.brand;
  - the "Tabela nutricional" section: the "Porção de <N><g|ml>" line sets
    base_amount/base_unit, and every row of the markdown table under it
    becomes a public.food_nutrients row.

The output goes to migrations/nutrition/<nome>.sql, one file per product,
applied by hand in the Supabase SQL editor like everything else in
migrations/.

Two things this script refuses to guess, same as
scripts/nutrition_report_to_sql.py:
  - a nutrient label it does not recognise is reported and left out, never
    mapped to something close;
  - a unit that disagrees with public.nutrients is converted only between
    mass units (g/mg/ug); anything else is skipped with a warning instead
    of silently being a 1000x mistake in the charts.

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

# Same namespace as scripts/nutrition_report_to_sql.py, so a product whose
# name happens to match an existing food updates that row instead of
# duplicating it.
FOOD_NAMESPACE = uuid.UUID('6f9619ff-8b86-d011-b42d-00c04fc964ff')

# ('id', 'Nome', 'category', 'unit', 123, false)
CATALOG_ROW = re.compile(
    r"^\s*\('([A-Za-z0-9]+)',\s*'(.+?)',\s*'([A-Za-z]+)',\s*"
    r"'([a-z]+)',\s*(\d+),\s*(?:true|false)\)",
    re.MULTILINE,
)

# "# <name> | <site>", blank line, "Source: <url>". Marks where one
# product page starts; everything up to the next match is that product.
PRODUCT_HEADER = re.compile(
    r'#\s*(?P<name>[^\n|]+?)\s*\|[^\n]*\n\s*\n\s*Source:\s*(?P<url>\S+)'
)

CODE_LINE = re.compile(r'C[óo]d\.?:\s*(\S+)')
BRAND_ROW = re.compile(r'\|\s*Marca\s*\|\s*([^|]+?)\s*\|', re.IGNORECASE)
PORTION_LINE = re.compile(
    r'Por[çc][ãa]o\s+de\s*(?P<amount>\d+(?:[.,]\d+)?)\s*(?P<unit>g|ml)',
    re.IGNORECASE,
)

# Quantity cell of a "Tabela nutricional" row, e.g. "20 g", "414mg", "0,9g".
VALUE_CELL = re.compile(
    r'^(?P<value>-?\d+(?:[.,]\d+)?)\s*'
    r'(?P<unit>g|mg|mcg|µg|ug|kcal|kj|iu|ui|ml|l|%)$',
    re.IGNORECASE,
)

REPORT_UNITS = {
    'g': 'g', 'mg': 'mg', 'mcg': 'ug', 'µg': 'ug', 'ug': 'ug',
    'kcal': 'kcal', 'kj': 'kj', 'iu': 'iu', 'ui': 'iu',
    'ml': 'ml', 'l': 'l', '%': 'percent',
}

# Grams per unit, for the only conversions worth doing automatically.
MASS_IN_GRAMS = {'g': 1.0, 'mg': 1e-3, 'ug': 1e-6}

# ANVISA-style "Tabela Nutricional" label (accent-free, lowercase) -> id in
# public.nutrients. Deliberately smaller than the SR25 catalog in
# nutrition_report_to_sql.py: product panels only ever print a handful of
# fields, and a label with no entry here is reported as unmapped rather
# than guessed at.
NAME_TO_ID = {
    # Macronutrients
    'carboidratos': 'carbohydrates',
    'carboidrato': 'carbohydrates',
    'proteinas': 'protein',
    'proteina': 'protein',
    'gorduras totais': 'fat',
    'gorduras saturadas': 'saturatedFat',
    'gorduras trans': 'transFat',
    'gorduras monoinsaturadas': 'monounsaturatedFat',
    'gorduras poliinsaturadas': 'polyunsaturatedFat',
    'gorduras poli-insaturadas': 'polyunsaturatedFat',
    'fibra alimentar': 'fiber',
    'sodio': 'sodium',
    'colesterol': 'cholesterol',
    'amido': 'starch',
    'alcool': 'alcohol',
    'agua': 'water',
    'cinzas': 'ash',

    # Sugars
    'acucares totais': 'sugar',
    'acucares adicionados': 'addedSugar',
    'lactose': 'lactose',
    'sacarose': 'sucrose',
    'glicose': 'glucose',
    'frutose': 'fructose',
    'galactose': 'galactose',
    'maltose': 'maltose',

    # Fatty acids
    'omega 3': 'omega3',
    'omega-3': 'omega3',
    'omega 6': 'omega6',
    'omega-6': 'omega6',
    'epa': 'epa',
    'dha': 'dha',
    'ala': 'ala',

    # Minerals
    'calcio': 'calcium',
    'ferro': 'iron',
    'magnesio': 'magnesium',
    'fosforo': 'phosphorus',
    'potassio': 'potassium',
    'zinco': 'zinc',
    'cobre': 'copper',
    'manganes': 'manganese',
    'selenio': 'selenium',
    'iodo': 'iodine',
    'cromo': 'chromium',
    'molibdenio': 'molybdenum',
    'fluor': 'fluoride',
    'cloreto': 'chloride',

    # Vitamins
    'vitamina c': 'vitaminC',
    'tiamina': 'vitaminB1',
    'vitamina b1': 'vitaminB1',
    'riboflavina': 'vitaminB2',
    'vitamina b2': 'vitaminB2',
    'niacina': 'vitaminB3',
    'vitamina b3': 'vitaminB3',
    'acido pantotenico': 'vitaminB5',
    'vitamina b5': 'vitaminB5',
    'vitamina b6': 'vitaminB6',
    'biotina': 'vitaminB7',
    'vitamina b7': 'vitaminB7',
    'acido folico': 'vitaminB9',
    'folato': 'vitaminB9',
    'vitamina b9': 'vitaminB9',
    'vitamina b12': 'vitaminB12',
    'vitamina e': 'vitaminE',
    'vitamina k': 'vitaminK',
    'colina': 'choline',

    # Other
    'cafeina': 'caffeine',
    'teobromina': 'theobromine',
}

# Labels only distinguishable by the unit column (mirrors the same
# ambiguity in nutrition_report_to_sql.py).
NAME_TO_ID_BY_UNIT = {
    ('valor energetico', 'kcal'): 'calories',
    ('valor energetico', 'kj'): 'kilojoules',
    ('vitamina a', 'ug'): 'vitaminA',
    ('vitamina a', 'iu'): 'vitaminAIu',
    ('vitamina d', 'ug'): 'vitaminD',
    ('vitamina d', 'iu'): 'vitaminDIu',
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
    text = strip_accents(text).lower()
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


def resolve_id(name_norm, unit):
    by_unit = NAME_TO_ID_BY_UNIT.get((name_norm, unit))
    if by_unit:
        return by_unit
    return NAME_TO_ID.get(name_norm)


def convert_amount(amount, from_unit, to_unit):
    """Mass-only conversion. Returns (amount, None) or (None, error)."""
    if from_unit == to_unit:
        return amount, None
    if from_unit in MASS_IN_GRAMS and to_unit in MASS_IN_GRAMS:
        return amount * MASS_IN_GRAMS[from_unit] / MASS_IN_GRAMS[to_unit], None
    return None, f'reported in {from_unit}, catalog wants {to_unit}'


def split_products(text):
    """Yields (name, source_url, block_text) for every product page found."""
    matches = list(PRODUCT_HEADER.finditer(text))
    for index, match in enumerate(matches):
        start = match.start()
        end = matches[index + 1].start() if index + 1 < len(matches) else len(text)
        yield match.group('name').strip(), match.group('url').strip(), text[start:end]


def parse_brand(block_text):
    match = BRAND_ROW.search(block_text)
    if not match:
        return None
    brand = match.group(1).strip()
    return brand or None


def parse_code(block_text):
    match = CODE_LINE.search(block_text)
    return match.group(1).strip() if match else None


def parse_nutrition_table(block_text, catalog):
    """Returns (base_amount, base_unit, rows, unknown, skipped) or None if
    no "Tabela nutricional" section is present."""
    section_match = re.search(r'Tabela\s+nutricional', block_text, re.IGNORECASE)
    if not section_match:
        return None
    section_text = block_text[section_match.end():]

    portion_match = PORTION_LINE.search(section_text)
    if not portion_match:
        return None
    base_amount = float(portion_match.group('amount').replace(',', '.'))
    base_unit = portion_match.group('unit').lower()

    rows = []
    seen = {}
    unknown = []
    skipped = []

    for raw_line in section_text.splitlines():
        line = raw_line.strip()
        if not line.startswith('|'):
            continue
        cells = [c.strip() for c in line.strip('|').split('|')]
        if len(cells) < 2:
            continue
        label, value_cell = cells[0], cells[1]
        if not label or label.upper() == 'ITEM':
            continue
        if set(label) <= {'-', ' '}:
            continue

        value_match = VALUE_CELL.match(value_cell)
        if not value_match:
            skipped.append(f'{label}: could not parse quantity {value_cell!r}')
            continue

        report_unit = REPORT_UNITS[value_match.group('unit').lower()]
        name_norm = normalize(label)
        nutrient_id = resolve_id(name_norm, report_unit)
        if nutrient_id is None:
            unknown.append(label)
            continue
        if nutrient_id not in catalog:
            sys.exit(
                f'error: "{label}" maps to "{nutrient_id}", which is not in '
                f'public.nutrients.\n       Add it to migrations/ first.'
            )

        amount = float(value_match.group('value').replace(',', '.'))
        catalog_unit = catalog[nutrient_id]
        if report_unit != catalog_unit:
            converted, error = convert_amount(amount, report_unit, catalog_unit)
            if error is None:
                amount = converted
            else:
                skipped.append(f'{label}: {error}')
                continue

        if nutrient_id in seen:
            skipped.append(f'{label}: duplicate of "{seen[nutrient_id]}"')
            continue
        seen[nutrient_id] = label
        rows.append((nutrient_id, amount, label))

    return base_amount, base_unit, rows, unknown, skipped


def sql_str(value):
    return "'" + value.replace("'", "''") + "'"


def format_amount(value):
    text = f'{value:.6f}'.rstrip('0').rstrip('.')
    return text if text else '0'


def slugify(name):
    slug = re.sub(r'[^a-z0-9]+', '_', normalize(name)).strip('_')
    slug = slug or 'produto'
    if slug in WINDOWS_RESERVED:
        slug += '_food'
    return slug[:80]


def build_sql(name, brand, code, source_url, food_id, base_amount, base_unit,
               rows, unknown):
    lines = [f'-- {name}']
    if brand:
        lines.append(f'-- Marca: {brand}')
    if code:
        lines.append(f'-- Codigo: {code}')
    lines.append(f'-- Fonte: {source_url}')
    lines.append('-- Gerado por scripts/product_page_to_sql.py - nao editar a mao.')
    lines.append('--')
    lines.append(
        f'-- Valores por {format_amount(base_amount)} {base_unit}. O id vem de um'
    )
    lines.append('-- uuid5 do nome, entao reaplicar este arquivo atualiza a mesma linha')
    lines.append('-- em vez de duplicar o alimento.')
    if unknown:
        lines.append('--')
        lines.append('-- Nutrientes da embalagem sem correspondencia no catalogo,')
        lines.append('-- portanto NAO importados:')
        lines.extend(f'--   {label}' for label in unknown)
    lines.append('')

    brand_sql = sql_str(brand) if brand else 'null'
    lines.append(
        'insert into public.foods (id, user_id, name, brand, base_amount, base_unit)'
    )
    lines.append(
        f'values ({sql_str(food_id)}, null, {sql_str(name)}, {brand_sql}, '
        f'{format_amount(base_amount)}, {sql_str(base_unit)})'
    )
    lines.append('on conflict (id) do update set')
    lines.append('  name = excluded.name,')
    lines.append('  brand = excluded.brand,')
    lines.append('  base_amount = excluded.base_amount,')
    lines.append('  base_unit = excluded.base_unit;')
    lines.append('')

    if not rows:
        lines.append('-- Nenhum nutriente reconhecido na tabela nutricional.')
        return '\n'.join(lines) + '\n'

    lines.append('insert into public.food_nutrients (food_id, nutrient_id, amount)')
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
        description='Convert scraped product pages into SQL for public.foods.')
    parser.add_argument('input', nargs='?',
                        help='file with one or more pasted product pages; '
                             'omit to read stdin')
    parser.add_argument('-o', '--out-dir', default=str(DEFAULT_OUT_DIR),
                        help=f'output directory (default {DEFAULT_OUT_DIR})')
    parser.add_argument('--strict', action='store_true',
                        help='exit non-zero if any product was skipped or '
                             'any nutrient was unrecognised')
    args = parser.parse_args()

    if args.input:
        text = Path(args.input).read_text(encoding='utf-8')
    else:
        if sys.stdin.isatty():
            print('Cole as paginas e finalize com Ctrl-Z + Enter '
                  '(Windows) ou Ctrl-D.', file=sys.stderr)
        text = sys.stdin.read()

    if not text.strip():
        sys.exit('error: empty input')

    # Neutralise stray ``` fences a paste may have kept; they carry no
    # meaning here and can otherwise glue a title onto the previous line.
    text = text.replace('```', ' ')

    catalog = load_catalog()

    products = list(split_products(text))
    if not products:
        sys.exit('error: no product page found. Expected a "# Name | Site" '
                 'title line followed by a "Source: ..." line.')

    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    written = 0
    had_problems = False

    for name, source_url, block_text in products:
        brand = parse_brand(block_text)
        code = parse_code(block_text)

        parsed = parse_nutrition_table(block_text, catalog)
        if parsed is None:
            print(f'{name}: sem "Tabela nutricional" reconhecivel, pulado.',
                  file=sys.stderr)
            had_problems = True
            continue

        base_amount, base_unit, rows, unknown, skipped = parsed
        if not rows:
            print(f'{name}: nenhum nutriente reconhecido, pulado.',
                  file=sys.stderr)
            had_problems = True
            continue

        food_id = str(uuid.uuid5(FOOD_NAMESPACE, normalize(name)))
        sql = build_sql(name, brand, code, source_url, food_id, base_amount,
                        base_unit, rows, unknown)

        out_path = out_dir / f'{slugify(name)}.sql'
        out_path.write_text(sql, encoding='utf-8')
        written += 1

        print(f'{name}  ->  {out_path}')
        print(f'  {len(rows)} nutrientes por '
              f'{format_amount(base_amount)} {base_unit}')
        if brand:
            print(f'  marca: {brand}')
        for note in skipped:
            print(f'  pulado: {note}')
        if unknown:
            had_problems = True
            print(f'  {len(unknown)} sem correspondencia (nao importados):',
                  file=sys.stderr)
            for label in unknown:
                print(f'    {label}', file=sys.stderr)

    print(f'\n{written}/{len(products)} produtos convertidos.')
    if args.strict and had_problems:
        sys.exit(1)


if __name__ == '__main__':
    main()
