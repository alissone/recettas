"""Validate quiz JSON files and upsert them into Supabase `quizzes`.

Format: docs/quiz-format.md. Table: migrations/044_quizzes.sql.

    python scripts/upload_quiz.py --check quiz.json [more.json ...]
    python scripts/upload_quiz.py quiz.json [more.json ...]

Each file holds one quiz object or a list of them. A quiz without an
"id" gets a fresh UUID, written back into its file so re-uploading
updates the same row instead of creating a duplicate.

Uploading needs the service-role key (clients can only read quizzes):
SUPABASE_SERVICE_ROLE_KEY from the environment, else from
transcriber/.env. Standard library only.
"""

import argparse
import json
import os
import re
import sys
import urllib.error
import urllib.request
import uuid
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SUPABASE_URL = os.environ.get("SUPABASE_URL") or "https://jixjuabvprbyupmaqtma.supabase.co"
LETTERS = "ABCDE"
UUID_RE = re.compile(r"^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", re.I)
HEX_RE = re.compile(r"^#[0-9a-fA-F]{6}$")


def _nonempty_str(value):
    return isinstance(value, str) and value.strip() != ""


def validate(quiz, where):
    """Errors (list of str) and warnings (list of str) for one quiz."""
    errors, warnings = [], []
    if not isinstance(quiz, dict):
        return [f"{where}: quiz must be an object"], []
    if "id" in quiz and not (isinstance(quiz["id"], str) and UUID_RE.match(quiz["id"])):
        errors.append(f"{where}: id must be a UUID")
    if not _nonempty_str(quiz.get("title")):
        errors.append(f"{where}: missing title")
    for key in ("topic", "description", "source"):
        if key in quiz and not isinstance(quiz[key], str):
            errors.append(f"{where}: {key} must be a string")
    if "color" in quiz and not (isinstance(quiz["color"], str) and HEX_RE.match(quiz["color"])):
        errors.append(f"{where}: color must look like #RRGGBB")
    known = {"id", "title", "topic", "description", "source", "color", "questions"}
    for key in quiz.keys() - known:
        warnings.append(f"{where}: unknown field '{key}' (ignored by the app)")

    questions = quiz.get("questions")
    if not isinstance(questions, list) or not questions:
        errors.append(f"{where}: questions must be a non-empty list")
        return errors, warnings

    for n, q in enumerate(questions, 1):
        qw = f"{where} q{n}"
        if not isinstance(q, dict):
            errors.append(f"{qw}: must be an object")
            continue
        if not _nonempty_str(q.get("prompt")):
            errors.append(f"{qw}: missing prompt")
        ctx = q.get("context")
        if ctx is not None:
            if not isinstance(ctx, dict):
                errors.append(f"{qw}: context must be an object")
            else:
                for key in ctx.keys() - {"text", "image_url", "image_caption"}:
                    errors.append(f"{qw}: unknown context field '{key}'")
                url = ctx.get("image_url")
                if url is not None:
                    if not (isinstance(url, str) and url.startswith("https://")):
                        errors.append(f"{qw}: image_url must be an https:// URL")
                    elif url.lower().split("?")[0].endswith(".svg"):
                        errors.append(f"{qw}: SVG images are not supported, use PNG/JPG")
        options = q.get("options")
        if not isinstance(options, list) or not 2 <= len(options) <= 5:
            errors.append(f"{qw}: options must be a list of 2 to 5")
            continue
        for i, opt in enumerate(options):
            ow = f"{qw} {LETTERS[i]}"
            if not isinstance(opt, dict):
                errors.append(f"{ow}: must be an object")
                continue
            if not _nonempty_str(opt.get("text")):
                errors.append(f"{ow}: missing text")
            if not _nonempty_str(opt.get("explanation")):
                errors.append(f"{ow}: missing explanation")
        correct = q.get("correct")
        if not (isinstance(correct, str) and correct in LETTERS[: len(options)]):
            errors.append(f"{qw}: correct must be one of {LETTERS[:len(options)]}")
        texts = [o.get("text", "").strip().lower() for o in options if isinstance(o, dict)]
        if len(set(texts)) != len(texts):
            errors.append(f"{qw}: duplicate option texts")

    letters = Counter(q.get("correct") for q in questions if isinstance(q, dict))
    if len(questions) >= 5 and len(letters) == 1:
        warnings.append(f"{where}: every answer is '{next(iter(letters))}'")
    elif len(questions) >= 8:
        top, count = letters.most_common(1)[0]
        if count > len(questions) * 0.4:
            warnings.append(f"{where}: '{top}' is the answer {count}/{len(questions)} times")
    return errors, warnings


def load_file(path):
    data = json.loads(path.read_text(encoding="utf-8"))
    return data, (data if isinstance(data, list) else [data])


def service_key():
    key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY")
    if key:
        return key
    env = ROOT / "transcriber" / ".env"
    if env.exists():
        for line in env.read_text(encoding="utf-8").splitlines():
            name, _, value = line.partition("=")
            if name.strip() == "SUPABASE_SERVICE_ROLE_KEY" and value.strip():
                return value.strip().strip('"').strip("'")
    sys.exit("SUPABASE_SERVICE_ROLE_KEY not set (environment or transcriber/.env)")


def upsert(rows, key):
    req = urllib.request.Request(
        f"{SUPABASE_URL}/rest/v1/quizzes?on_conflict=id",
        data=json.dumps(rows).encode("utf-8"),
        method="POST",
        headers={
            "apikey": key,
            "Authorization": f"Bearer {key}",
            "Content-Type": "application/json",
            "Prefer": "resolution=merge-duplicates,return=representation",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            return json.loads(r.read() or b"[]")
    except urllib.error.HTTPError as e:
        sys.exit(f"Supabase error {e.code}: {e.read().decode('utf-8', 'replace')}")


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("files", nargs="+", type=Path)
    parser.add_argument("--check", action="store_true", help="validate only, don't upload")
    args = parser.parse_args()

    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")

    all_errors, quizzes, seen_ids = [], [], {}
    for path in args.files:
        try:
            data, items = load_file(path)
        except (OSError, json.JSONDecodeError) as e:
            all_errors.append(f"{path}: {e}")
            continue
        changed = False
        for i, quiz in enumerate(items):
            where = path.name if len(items) == 1 else f"{path.name}[{i}]"
            errors, warnings = validate(quiz, where)
            all_errors += errors
            for w in warnings:
                print(f"warning: {w}")
            if errors:
                continue
            if "id" not in quiz and not args.check:
                quiz["id"] = str(uuid.uuid4())
                changed = True
            qid = quiz.get("id")
            if qid and qid in seen_ids:
                all_errors.append(f"{where}: id {qid} also used in {seen_ids[qid]}")
            seen_ids[qid] = where
            quizzes.append((where, quiz))
        if changed:
            path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
            print(f"{path}: wrote generated id(s) back")

    if all_errors:
        print("\n".join(f"error: {e}" for e in all_errors))
        sys.exit(1)

    for where, quiz in quizzes:
        print(f"ok: {where} - {quiz['title']} ({len(quiz['questions'])} questions)")
    if args.check:
        return

    rows = upsert([{"id": q["id"], "content": q} for _, q in quizzes], service_key())
    print(f"Uploaded {len(rows)} quiz(zes) to {SUPABASE_URL}")


if __name__ == "__main__":
    main()
