"""Build the printable A4 recipe sheet from a receitas.json.

Used by the /receitas Claude command (~/.claude/commands/receitas.md):
Claude writes the JSON (recipes cooked up from the pantry), this checks
it and lays it out in the black-and-white style of web/print.html.
Stdlib only.

    python scripts/receitas/render.py <receitas.json> [--validar] [--pdf] [--abrir]

--validar   only check the JSON and report problems (exit 1 if any)
--pdf       also print receitas.pdf with headless Chrome/Edge and report
            the page count (the sheet is meant to be exactly one page)
--abrir     open the result (the PDF if made, else the HTML)

receitas.json:
{
  "data": "2026-11-02",
  "despensa": [{"nome": "Ovo", "quantidade": "meia dúzia"}, ...],
  "receitas": [            // one of each categoria, in any order
    {
      "categoria": "principal" | "doce" | "mundo",
      "titulo": "Omelete de abobrinha",
      "pais": "Japão",                 // "mundo" only (required there)
      "descricao": "uma frase",
      "tempo": "20 min",
      "porcoes": "2",
      "ingredientes": [
        {"item": "3 ovos", "origem": "cozinha", "despensa": "Ovo"},
        {"item": "sal e pimenta", "origem": "basico"},
        {"item": "1 limão", "origem": "comprar"}
      ],
      "preparo": ["passo curto", ...],
      "dica": "opcional"
    }
  ],
  "sucos": [               // 2 or 3 juice ideas
    {
      "nome": "Laranja com couve",
      "ingredientes": [    // same shape as a recipe's
        {"item": "2 laranjas", "origem": "cozinha", "despensa": "Laranja"},
        {"item": "1 folha de couve", "origem": "comprar"}
      ],
      "beneficio": "two short lines on why it's good for you"
    }
  ]
}
"origem": cozinha = from the pantry ("despensa" must then name one of
the pantry items exactly), basico = salt/oil/water-type staples assumed
at home, comprar = would need buying.
"""
import argparse
import html
import json
import os
import re
import subprocess
import sys
from datetime import date
from pathlib import Path

CATEGORIES = {
    "principal": "Almoço ou jantar",
    "doce": "Doce rápido",
    "mundo": "Pelo mundo",
}
ORIGINS = {"cozinha": "●", "basico": "○", "comprar": "□"}
WEEKDAYS = ["segunda-feira", "terça-feira", "quarta-feira", "quinta-feira",
            "sexta-feira", "sábado", "domingo"]
MONTHS = ["janeiro", "fevereiro", "março", "abril", "maio", "junho", "julho",
          "agosto", "setembro", "outubro", "novembro", "dezembro"]

# Keep each recipe small enough for the three to share one sheet.
MAX_INGREDIENTS = 12
MAX_STEPS = 7
MAX_STEP_CHARS = 220
MAX_DESC_CHARS = 140
MIN_JUICES, MAX_JUICES = 2, 3
MAX_JUICE_INGREDIENTS = 4
MAX_BENEFIT_CHARS = 170

BROWSERS = [
    r"C:\Program Files\Google\Chrome\Application\chrome.exe",
    r"C:\Program Files (x86)\Google\Chrome\Application\chrome.exe",
    r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
    r"C:\Program Files\Microsoft\Edge\Application\msedge.exe",
]


