"""Print what's in the kitchen, as saved by "Guardar o que há na cozinha".

Used by the /receitas Claude command (~/.claude/commands/receitas.md).
Reads pantry_items (migration 042) straight from Supabase with the
transcriber's service role key (transcriber/.env), so it needs no login
and no packages: stdlib only.

By default prints the latest day that has items; --dias N merges the
last N days (a day's list wins over older ones for the same name).

    python scripts/receitas/fetch_pantry.py [--dias N]

Output (stdout, JSON):
    {"dia": "2026-11-02", "hoje": true, "dias": ["2026-11-02"],
     "itens": [{"nome": "Ovo", "quantidade": "meia dúzia"}, ...]}
"""
import argparse
import json
import sys
import urllib.parse
import urllib.request
from datetime import date, timedelta
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ENV = ROOT / "transcriber" / ".env"
DEFAULT_URL = "https://jixjuabvprbyupmaqtma.supabase.co"


def read_env(path: Path) -> dict:
    env = {}
    if not path.exists():
        return env
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        env[key.strip()] = value.strip().strip('"').strip("'")
    return env


def get(url: str, key: str, table: str, params: dict) -> list:
    query = urllib.parse.urlencode(params, safe="*,.()")
    req = urllib.request.Request(
        f"{url}/rest/v1/{table}?{query}",
        headers={"apikey": key, "Authorization": f"Bearer {key}"},
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as res:
            return json.loads(res.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        if e.code == 404:
            sys.exit(f"Tabela {table} não encontrada: rode migrations/042_pantry_items.sql")
        raise


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--dias", type=int, default=1,
                        help="juntar os últimos N dias com itens (padrão 1)")
    args = parser.parse_args()

    env = read_env(ENV)
    url = env.get("SUPABASE_URL") or DEFAULT_URL
    key = env.get("SUPABASE_SERVICE_ROLE_KEY")
    if not key:
        sys.exit(f"SUPABASE_SERVICE_ROLE_KEY não encontrada em {ENV}")

    latest = get(url, key, "pantry_items",
                 {"select": "seen_on", "order": "seen_on.desc", "limit": "1"})
    if not latest:
        print(json.dumps({"dia": None, "hoje": False, "dias": [], "itens": []},
                         ensure_ascii=False))
        return
    last_day = date.fromisoformat(latest[0]["seen_on"])
    since = last_day - timedelta(days=max(1, args.dias) - 1)
    rows = get(url, key, "pantry_items", {
        "select": "name,quantity,seen_on",
        "seen_on": f"gte.{since.isoformat()}",
        "order": "seen_on.desc,created_at.asc",
    })

    items, seen, days = [], set(), []
    for row in rows:
        if row["seen_on"] not in days:
            days.append(row["seen_on"])
        name = row["name"].strip()
        if name.casefold() in seen:
            continue
        seen.add(name.casefold())
        items.append({"nome": name, "quantidade": row.get("quantity")})

    print(json.dumps({
        "dia": last_day.isoformat(),
        "hoje": last_day == date.today(),
        "dias": days,
        "itens": items,
    }, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    main()
