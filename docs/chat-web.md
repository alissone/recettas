---
title: Recettas Web Build
eyebrow: Recettas · Web · Deployment Guide
standfirst: A lightweight web version of Recettas with login, simplified Afazeres, Compras and Gastos tabs, and the chat. It is built from its own entry point, stripped of the app's large assets, and hosted on Firebase Hosting.
meta:
  Project: recettas
  Date: 2026-10-19
  Status: Built, chat deployed earlier; new tabs not yet deployed
footer:
  - Recettas
  - 2026-10-19
---

## Summary

The full app bundles every screen, a local SQLite database and about 87 MB of exercise GIFs and posters. Someone in a browser who only wants to check the lists or chat should not have to download any of that.

::: tiles
- label: Before pruning
  figure: 129 MB
  sub: build/web_chat
- label: After pruning
  figure: 44.0 MB
  sub: 37 MB is CanvasKit, loaded one variant at a time
  secondary: true
- label: JS per visitor
  figure: ~3.2 MB
  sub: main.dart.js (was ~2.7 MB chat-only)
  secondary: true
:::

::: callout What a visitor actually downloads
About 3.2 MB of JavaScript, the fonts, and one CanvasKit file. Flutter web fetches individual assets only when code requests them, and the web screens never request the pruned ones.
:::

## What was built

::: plain
- **`lib/main_chat.dart`.** The web entry point. It initializes Supabase and `ChatNotifier` and shows a login or sign-up form until there is a session. After login it shows a bottom-nav shell with four tabs, in the app's order: Afazeres, Compras, Gastos, Chat. The Chat icon carries the unread badge.
- **`lib/web/`.** Simplified, web-only versions of the three list tabs, plus shared widgets (`web_common.dart`) and the gasto form dialog.
- **Todo methods on `SupabaseService`.** `getOpenTodos`, `getTodoCategories`, `addTodo`, `updateTodo`, `reorderTodos`. These talk to Supabase directly, because the web build has no SQLite cache.
- **`scripts/build_chat_web.ps1`.** Builds the entry point into `build/web_chat`, then deletes the assets the web build never requests.
:::

### The tabs

| Tab | Can do | Left to the app |
|---|---|---|
| **Afazeres** | List open todos in manual order, add, tick, archive, drag to reorder | Editing, categorizing, grouped view, completed todos |
| **Compras** | List items (own and shared lists), add, delete, tick to register a gasto, untick | Managing invites |
| **Gastos** | One month at a time with a total, add, edit, delete (with confirmation) | Receipts and queue, search, reports, auto-categorize, editing categories |
| **Chat** | Same `ChatListScreen` and `ChatRoomScreen` as before | — |

::: plain
- **Afazeres** fetches only todos that are neither completed nor archived. A todo ticked during the session stays visible, struck through, until the next reload. Deleting archives the row, the same as in the app. Reordering writes `sort_order = index`, the same write the app's `TodoRepository` queues, so the order matches on the phone after its next sync. Category colors show as a stripe. "Levar" and event cards show their places or date above the markdown body, read-only.
- **Compras** uses the same rules as the app for shared lists: tabs appear only when more than one list has items. Ticking opens the gasto form (valor, data, local, categoria). The gasto goes to the list the item belongs to, with that list's categories, and Gastos reloads.
- **Gastos** uses the same form for add and edit. New gastos go to the list being shown.
- The **Local** field reuses the app's `LocalField` (frequent places dropdown plus free text). There is no GPS guess on the web.
:::

### Why separate screens

The app's `TodoScreen`, `ShoppingScreen`, `PurchasesScreen` and `ProfileScreen` all import `home_shell.dart`, which imports every other tab. Reusing any of them would pull the whole app back into the bundle. The todo screen also depends on `TodoRepository`, which needs SQLite. The web screens import only models, `SupabaseService`, `app_theme.dart`, `utils/brl.dart`, `ListOwnerTabs` and `LocalField`.

### What the entry point skips

::: split
::: panel Kept
- `Supabase.initialize`
- `ChatNotifier.instance.init()`
- `ChatListScreen` and `ChatRoomScreen`
- `lib/web/` screens
- `SupabaseService` and the models (tree-shaken)
- `flutter_markdown_plus` for todo text
:::

::: panel Skipped
- `LocalDb.initPlatform()` and the sqlite wasm
- `TodoRepository.init()`
- `HomeShell` and the app's full screens
- Receipt scanning, camera, GPS (`LocalGuesser`)
- Exercise GIFs and posters, harpa, NVI, chart.js
:::
:::

### What the script prunes

`pubspec.yaml` has a single asset list, so every build copies the large assets whether or not the entry point uses them. The script deletes them from `build/web_chat` after the build:

| Pruned | Reason |
|---|---|
| `assets/assets/exercises`, `exercise_posters` | About 87 MB, never requested on the web |
| `assets/assets/harpa_crista.json`, `NVI.xml`, `chart.min.js` | Other tabs only |
| `sqlite3.wasm`, `sqflite_sw.js` | Used only by `LocalDb` |

Fonts stay. If you add assets to `pubspec.yaml`, they ship in this build unless you add them to the prune list in the script.

## Build it

```
powershell -File scripts/build_chat_web.ps1
```

Serve `build/web_chat` with any static server to test locally.

## Deploy to Firebase

::: warn Use Hosting, not App Hosting
App Hosting deploys server-rendered frameworks from a GitHub repo and needs the paid Blaze plan. This build is static files, which is what **Firebase Hosting** is for. It works on the free Spark plan (10 GB storage, 360 MB/day transfer). The project is `recettas-chat` either way.
:::

`firebase.json` and `.firebaserc` are already in the repo (public directory `build/web_chat`, SPA rewrite, project `recettas-chat`). To deploy:

```
powershell -File scripts/build_chat_web.ps1
firebase deploy --only hosting
```

It serves at `https://recettas-chat.web.app`.

::: warn "resolving hosting target of a site with no site name"
This assertion means the CLI could not look up the project's default Hosting site. On 2026-10-19 the cause was an **expired login**: `firebase login:list` still showed the account, but API calls returned HTTP 401. Fix it with:

```
firebase login --reauth
```

`firebase hosting:sites:list --project recettas-chat` is a quick way to check that the credentials work before deploying.
:::

### First-time setup (already done)

For reference, the config came from `firebase init hosting` with these answers: use the existing project `recettas-chat`, public directory `build/web_chat`, single-page app **yes**, GitHub auto-deploys **no**, overwrite `index.html` **no**.

### Supabase redirect URLs

In Supabase, under Authentication → URL Configuration, add `https://recettas-chat.web.app` and `https://recettas-chat.firebaseapp.com` to the Site URL or Redirect URLs. Without this, the email confirmation link from sign-up may point somewhere else. Password login itself should work without it.

### Optional: avoid stale caches

Hosting caches files briefly, so a new deploy can show up late. In `firebase.json`, add a `headers` rule that sets `Cache-Control: no-cache` for `index.html`, `flutter_bootstrap.js` and `main.dart.js`.

## Open items

::: warn Not yet verified
- The build compiles and `flutter analyze` is clean, but the Afazeres, Compras and Gastos tabs have **not** been tried in a browser.
- The new tabs have not been deployed yet.
- The site now opens on Afazeres instead of Chat, and the page title is "Recettas" instead of "Recettas Chat".
:::
