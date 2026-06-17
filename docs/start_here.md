
  New Structure

  lib/
    main.dart              - Supabase init + app entry
    app_theme.dart         - All colors, text styles, shadows, decorations
    recipe_view.dart       - Updated to use AppTheme + back button
    models/
      recipe.dart          - Recipe & RecipeSection models
      todo.dart            - Todo model
    services/
      supabase_service.dart - Auth, recipes, todos, profile CRUD
    screens/
      home_shell.dart      - Bottom tab bar (To-Do | Recipes | Profile)
      recipes_screen.dart  - Recipe list with cards, pull-to-refresh
      todo_screen.dart     - Todo list with add/check/swipe-delete
      profile_screen.dart  - Sign in/up form + profile display
  migrations/
    001_create_profiles.sql - profiles table + auto-create trigger
    002_create_recipes.sql  - recipes table + seed with Artisan Bread
    003_create_todos.sql    - todos table with RLS per user

  What you need to do next

    main.dart              - Supabase init + app entry
    app_theme.dart         - All colors, text styles, shadows, decorations
    recipe_view.dart       - Updated to use AppTheme + back button
    models/
      recipe.dart          - Recipe & RecipeSection models
      todo.dart            - Todo model
    services/
      supabase_service.dart - Auth, recipes, todos, profile CRUD
    screens/
      home_shell.dart      - Bottom tab bar (To-Do | Recipes | Profile)
      recipes_screen.dart  - Recipe list with cards, pull-to-refresh
      todo_screen.dart     - Todo list with add/check/swipe-delete
      profile_screen.dart  - Sign in/up form + profile display
  migrations/
    001_create_profiles.sql - profiles table + auto-create trigger
    002_create_recipes.sql  - recipes table + seed with Artisan Bread
    003_create_todos.sql    - todos table with RLS per user



1. Signup feedback banner

After signing up, a green slide-down banner appears: "Account created! Please check your email to confirm your account." After signing in, a warm "Welcome back!" banner appears. The banner auto-dismisses after 4
seconds or can be closed with the X button. It overlays all tabs (same pattern as the MainScaffold in your mvc_app reference).

2. Session persistence

supabase_flutter already persists the session automatically via shared_preferences under the hood -- the Supabase.initialize() call in main() restores it on startup. No extra code needed for this; the user stays
logged in across app restarts.

3. Todo screen auth reactivity + inline editing

- Auth reactivity: The Todo screen now listens to authStateChanges, so it immediately updates when the user signs in from the Profile tab (no more stale "sign in" message).
- Empty state: When logged in with no todos, shows "All clear!" with a "Tap + to add" hint and the FAB.
- Inline add flow: Tapping the FAB enters add mode -- the list disappears, a focused text field appears at the top, and the rest of the screen is a blank tappable area. Tapping outside the text field (or pressing
  Enter) saves the todo and returns to the list. Empty submissions are silently discarded.