def validate(data: dict) -> list[str]:
    errors = []
    pantry = {p.get("nome", "").casefold() for p in data.get("despensa", [])}
    try:
        date.fromisoformat(data.get("data", ""))
    except ValueError:
        errors.append('"data" precisa ser AAAA-MM-DD')
    recipes = data.get("receitas", [])
    cats = [r.get("categoria") for r in recipes]
    for cat in CATEGORIES:
        if cats.count(cat) != 1:
            errors.append(f'precisa de exatamente uma receita "{cat}" (tem {cats.count(cat)})')
    for r in recipes:
        name = r.get("titulo") or "(sem título)"
        if r.get("categoria") not in CATEGORIES:
            errors.append(f'{name}: categoria "{r.get("categoria")}" inválida')
        for field in ("titulo", "descricao", "tempo", "porcoes"):
            if not str(r.get(field) or "").strip():
                errors.append(f'{name}: falta "{field}"')
        if r.get("categoria") == "mundo" and not (r.get("pais") or "").strip():
            errors.append(f'{name}: receita "mundo" precisa de "pais"')
        if len(r.get("descricao") or "") > MAX_DESC_CHARS:
            errors.append(f"{name}: descrição com mais de {MAX_DESC_CHARS} caracteres")
        ings = r.get("ingredientes") or []
        if not ings or len(ings) > MAX_INGREDIENTS:
            errors.append(f"{name}: 1 a {MAX_INGREDIENTS} ingredientes (tem {len(ings)})")
        errors += _check_ingredients(name, ings, pantry)
        steps = r.get("preparo") or []
        if not steps or len(steps) > MAX_STEPS:
            errors.append(f"{name}: 1 a {MAX_STEPS} passos (tem {len(steps)})")
        for i, step in enumerate(steps, 1):
            if len(step) > MAX_STEP_CHARS:
                errors.append(f"{name}: passo {i} com mais de {MAX_STEP_CHARS} caracteres")
    juices = data.get("sucos") or []
    if not MIN_JUICES <= len(juices) <= MAX_JUICES:
        errors.append(f'"sucos": {MIN_JUICES} a {MAX_JUICES} (tem {len(juices)})')
    for j in juices:
        name = j.get("nome") or "(suco sem nome)"
        if not (j.get("nome") or "").strip():
            errors.append('suco sem "nome"')
        ings = j.get("ingredientes") or []
        if not ings or len(ings) > MAX_JUICE_INGREDIENTS:
            errors.append(f"{name}: 1 a {MAX_JUICE_INGREDIENTS} ingredientes (tem {len(ings)})")
        errors += _check_ingredients(name, ings, pantry)
        benefit = (j.get("beneficio") or "").strip()
        if not benefit or len(benefit) > MAX_BENEFIT_CHARS:
            errors.append(f'{name}: "beneficio" de 1 a {MAX_BENEFIT_CHARS} caracteres '
                          f'(tem {len(benefit)})')
    return errors


def _check_ingredients(name: str, ings: list, pantry: set) -> list[str]:
    errors = []
    for ing in ings:
        origin = ing.get("origem")
        if origin not in ORIGINS:
            errors.append(f'{name}: origem "{origin}" inválida em "{ing.get("item")}"')
        if origin == "cozinha" and (ing.get("despensa") or "").casefold() not in pantry:
            errors.append(f'{name}: "{ing.get("item")}" é da cozinha mas "despensa" '
                          f'("{ing.get("despensa")}") não é um item da despensa')
    return errors


def used_pantry(data: dict) -> set[str]:
    return {
        (ing.get("despensa") or "").casefold()
        for r in [*data["receitas"], *data.get("sucos", [])]
        for ing in r["ingredientes"]
        if ing.get("origem") == "cozinha"
    }


def esc(value) -> str:
    return html.escape(str(value or ""))


def recipe_html(r: dict, wide: bool) -> str:
    kicker = CATEGORIES[r["categoria"]]
    if r["categoria"] == "mundo":
        kicker += f" · {r['pais']}"
    ings = "".join(
        f'<li><span class="mark">{ORIGINS[i["origem"]]}</span>'
        f'<span class="{"buy" if i["origem"] == "comprar" else ""}">{esc(i["item"])}</span></li>'
        for i in r["ingredientes"])
    steps = "".join(f"<li>{esc(s)}</li>" for s in r["preparo"])
    tip = f'<p class="tip"><b>Dica:</b> {esc(r["dica"])}</p>' if r.get("dica") else ""
    return f"""<article class="recipe{' wide' if wide else ''}">
  <div class="kicker">{esc(kicker)}</div>
  <h2>{esc(r['titulo'])}</h2>
  <div class="meta">{esc(r['tempo'])} · {esc(r['porcoes'])} {'porção' if str(r['porcoes']).strip() == '1' else 'porções'}</div>
  <p class="desc">{esc(r['descricao'])}</p>
  <div class="body">
    <div><h3>Ingredientes</h3><ul class="ings">{ings}</ul></div>
    <div><h3>Preparo</h3><ol class="steps">{steps}</ol>{tip}</div>
  </div>
</article>"""


def juices_html(juices: list) -> str:
    cards = []
    for j in juices:
        ings = " + ".join(
            f'<span class="{"buy" if i["origem"] == "comprar" else ""}">'
            f'{ORIGINS[i["origem"]]}&nbsp;{esc(i["item"])}</span>'
            for i in j["ingredientes"])
        cards.append(f"""<div class="juice">
    <h3>{esc(j['nome'])}</h3>
    <div class="mix">{ings}</div>
    <p>{esc(j['beneficio'])}</p>
  </div>""")
    return f"""<section class="juices">
  <h2 class="section-title">Sucos do dia</h2>
  <div class="juice-row">{''.join(cards)}</div>
</section>"""


