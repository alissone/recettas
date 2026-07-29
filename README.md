# Recettas

A household app for the family: shared to-dos, purchase/expense tracking (with
receipt photo scanning), and recipes. Built with Flutter and Supabase, targeting
Android, iOS, Windows, macOS and Linux from a single codebase.

## Features

- **Afazeres (To-dos)** — offline-first task list. Drag to reorder, swipe left
  to delete, swipe right to assign a color-coded category. Works fully offline
  and syncs in the background once connectivity returns.
- **Compras (Purchases)** — track expenses by date, item, value, place and
  category. Add entries manually, or snap/upload a receipt photo to have it
  queued for OCR extraction.
- **Receitas (Recipes)** — browse recipes (public, read-only).
- **Hábitos (Habits)** — three trackers behind one summary tab:
  - *Nutrição*: log how much of a food you ate and see the day's nutrient
    intake charted against a named recommendation set. The nutrient and food
    catalogs are seeded by hand in SQL; the app only reads them.
  - *Academia*: per day, which exercises you did — sets, reps and one weight
    each (no drop sets). The exercise catalog, photos included, is seeded by
    hand too.
  - *Hábitos*: custom habits with an icon, color, image and a counter- or
    duration-based goal over a daily/weekly/monthly period, each with a month
    calendar heatmap of how much you did per day.
- **Perfil (Profile)** — Supabase email/password auth and profile info.

## Architecture

- **Flutter** app, single codebase for mobile and desktop.
- **Supabase** (Postgres + Auth + Storage) is the backend. There is no
  CLI-managed migration flow — SQL files under [`migrations/`](migrations) are
  applied by hand, in numeric order, via the Supabase SQL editor. All
  user-owned tables have row-level security scoped to `auth.uid()`; `recipes`,
  `nutrients`, `foods` and `exercises` are public read-only catalogs.
- **Storage buckets**: `receipts` (private, per-user folders) for receipt
  photos, and `habits` (private, readable by any signed-in account) for habit,
  food and exercise pictures. Habit images are uploaded from the app; food and
  exercise images are uploaded through the Supabase dashboard and their
  `image_path` set by hand alongside the catalog rows. Because the bucket is
  private, images are fetched through short-lived signed URLs memoized by
  `SupabaseService.habitImageUrl`.
- **Offline-first sync** (todos only): `lib/services/local_db.dart` keeps a
  SQLite cache (via `sqflite`, or `sqflite_common_ffi` on Windows/Linux), and
  `lib/services/todo_repository.dart` reads/writes that cache first so the UI
  is instant and usable offline. Writes are queued in a local `pending_ops`
  table and pushed to Supabase in the background with retry; a small sync
  indicator in the UI reflects `synced` / `syncing` / `offline` state.
- **Receipt OCR pipeline**: a receipt photo is uploaded to the private
  `receipts` storage bucket and a row is inserted into `receipt_jobs`
  (`queued`). From the Receipt Queue screen, processing is triggered
  **manually** — the image is sent to a local llama.cpp server (Qwen vision
  model) shared over Tailscale, whose CSV response is parsed
  (`receipt_csv_parser.dart`) into `purchases` rows linked back to the job.
  Processing is manual rather than automatic because that server isn't always
  powered on.

## Project layout

```
lib/
  main.dart                    Supabase init, local DB init, app entry
  app_theme.dart                Colors, text styles, shared decorations
  models/                       Todo, TodoCategory, Purchase, ReceiptJob, ...
  screens/                       One file per tab/screen (home_shell.dart is the
                                 bottom-nav shell wiring the six tabs together)
  services/                      Supabase access, local DB/offline sync,
                                 receipt processing + CSV parsing
  utils/, widgets/               Small shared helpers/components
migrations/                     Numbered SQL files, applied by hand and in order
scripts/                        One-off maintenance/import scripts
test/                           Unit tests
```

## Getting started

1. Install the Flutter SDK matching `environment.sdk` in `pubspec.yaml`.
2. `flutter pub get`
3. Apply any not-yet-applied files under `migrations/` in order, via the
   Supabase SQL editor for the project referenced in `lib/main.dart`.
4. `flutter run` (pick a device/platform when prompted).

## Testing

```
flutter test
```

Covers the receipt CSV parser (`test/receipt_csv_parser_test.dart`), which
handles the vision model's CSV quirks: alternate delimiters, decimal-comma
values, and `DD/MM/YYYY` date normalization.

## Scripts

- `scripts/csv_to_purchases_sql.py` — converts an ad-hoc purchases CSV export
  into a SQL script that inserts rows into `public.purchases` (forward-fills
  blank dates, handles Brazilian decimal-comma values, and matches category
  names against the user's existing `purchase_categories`). Run with `-h` for
  usage.
- `scripts/nutrition_report_to_sql.py` — paste a "Relatório completo" page
  from the SR25 food composition table (UNIFESP) and it writes
  `migrations/nutrition/<alimento>.sql`, ready to run in the SQL editor.
  It reads the nutrient catalog straight out of `migrations/` so it cannot
  drift from the database, maps the Portuguese labels to `nutrient_id`s,
  converts between mass units when the report disagrees with the catalog,
  and refuses to guess: an unrecognised nutrient is reported and left out
  rather than matched to something close. Food ids are a `uuid5` of the
  name, so re-running a report updates the same row instead of duplicating
  it. Run with `-h` for usage.
