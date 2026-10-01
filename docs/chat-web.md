---
title: Chat-only Web Build
eyebrow: Recettas · Web · Deployment Guide
standfirst: A web version of Recettas with only login and chat, built from its own entry point, stripped of the app's large assets, and hosted on Firebase Hosting.
meta:
  Project: recettas
  Date: 2026-10-01
  Status: Built, not yet deployed
footer:
  - Recettas
  - 2026-10-01
---

## Summary

The full app bundles every screen, a local SQLite database and about 87 MB of exercise GIFs and posters. A browser visitor who only wants to chat should not pay for any of that.

::: tiles
- label: Before pruning
  figure: 129 MB
  sub: build/web_chat
- label: After pruning
  figure: 43.5 MB
  sub: 37 MB is CanvasKit, loaded one variant at a time
  secondary: true
- label: JS per visitor
  figure: ~2.7 MB
  sub: main.dart.js
  secondary: true
:::

::: callout What a visitor actually downloads
About 2.7 MB of JavaScript, the fonts, and one CanvasKit file. Flutter web fetches individual assets only when code requests them, and the chat never requests the pruned ones.
:::

## What was built

::: plain
- **`lib/main_chat.dart`.** A second entry point. It initializes Supabase and `ChatNotifier`, and shows a login or sign-up form until there is a session, then `ChatListScreen` with a sign-out button.
- **`scripts/build_chat_web.ps1`.** Builds the entry point into `build/web_chat`, then deletes the assets the chat never requests.
:::

### Why a new login screen

The existing `ProfileScreen` imports `home_shell.dart`, which imports every other tab. Reusing it would have pulled the whole app back into the bundle. The new screen is a small standalone form that uses only `SupabaseService.signIn`, `signUp` and `signOut`.

### What the entry point skips

::: split
::: panel Kept
- `Supabase.initialize`
- `ChatNotifier.instance.init()`
- `ChatListScreen` and `ChatRoomScreen`
- `SupabaseService` and the models (tree-shaken)
:::

::: panel Skipped
- `LocalDb.initPlatform()` and the sqlite wasm
- `TodoRepository.init()`
- `HomeShell` and every other screen
- Exercise GIFs and posters, harpa, NVI, chart.js
:::
:::

### What the script prunes

`pubspec.yaml` has a single asset list, so every build copies the large assets whether or not the entry point uses them. The script deletes them from `build/web_chat` after the build:

| Pruned | Reason |
|---|---|
| `assets/assets/exercises`, `exercise_posters` | About 87 MB, never requested by chat |
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

1. **Install the CLI and log in**

   ```
   npm install -g firebase-tools
   firebase login
   ```

2. **Build the chat bundle**

   ```
   powershell -File scripts/build_chat_web.ps1
   ```

3. **Initialize Hosting** from the project root

   ```
   firebase init hosting
   ```

   - Choose "Use an existing project" and pick `recettas-chat`.
   - Public directory: `build/web_chat`.
   - Single-page app (rewrite all URLs to `/index.html`): **yes**.
   - GitHub auto-deploys: **no**.
   - Overwrite `index.html`: **no**.

   This creates `firebase.json` and `.firebaserc`.

4. **Deploy**

   ```
   firebase deploy --only hosting
   ```

   It prints a URL such as `https://recettas-chat.web.app`.

### Supabase redirect URLs

In Supabase, under Authentication → URL Configuration, add `https://recettas-chat.web.app` and `https://recettas-chat.firebaseapp.com` to the Site URL or Redirect URLs. Without this, the email confirmation link from sign-up may point somewhere else. Password login itself should work without it.

### Optional: avoid stale caches

Hosting caches files briefly, so a new deploy can show up late. In `firebase.json`, add a `headers` rule that sets `Cache-Control: no-cache` for `index.html`, `flutter_bootstrap.js` and `main.dart.js`.

## Open items

::: warn Not yet verified
- The build compiles and `flutter analyze` is clean, but login and chat have **not** been tried in a browser.
- `ChatNotifier.init()` runs before login. It should pick up a later sign-in, since `ChatListScreen` re-renders on auth changes, but the unread badge logic lives in the notifier and was not checked.
- Nothing has been deployed yet.
:::