def build_html(data: dict) -> str:
    day = date.fromisoformat(data["data"])
    by_cat = {r["categoria"]: r for r in data["receitas"]}
    used = used_pantry(data)
    pantry = data.get("despensa", [])
    rows = []
    for p in pantry:
        is_used = p["nome"].casefold() in used
        qty = f" <small>({esc(p['quantidade'])})</small>" if p.get("quantidade") else ""
        rows.append(f'<li class="{"used" if is_used else "unused"}">'
                    f'<span class="mark">{"●" if is_used else "○"}</span>'
                    f'{esc(p["nome"])}{qty}</li>')
    pantry_items = "".join(rows)
    n_used = sum(1 for p in pantry if p["nome"].casefold() in used)
    css = (Path(__file__).with_name("sheet.css")).read_text(encoding="utf-8")
    return f"""<!DOCTYPE html>
<html lang="pt-BR">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Receitas {day.strftime('%d/%m')}</title>
<style>
{css}
</style>
</head>
<body>
<div class="sheet-wrap"><div class="page">
  <header class="page-header">
    <div>
      <h1>Receitas</h1>
      <div class="owner">com o que tem na cozinha</div>
    </div>
    <div class="date">
      <div class="weekday">{WEEKDAYS[day.weekday()]}</div>
      <div class="day">{day.day} de {MONTHS[day.month - 1]}</div>
    </div>
  </header>

  <section class="pantry-box">
    <h2 class="section-title">Na cozinha <span class="count">usa {n_used} de {len(pantry)}</span></h2>
    <ul>{pantry_items}</ul>
  </section>

  {recipe_html(by_cat['principal'], wide=True)}
  <div class="pair">
    {recipe_html(by_cat['doce'], wide=False)}
    {recipe_html(by_cat['mundo'], wide=False)}
  </div>

  {juices_html(data.get('sucos', []))}

  <footer class="legend">● da cozinha &nbsp;·&nbsp; ○ básico de casa &nbsp;·&nbsp; □ comprar</footer>
</div></div>
</body>
</html>
"""


def find_browser() -> str | None:
    for path in BROWSERS:
        if Path(path).exists():
            return path
    return None


def print_pdf(html_path: Path) -> tuple[Path, int]:
    browser = find_browser()
    if not browser:
        sys.exit("Chrome/Edge não encontrado para gerar o PDF")
    pdf_path = html_path.with_suffix(".pdf")
    subprocess.run(
        [browser, "--headless=new", "--disable-gpu", "--no-pdf-header-footer",
         f"--print-to-pdf={pdf_path}", html_path.as_uri()],
        check=True, capture_output=True, timeout=120)
    pages = len(re.findall(rb"/Type\s*/Page[^s]", pdf_path.read_bytes()))
    return pdf_path, pages


def main() -> None:
    sys.stdout.reconfigure(encoding="utf-8")
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("json", type=Path)
    parser.add_argument("--validar", action="store_true")
    parser.add_argument("--pdf", action="store_true")
    parser.add_argument("--abrir", action="store_true")
    args = parser.parse_args()

    args.json = args.json.resolve()
    data = json.loads(args.json.read_text(encoding="utf-8"))
    errors = validate(data)
    if errors:
        print("Problemas:")
        for e in errors:
            print(f"  - {e}")
        sys.exit(1)
    pantry = data.get("despensa", [])
    used = used_pantry(data)
    unused = [p["nome"] for p in pantry if p["nome"].casefold() not in used]
    print(f"OK: usa {len(pantry) - len(unused)} de {len(pantry)} ingredientes da cozinha"
          + (f" (fora: {', '.join(unused)})" if unused else ""))
    if args.validar:
        return

    html_path = args.json.with_name("receitas.html")
    html_path.write_text(build_html(data), encoding="utf-8")
    print(f"HTML: {html_path}")
    opened = html_path
    if args.pdf:
        pdf_path, pages = print_pdf(html_path)
        print(f"PDF: {pdf_path} ({pages} {'página' if pages == 1 else 'páginas'})")
        if pages != 1:
            print("ATENÇÃO: deveria caber em 1 página - encurte passos ou ingredientes")
        opened = pdf_path
    if args.abrir:
        os.startfile(opened)  # noqa: S606 - Windows only, by design


if __name__ == "__main__":
    main()
