#!/usr/bin/env python3
"""Convert a purchases CSV export into a SQL insert script for public.purchases.

Usage:
    python csv_to_purchases_sql.py INPUT.csv --user-id USER_UUID [-o OUTPUT.sql]

Expected CSV columns, by position (header row is skipped):
    Data, Item, Valor, Local, <unused>, Importancia

- Data (purchase date) may be blank; a blank row inherits the last non-blank date.
- Valor accepts both "4.49" and Brazilian "13,1" decimal-comma formats.
- Fully blank rows (CSV section separators) are skipped.
- Importancia, when present, is matched by name against the user's existing
  public.purchase_categories rows; when blank, category_id is left null.
"""
import argparse
import csv
import sys
from pathlib import Path


def parse_valor(raw: str) -> float:
    s = raw.strip()
    if ',' in s and '.' in s:
        s = s.replace('.', '').replace(',', '.')
    elif ',' in s:
        s = s.replace(',', '.')
    return float(s)


def sql_str(value: str) -> str:
    return "'" + value.replace("'", "''") + "'"


def convert(rows, user_id):
    values = []
    categories = set()
    last_date = None
    skipped = 0
    for lineno, row in enumerate(rows, start=2):
        row = [c.strip() for c in row]
        data, item, valor_raw, local, _unused, importancia = row[:6]

        if not any([data, item, valor_raw, local, importancia]):
            continue  # blank separator row

        if data:
            last_date = data
        date = last_date

        if not date or not item or not valor_raw:
            print(f"line {lineno}: missing date/item/valor, skipping", file=sys.stderr)
            skipped += 1
            continue
        try:
            valor = parse_valor(valor_raw)
        except ValueError:
            print(f"line {lineno}: bad valor {valor_raw!r}, skipping", file=sys.stderr)
            skipped += 1
            continue

        local_sql = sql_str(local) if local else 'null'
        if importancia:
            categories.add(importancia)
            category_sql = (
                "(select id from public.purchase_categories "
                f"where user_id = '{user_id}' and name = {sql_str(importancia)})"
            )
        else:
            category_sql = 'null'

        values.append(
            f"  ('{user_id}', '{date}', {sql_str(item)}, {valor:.2f}, "
            f"{local_sql}, {category_sql})"
        )

    return values, categories, skipped


def main():
    parser = argparse.ArgumentParser(description=__doc__,
                                      formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('csv_path', type=Path)
    parser.add_argument('--user-id', required=True,
                         help='UUID of the profiles/auth.users row to own these purchases')
    parser.add_argument('-o', '--output', type=Path, default=None)
    args = parser.parse_args()

    output = args.output or args.csv_path.with_suffix('.sql')

    with args.csv_path.open(newline='', encoding='utf-8') as f:
        reader = csv.reader(f)
        next(reader)  # header
        values, categories, skipped = convert(reader, args.user_id)

    if not values:
        print('No rows to insert.', file=sys.stderr)
        sys.exit(1)

    with output.open('w', encoding='utf-8') as f:
        f.write('begin;\n\n')
        f.write(
            'insert into public.purchases '
            '(user_id, purchase_date, item, valor, local, category_id)\n'
            'values\n'
        )
        f.write(',\n'.join(values))
        f.write('\n;\n\ncommit;\n')

    print(f"Wrote {len(values)} rows to {output} ({skipped} skipped).")
    print(f"Categories referenced: {', '.join(sorted(categories)) or '(none)'}")
    print('Make sure those names already exist in public.purchase_categories for '
          'this user_id, otherwise category_id will silently end up null for '
          'unmatched names.')


if __name__ == '__main__':
    main()
