import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/chat.dart';
import '../models/exercise.dart';
import '../models/food.dart';
import '../models/gym_entry.dart';
import '../models/habit.dart';
import '../models/list_invite.dart';
import '../models/nutrient.dart';
import '../models/nutrient_recommendation.dart';
import '../models/purchase.dart';
import '../models/purchase_category.dart';
import '../models/receipt_job.dart';
import '../models/recipe.dart';
import '../models/shopping_item.dart';
import '../models/sleep_event.dart';
import '../models/weight_entry.dart';
import 'product_page_parser.dart';

class SupabaseService {
  static SupabaseClient get _client => Supabase.instance.client;

  // Auth
  static User? get currentUser => _client.auth.currentUser;
  static Stream<AuthState> get authStateChanges =>
      _client.auth.onAuthStateChange;

  /// Auth events that change *which data* the user should be seeing.
  ///
  /// Screens must listen to this rather than [authStateChanges], because
  /// it drops `tokenRefreshed`. A token refresh is the same user with the
  /// same rows, but every screen reloading on it turns one refresh into a
  /// reload on each listening screen, and those requests can themselves
  /// trigger a refresh - which fans out again. That feedback loop is what
  /// produces hundreds of "supabase.auth: INFO: Refresh session" lines in
  /// a burst, usually on a cold start with an expired stored session.
  static Stream<AuthState> get authDataChanges => authStateChanges
      .where((state) => state.event != AuthChangeEvent.tokenRefreshed);

  /// True for auth errors caused by connectivity issues (background token
  /// refresh failing because there's no internet), as opposed to a real
  /// auth failure. [authStateChanges] listeners must handle these or they
  /// surface as unhandled exceptions and crash the log.
  static bool isNetworkError(Object error) =>
      error is AuthRetryableFetchException;

  static Future<AuthResponse> signUp(
      String email, String password, String displayName) async {
    return await _client.auth.signUp(
      email: email,
      password: password,
      data: {'display_name': displayName},
    );
  }

  static Future<void> signIn(String email, String password) async {
    await _client.auth.signInWithPassword(email: email, password: password);
  }

  static Future<void> signOut() async {
    await _client.auth.signOut();
  }

  // Recipes (shared rows have a null user_id and are read-only; the
  // ingredient list is what the nutrition log scores a portion by)

  /// Every recipe with its ingredient list, in one request. [catalog]
  /// resolves the ingredients' nutrient values - pass it empty when only
  /// the names and weights are needed.
  static Future<List<Recipe>> getRecipes(
      [Map<NutrientId, Nutrient> catalog = const {}]) async {
    final data = await _client
        .from('recipes')
        .select('*, ingredients:recipe_ingredients(*, '
            'food:foods(*, food_nutrients(nutrient_id, amount)))')
        .order('created_at');
    return data
        .map<Recipe>((json) => Recipe.fromJson(json, catalog))
        .toList();
  }

  /// [ingredients] is a list of `{food_id, amount}` in the order they
  /// should be shown. Returns the new recipe's id.
  static Future<String> createRecipe({
    required String name,
    String? image,
    String? prepTime,
    String? totalTime,
    double? yieldAmount,
    required List<RecipeSection> sections,
    required List<Map<String, dynamic>> ingredients,
  }) async {
    final data = await _client
        .from('recipes')
        .insert({
          'user_id': currentUser!.id,
          'name': name,
          'image': image,
          'prep_time': prepTime,
          'total_time': totalTime,
          'yield_amount': yieldAmount,
          'sections': [for (final s in sections) s.toMap()],
        })
        .select('id')
        .single();
    final id = data['id'] as String;
    await _replaceRecipeIngredients(id, ingredients);
    return id;
  }

  static Future<void> updateRecipe(
    String id, {
    required String name,
    String? image,
    String? prepTime,
    String? totalTime,
    double? yieldAmount,
    required List<RecipeSection> sections,
    required List<Map<String, dynamic>> ingredients,
  }) async {
    await _client.from('recipes').update({
      'name': name,
      'image': image,
      'prep_time': prepTime,
      'total_time': totalTime,
      'yield_amount': yieldAmount,
      'sections': [for (final s in sections) s.toMap()],
    }).eq('id', id);
    await _replaceRecipeIngredients(id, ingredients);
  }

  /// The ingredient list is small and always edited as a whole, so it is
  /// rewritten rather than diffed. Past log entries are unaffected: they
  /// point at the recipe, not at its rows.
  static Future<void> _replaceRecipeIngredients(
      String recipeId, List<Map<String, dynamic>> ingredients) async {
    await _client
        .from('recipe_ingredients')
        .delete()
        .eq('recipe_id', recipeId);
    if (ingredients.isEmpty) return;
    await _client.from('recipe_ingredients').insert([
      for (var i = 0; i < ingredients.length; i++)
        {
          'recipe_id': recipeId,
          'food_id': ingredients[i]['food_id'],
          'amount': ingredients[i]['amount'],
          'sort_order': i,
        }
    ]);
  }

  static Future<void> deleteRecipe(String id) async {
    await _client.from('recipes').delete().eq('id', id);
  }

  // Purchases
  /// Newest first; [fromDate] inclusive and [toDateExclusive] exclusive,
  /// both YYYY-MM-DD, filter server-side (used for the month view).
  /// RLS returns the user's own rows plus every list shared with them
  /// through an accepted invite — group by user_id to split them.
  static Future<List<Purchase>> getPurchases(
      {String? fromDate, String? toDateExclusive}) async {
    var query = _client.from('purchases').select();
    if (fromDate != null) {
      query = query.gte('purchase_date', fromDate);
    }
    if (toDateExclusive != null) {
      query = query.lt('purchase_date', toDateExclusive);
    }
    final data = await query
        .order('purchase_date', ascending: false)
        .order('created_at', ascending: false);
    return data.map<Purchase>((json) => Purchase.fromJson(json)).toList();
  }

  /// Returns the id of the created purchase. [ownerId] targets a
  /// shared list; defaults to the signed-in user's own list.
  static Future<String> addPurchase({
    required String purchaseDate,
    required String item,
    required double valor,
    String? local,
    String? categoryId,
    String? ownerId,
  }) async {
    final data = await _client
        .from('purchases')
        .insert({
          'user_id': ownerId ?? currentUser!.id,
          'purchase_date': purchaseDate,
          'item': item,
          'valor': valor,
          'local': local,
          'category_id': categoryId,
        })
        .select('id')
        .single();
    return data['id'] as String;
  }

  static Future<void> insertPurchases(
      List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) return;
    await _client.from('purchases').insert(rows);
  }

  static Future<void> updatePurchase(
      String id, Map<String, dynamic> fields) async {
    await _client.from('purchases').update(fields).eq('id', id);
  }

  /// Sets the category of several purchases in one request.
  static Future<void> updatePurchasesCategory(
      List<String> ids, String categoryId) async {
    if (ids.isEmpty) return;
    await _client
        .from('purchases')
        .update({'category_id': categoryId}).inFilter('id', ids);
  }

  static Future<void> deletePurchase(String id) async {
    await _client.from('purchases').delete().eq('id', id);
  }

  // Shopping list ("Compras": reminders of stuff to buy)
  static Future<List<ShoppingItem>> getShoppingItems() async {
    final data = await _client
        .from('shopping_items')
        .select()
        .order('is_purchased', ascending: true)
        .order('created_at', ascending: false);
    return data
        .map<ShoppingItem>((json) => ShoppingItem.fromJson(json))
        .toList();
  }

  /// [ownerId] targets a shared list; defaults to the user's own.
  static Future<void> addShoppingItem(String item,
      {String? ownerId}) async {
    await _client.from('shopping_items').insert({
      'user_id': ownerId ?? currentUser!.id,
      'item': item,
    });
  }

  static Future<void> updateShoppingItem(
      String id, Map<String, dynamic> fields) async {
    await _client.from('shopping_items').update(fields).eq('id', id);
  }

  static Future<void> deleteShoppingItem(String id) async {
    await _client.from('shopping_items').delete().eq('id', id);
  }

  // Shared lists: invites give another account full access to the
  // inviter's Gastos + Compras lists (see migrations 012/013).
  static Future<void> sendListInvite(String email) async {
    await _client.from('list_invites').insert({
      'inviter_id': currentUser!.id,
      'invitee_email': email.trim().toLowerCase(),
    });
  }

  static Future<List<ListInvite>> getSentInvites() async {
    final data = await _client
        .from('list_invites')
        .select()
        .eq('inviter_id', currentUser!.id)
        .order('created_at', ascending: false);
    return data
        .map<ListInvite>((json) => ListInvite.fromJson(json))
        .toList();
  }

  /// Invites other users sent to this account's email.
  static Future<List<ListInvite>> getReceivedInvites() async {
    final data = await _client
        .from('list_invites')
        .select('*, inviter:profiles!list_invites_inviter_id_fkey('
            'display_name, email)')
        .neq('inviter_id', currentUser!.id)
        .order('created_at', ascending: false);
    return data
        .map<ListInvite>((json) => ListInvite.fromJson(json))
        .toList();
  }

  /// Accepting or declining claims the invite: RLS requires the update
  /// to set invitee_id to the responding user.
  static Future<void> respondToListInvite(String id,
      {required bool accept}) async {
    await _client.from('list_invites').update({
      'status': accept ? 'accepted' : 'declined',
      'invitee_id': currentUser!.id,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id);
  }

  /// Revokes a sent invite (and the access it granted).
  static Future<void> deleteListInvite(String id) async {
    await _client.from('list_invites').delete().eq('id', id);
  }

  /// Lists the user can read and write: their own first, then one per
  /// accepted invite, named after the inviter.
  static Future<List<ListOwner>> getListOwners() async {
    final me = currentUser!;
    final data = await _client
        .from('list_invites')
        .select('inviter_id, inviter:profiles!list_invites_inviter_id_fkey('
            'display_name, email)')
        .eq('invitee_id', me.id)
        .eq('status', 'accepted');
    return [
      ListOwner(id: me.id, name: 'Minha lista', isMine: true),
      for (final row in data)
        ListOwner(
          id: row['inviter_id'] as String,
          name: ((row['inviter'] as Map<String, dynamic>?)?['display_name'] ??
              (row['inviter'] as Map<String, dynamic>?)?['email'] ??
              'Lista compartilhada') as String,
          isMine: false,
        ),
    ];
  }

  // Purchase categories ("Importância")
  static Future<List<PurchaseCategory>> getPurchaseCategories() async {
    final data = await _client
        .from('purchase_categories')
        .select()
        .order('created_at');
    return data
        .map<PurchaseCategory>((json) => PurchaseCategory.fromJson(json))
        .toList();
  }

  /// Returns the id of the created category. [ownerId] targets a
  /// shared list; defaults to the user's own.
  static Future<String> addPurchaseCategory(String name, int colorValue,
      {String? ownerId}) async {
    final data = await _client
        .from('purchase_categories')
        .insert({
          'user_id': ownerId ?? currentUser!.id,
          'name': name,
          'color_value': colorValue,
        })
        .select('id')
        .single();
    return data['id'] as String;
  }

  static Future<void> updatePurchaseCategory(String id,
      {String? name, int? colorValue}) async {
    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (colorValue != null) updates['color_value'] = colorValue;
    await _client.from('purchase_categories').update(updates).eq('id', id);
  }

  static Future<void> deletePurchaseCategory(String id) async {
    await _client.from('purchase_categories').delete().eq('id', id);
  }

  // Receipt jobs (queue of receipt photos waiting for the local LLM)
  static Future<List<ReceiptJob>> getReceiptJobs() async {
    final data = await _client
        .from('receipt_jobs')
        .select()
        .order('created_at', ascending: false);
    return data.map<ReceiptJob>((json) => ReceiptJob.fromJson(json)).toList();
  }

  static Future<void> createReceiptJob(String id, String imagePath) async {
    await _client.from('receipt_jobs').insert({
      'id': id,
      'user_id': currentUser!.id,
      'image_path': imagePath,
    });
  }

  static Future<void> updateReceiptJob(
    String id, {
    ReceiptJobStatus? status,
    String? errorMessage,
    int? itemsCount,
  }) async {
    await _client.from('receipt_jobs').update({
      if (status != null) 'status': status.name,
      'error_message': errorMessage,
      if (itemsCount != null) 'items_count': itemsCount,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id);
  }

  static Future<void> deleteReceiptJob(ReceiptJob job) async {
    await _client.storage.from('receipts').remove([job.imagePath]);
    await _client.from('receipt_jobs').delete().eq('id', job.id);
  }

  // Receipt images (Supabase storage bucket)
  static Future<void> uploadReceiptImage(
      String path, Uint8List bytes) async {
    await _client.storage.from('receipts').uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(contentType: 'image/jpeg'),
        );
  }

  static Future<Uint8List> downloadReceiptImage(String path) async {
    return await _client.storage.from('receipts').download(path);
  }

  // Accelerometer recordings (bursts of [t_ms, x, y, z] vectors)
  static Future<void> insertAccelRecording({
    required DateTime recordedAt,
    required List<List<double>> samples,
    required String category,
  }) async {
    await _client.from('accel_recordings').insert({
      'user_id': currentUser!.id,
      'recorded_at': recordedAt.toUtc().toIso8601String(),
      'sample_count': samples.length,
      'samples': samples,
      'category': category,
    });
  }

  // Sleep events
  static Future<List<SleepEvent>> getSleepEvents(
      {required DateTime from, DateTime? to}) async {
    var query = _client
        .from('sleep_events')
        .select()
        .gte('occurred_at', from.toUtc().toIso8601String());
    if (to != null) {
      query = query.lt('occurred_at', to.toUtc().toIso8601String());
    }
    final data = await query.order('occurred_at', ascending: true);
    return data
        .map<SleepEvent>((json) => SleepEvent.fromJson(json))
        .toList();
  }

  /// All sleep events for the user, oldest first. Paginates past the
  /// PostgREST 1000-row response cap.
  static Future<List<SleepEvent>> getAllSleepEvents() async {
    const pageSize = 1000;
    final events = <SleepEvent>[];
    var offset = 0;
    while (true) {
      final data = await _client
          .from('sleep_events')
          .select()
          .order('occurred_at', ascending: true)
          .range(offset, offset + pageSize - 1);
      events.addAll(data.map<SleepEvent>((json) => SleepEvent.fromJson(json)));
      if (data.length < pageSize) break;
      offset += pageSize;
    }
    return events;
  }

  static Future<void> addSleepEvent(
      String eventType, DateTime occurredAt) async {
    await _client.from('sleep_events').insert({
      'user_id': currentUser!.id,
      'event_type': eventType,
      'occurred_at': occurredAt.toUtc().toIso8601String(),
    });
  }

  static Future<void> deleteSleepEvent(String id) async {
    await _client.from('sleep_events').delete().eq('id', id);
  }

  // Nutrition (hand-seeded nutrient + food catalogs, per-day food log)

  /// The public.nutrients catalog. Rows naming a nutrient this build
  /// doesn't know are skipped rather than defaulted - see
  /// Nutrient.fromJson.
  static Future<List<Nutrient>> getNutrientCatalog() async {
    final data =
        await _client.from('nutrients').select().order('sort_order');
    return data
        .map(Nutrient.fromJson)
        .whereType<Nutrient>()
        .toList();
  }

  /// Every food plus its nutrient values, in one request. RLS makes the
  /// shared catalog (user_id null) visible alongside the user's own.
  static Future<List<Food>> getFoods(
      Map<NutrientId, Nutrient> catalog) async {
    final data = await _client
        .from('foods')
        .select('*, food_nutrients(nutrient_id, amount)')
        .order('name');
    return data.map<Food>((json) => Food.fromJson(json, catalog)).toList();
  }

  /// Fixed-size packages of catalogued foods. Shared rows (user_id null)
  /// come back alongside the user's own, same as [getFoods].
  static Future<List<FoodPackage>> getFoodPackages() async {
    final data =
        await _client.from('food_packages').select().order('amount');
    return data
        .map<FoodPackage>((json) => FoodPackage.fromJson(json))
        .toList();
  }

  static Future<void> createFoodPackage({
    required String foodId,
    String? name,
    required double amount,
  }) async {
    await _client.from('food_packages').insert({
      'user_id': currentUser!.id,
      'food_id': foodId,
      'name': name,
      'amount': amount,
    });
  }

  static Future<void> updateFoodPackage(
    String id, {
    required String foodId,
    String? name,
    required double amount,
  }) async {
    await _client.from('food_packages').update({
      'food_id': foodId,
      'name': name,
      'amount': amount,
    }).eq('id', id);
  }

  static Future<void> deleteFoodPackage(String id) async {
    await _client.from('food_packages').delete().eq('id', id);
  }

  /// Inserts or updates a food this user scanned (product_scanner_screen.dart)
  /// plus its recognized nutrients, as one call. [foodId] is the uuid5 from
  /// ProductPageParser.foodUuidFor - re-scanning the same product updates
  /// this user's own row instead of duplicating it. Throws
  /// [PostgrestException] with code '42501' if [foodId] belongs to the
  /// shared catalog or another user, since foods RLS only allows updating
  /// rows this user owns.
  static Future<void> upsertScannedFood({
    required String foodId,
    required String name,
    String? brand,
    required double baseAmount,
    required String baseUnit,
    required List<ParsedNutritionRow> nutrients,
  }) async {
    await _client.from('foods').upsert({
      'id': foodId,
      'user_id': currentUser!.id,
      'name': name,
      'brand': brand,
      'base_amount': baseAmount,
      'base_unit': baseUnit,
    });
    if (nutrients.isEmpty) return;
    await _client.from('food_nutrients').upsert([
      for (final n in nutrients)
        {
          'food_id': foodId,
          'nutrient_id': n.nutrientId.name,
          'amount': n.amount,
        },
    ], onConflict: 'food_id,nutrient_id');
  }

  /// Food log between two YYYY-MM-DD dates, [toDateExclusive] excluded.
  static Future<List<FoodEntry>> getFoodEntries({
    required String fromDate,
    required String toDateExclusive,
    required Map<NutrientId, Nutrient> catalog,
  }) async {
    final data = await _client
        .from('food_entries')
        .select('*, food:foods(*, food_nutrients(nutrient_id, amount)), '
            'package:food_packages(*), '
            'recipe:recipes(*, ingredients:recipe_ingredients(*, '
            'food:foods(*, food_nutrients(nutrient_id, amount))))')
        .gte('entry_date', fromDate)
        .lt('entry_date', toDateExclusive)
        .order('entry_date', ascending: false)
        .order('created_at', ascending: false);
    return data
        .map<FoodEntry>((json) => FoodEntry.fromJson(json, catalog))
        .toList();
  }

  /// Logs a portion. Exactly one of [foodId] and [recipeId] is set;
  /// [packageId] only records which package [amount] was derived from.
  static Future<void> addFoodEntry({
    required String entryDate,
    String? foodId,
    String? recipeId,
    String? packageId,
    required double amount,
  }) async {
    await _client.from('food_entries').insert({
      'user_id': currentUser!.id,
      'entry_date': entryDate,
      'food_id': foodId,
      'recipe_id': recipeId,
      'package_id': packageId,
      'amount': amount,
    });
  }

  static Future<void> updateFoodEntry(
      String id, Map<String, dynamic> fields) async {
    await _client.from('food_entries').update(fields).eq('id', id);
  }

  static Future<void> deleteFoodEntry(String id) async {
    await _client.from('food_entries').delete().eq('id', id);
  }

  /// Shared presets plus the user's own sets (RLS returns both).
  static Future<List<NutrientRecommendationSet>>
      getRecommendationSets() async {
    final data = await _client
        .from('nutrient_recommendation_sets')
        .select()
        .order('name');
    return data
        .map<NutrientRecommendationSet>(
            (json) => NutrientRecommendationSet.fromJson(json))
        .toList();
  }

  static Future<List<NutrientRecommendation>> getRecommendations(
      String setId) async {
    final data = await _client
        .from('nutrient_recommendations')
        .select()
        .eq('set_id', setId);
    return data
        .map(NutrientRecommendation.fromJson)
        .whereType<NutrientRecommendation>()
        .toList();
  }

  static Future<String> createRecommendationSet({
    required String name,
    String? description,
  }) async {
    final data = await _client
        .from('nutrient_recommendation_sets')
        .insert({
          'user_id': currentUser!.id,
          'name': name,
          'description': description,
        })
        .select('id')
        .single();
    return data['id'] as String;
  }

  /// Bulk-copies targets into [setId] - used when a user forks a shared
  /// preset into a set they own and can edit.
  static Future<void> addRecommendations(
    String setId,
    List<NutrientRecommendation> recommendations,
  ) async {
    if (recommendations.isEmpty) return;
    await _client.from('nutrient_recommendations').insert([
      for (final r in recommendations)
        {
          'set_id': setId,
          'nutrient_id': r.nutrient.name,
          'amount': r.amount,
          'unit': r.unit.name,
        }
    ]);
  }

  /// One target per (set, nutrient), via the unique index from
  /// migration 016.
  static Future<void> upsertRecommendation({
    required String setId,
    required NutrientId nutrient,
    required double amount,
    required NutrientUnit unit,
  }) async {
    await _client.from('nutrient_recommendations').upsert({
      'set_id': setId,
      'nutrient_id': nutrient.name,
      'amount': amount,
      'unit': unit.name,
    }, onConflict: 'set_id,nutrient_id');
  }

  static Future<void> deleteRecommendation({
    required String setId,
    required NutrientId nutrient,
  }) async {
    await _client
        .from('nutrient_recommendations')
        .delete()
        .eq('set_id', setId)
        .eq('nutrient_id', nutrient.name);
  }

  static Future<void> deleteRecommendationSet(String id) async {
    await _client
        .from('nutrient_recommendation_sets')
        .delete()
        .eq('id', id);
  }

  /// Null clears the active set, leaving the charts without targets.
  static Future<void> setActiveRecommendationSet(String? setId) async {
    await _client
        .from('profiles')
        .update({'active_recommendation_set_id': setId})
        .eq('id', currentUser!.id);
  }

  // Gym (shared exercise catalog, one row per exercise per day)
  static Future<List<Exercise>> getExercises() async {
    final data = await _client
        .from('exercises')
        .select()
        .order('sort_order')
        .order('name');
    return data.map<Exercise>((json) => Exercise.fromJson(json)).toList();
  }

  /// Gym log between two YYYY-MM-DD dates, [toDateExclusive] excluded.
  static Future<List<GymEntry>> getGymEntries({
    required String fromDate,
    required String toDateExclusive,
  }) async {
    final data = await _client
        .from('gym_entries')
        .select('*, exercise:exercises(*)')
        .gte('entry_date', fromDate)
        .lt('entry_date', toDateExclusive)
        .order('entry_date', ascending: false)
        .order('created_at', ascending: true);
    return data.map<GymEntry>((json) => GymEntry.fromJson(json)).toList();
  }

  /// One row per set group (sets x reps at one weight) of one exercise on
  /// one day - an exercise can have several on the same day, e.g. a top
  /// set plus lighter drop sets. Pass [id] to update an existing set
  /// group in place; omit it to add a new one.
  static Future<void> saveGymEntrySet({
    String? id,
    required String entryDate,
    required String exerciseId,
    required int sets,
    required int reps,
    double? weight,
    String? notes,
  }) async {
    final payload = {
      'user_id': currentUser!.id,
      'entry_date': entryDate,
      'exercise_id': exerciseId,
      'sets': sets,
      'reps': reps,
      'weight': weight,
      'notes': notes,
    };
    if (id == null) {
      await _client.from('gym_entries').insert(payload);
    } else {
      await _client.from('gym_entries').update(payload).eq('id', id);
    }
  }

  static Future<void> deleteGymEntry(String id) async {
    await _client.from('gym_entries').delete().eq('id', id);
  }

  /// The whole training log, newest first, with each entry's exercise
  /// joined. The history screen groups it per exercise client-side: the
  /// table holds one row per exercise per day, so even years of training
  /// is a few thousand rows - cheaper than a query per exercise.
  static Future<List<GymEntry>> getAllGymEntries() async {
    final data = await _client
        .from('gym_entries')
        .select('*, exercise:exercises(*)')
        .eq('user_id', currentUser!.id)
        .order('entry_date', ascending: false)
        .order('created_at', ascending: false);
    return data.map<GymEntry>((json) => GymEntry.fromJson(json)).toList();
  }

  /// Most recently logged weight per exercise, for the "latest PR" line in
  /// the exercise gallery. Entries come back newest-first, so the first
  /// weighted row seen per exercise is the one kept.
  static Future<Map<String, double>> getLatestExerciseWeights() async {
    final data = await _client
        .from('gym_entries')
        .select('exercise_id, weight, entry_date')
        .eq('user_id', currentUser!.id)
        .order('entry_date', ascending: false)
        .order('created_at', ascending: false);
    final latest = <String, double>{};
    for (final row in data) {
      final exerciseId = row['exercise_id'] as String;
      if (latest.containsKey(exerciseId)) continue;
      final weight = row['weight'] != null
          ? double.tryParse(row['weight'].toString())
          : null;
      if (weight != null && weight > 0) latest[exerciseId] = weight;
    }
    return latest;
  }

  // Habits (custom habits and their daily logs)
  static Future<List<Habit>> getHabits() async {
    final data = await _client
        .from('habits')
        .select()
        .eq('is_archived', false)
        .order('sort_order')
        .order('created_at');
    return data.map<Habit>((json) => Habit.fromJson(json)).toList();
  }

  static Future<String> addHabit({
    required String name,
    String? description,
    required String iconName,
    required int colorValue,
    String? imagePath,
    required HabitGoalType goalType,
    required double goalTarget,
    String? goalUnit,
    required HabitPeriod period,
  }) async {
    final data = await _client
        .from('habits')
        .insert({
          'user_id': currentUser!.id,
          'name': name,
          'description': description,
          'icon_name': iconName,
          'color_value': colorValue,
          'image_path': imagePath,
          'goal_type': goalType.name,
          'goal_target': goalTarget,
          'goal_unit': goalUnit,
          'period': period.name,
        })
        .select('id')
        .single();
    return data['id'] as String;
  }

  static Future<void> updateHabit(
      String id, Map<String, dynamic> fields) async {
    await _client.from('habits').update(fields).eq('id', id);
  }

  static Future<void> deleteHabit(String id) async {
    await _client.from('habits').delete().eq('id', id);
  }

  /// Habit logs between two YYYY-MM-DD dates, [toDateExclusive]
  /// excluded. Omit [habitId] for every habit at once.
  static Future<List<HabitLog>> getHabitLogs({
    required String fromDate,
    required String toDateExclusive,
    String? habitId,
  }) async {
    var query = _client
        .from('habit_logs')
        .select()
        .gte('log_date', fromDate)
        .lt('log_date', toDateExclusive);
    if (habitId != null) query = query.eq('habit_id', habitId);
    final data = await query.order('created_at', ascending: true);
    return data.map<HabitLog>((json) => HabitLog.fromJson(json)).toList();
  }

  static Future<void> addHabitLog({
    required String habitId,
    required String logDate,
    double value = 1,
  }) async {
    await _client.from('habit_logs').insert({
      'user_id': currentUser!.id,
      'habit_id': habitId,
      'log_date': logDate,
      'value': value,
    });
  }

  static Future<void> deleteHabitLog(String id) async {
    await _client.from('habit_logs').delete().eq('id', id);
  }

  // Habit images (shared "habits" storage bucket: foods, exercises,
  // habits). Objects are stored as "<user_id>/<kind>/<id>.jpg".
  // Keyed by object path. Holds the Future rather than the resolved URL
  // so widgets building in the same frame share one signing request
  // instead of each firing its own.
  static final Map<String, Future<String>> _habitImageUrls = {};

  static Future<void> uploadHabitImage(
      String path, Uint8List bytes) async {
    await _client.storage.from('habits').uploadBinary(
          path,
          bytes,
          // Unlike receipts, a habit photo can be replaced.
          fileOptions: const FileOptions(
              contentType: 'image/jpeg', upsert: true),
        );
    _habitImageUrls.remove(path);
  }

  /// Signed URL for an object in the bucket, memoized for the life of
  /// the process. The bucket is private, so getPublicUrl would fail; the
  /// memo also keeps the URL - and therefore Flutter's ImageCache key -
  /// stable across rebuilds, otherwise every rebuild re-downloads the
  /// image. If the bucket is ever made public, the whole body becomes
  /// `_client.storage.from('habits').getPublicUrl(path)`.
  static Future<String> habitImageUrl(String path) {
    final cached = _habitImageUrls[path];
    if (cached != null) return cached;
    final future = _signHabitImage(path);
    _habitImageUrls[path] = future;
    return future;
  }

  static Future<String> _signHabitImage(String path) async {
    try {
      // A day outlives any realistic session, so a memoized URL never
      // expires while it is still in the map.
      return await _client.storage
          .from('habits')
          .createSignedUrl(path, 60 * 60 * 24);
    } catch (_) {
      // Never cache a failure: otherwise one flaky request means the
      // image can't load again for the rest of the session.
      _habitImageUrls.remove(path);
      rethrow;
    }
  }

  static Future<void> deleteHabitImage(String path) async {
    await _client.storage.from('habits').remove([path]);
    _habitImageUrls.remove(path);
  }

  // Profile
  static Future<Map<String, dynamic>?> getProfile() async {
    if (currentUser == null) return null;
    final data = await _client
        .from('profiles')
        .select()
        .eq('id', currentUser!.id)
        .single();
    return data;
  }

  static Future<void> updateProfile({
    String? displayName,
    String? avatarUrl,
    double? heightCm,
    double? weightKg,
    String? sex,
    int? age,
    String? goal,
    String? goalRate,
    int? weightliftingDaysPerWeek,
    int? weightliftingMinutesPerSession,
    int? cardioDaysPerWeek,
    String? cardioType,
    int? cardioMinutesPerSession,
    int? averageDailySteps,
    String? occupationActivity,
    double? bodyFatPercent,
    String? cardioIntensity,
    int? cardioHeartRate,
    String? liftingIntensity,
  }) async {
    final updates = <String, dynamic>{};
    if (displayName != null) updates['display_name'] = displayName;
    if (avatarUrl != null) updates['avatar_url'] = avatarUrl;
    if (heightCm != null) updates['height_cm'] = heightCm;
    if (weightKg != null) updates['weight_kg'] = weightKg;
    if (sex != null) updates['sex'] = sex;
    if (age != null) updates['age'] = age;
    if (goal != null) updates['goal'] = goal;
    if (goalRate != null) updates['goal_rate'] = goalRate;
    if (weightliftingDaysPerWeek != null) {
      updates['weightlifting_days_per_week'] = weightliftingDaysPerWeek;
    }
    if (weightliftingMinutesPerSession != null) {
      updates['weightlifting_minutes_per_session'] =
          weightliftingMinutesPerSession;
    }
    if (cardioDaysPerWeek != null) {
      updates['cardio_days_per_week'] = cardioDaysPerWeek;
    }
    if (cardioType != null) updates['cardio_type'] = cardioType;
    if (cardioMinutesPerSession != null) {
      updates['cardio_minutes_per_session'] = cardioMinutesPerSession;
    }
    if (averageDailySteps != null) {
      updates['average_daily_steps'] = averageDailySteps;
    }
    if (occupationActivity != null) {
      updates['occupation_activity'] = occupationActivity;
    }
    if (bodyFatPercent != null) {
      updates['body_fat_percent'] = bodyFatPercent;
    }
    if (cardioIntensity != null) {
      updates['cardio_intensity'] = cardioIntensity;
    }
    if (cardioHeartRate != null) {
      updates['cardio_heart_rate'] = cardioHeartRate;
    }
    if (liftingIntensity != null) {
      updates['lifting_intensity'] = liftingIntensity;
    }
    if (updates.isEmpty) return;

    await _client
        .from('profiles')
        .update(updates)
        .eq('id', currentUser!.id);
  }

  // Weight history
  static Future<List<WeightEntry>> getWeightEntries(
      {required DateTime from, DateTime? to}) async {
    var query = _client
        .from('weight_entries')
        .select()
        .eq('user_id', currentUser!.id)
        .gte('recorded_at', from.toUtc().toIso8601String());
    if (to != null) {
      query = query.lt('recorded_at', to.toUtc().toIso8601String());
    }
    final data = await query.order('recorded_at', ascending: true);
    return data
        .map<WeightEntry>((json) => WeightEntry.fromJson(json))
        .toList();
  }

  static Future<void> addWeightEntry(double weightKg,
      {DateTime? recordedAt}) async {
    await _client.from('weight_entries').insert({
      'user_id': currentUser!.id,
      'weight_kg': weightKg,
      'recorded_at': (recordedAt ?? DateTime.now()).toUtc().toIso8601String(),
    });
  }

  // Chat (migration 031): one-to-one rooms keyed by the two members'
  // e-mail addresses. RLS scopes every read to rooms the signed-in
  // address belongs to, which is why the streams below carry no filter
  // of their own.

  /// Lowercased address of the signed-in account - the key every chat
  /// row is matched on.
  static String? get currentEmail => currentUser?.email?.toLowerCase();

  /// The room for [email], opening it on first use. Safe to call
  /// repeatedly: the unique index on the sorted member pair means a
  /// concurrent open by the other side is a duplicate-key error, which
  /// resolves to the row that won.
  static Future<ChatRoom> openChatRoom(String email) async {
    final me = currentUser!;
    final myEmail = me.email!.toLowerCase();
    final other = email.trim().toLowerCase();
    if (other.isEmpty) {
      throw ArgumentError('Informe um e-mail');
    }
    if (other == myEmail) {
      throw ArgumentError('Você não pode conversar consigo mesmo');
    }
    final members = [myEmail, other]..sort();

    final existing = await _findChatRoom(members);
    if (existing != null) return existing;

    try {
      final data = await _client
          .from('chat_rooms')
          .insert({'created_by': me.id, 'member_emails': members})
          .select()
          .single();
      return ChatRoom.fromJson(data);
    } on PostgrestException catch (e) {
      // 23505: the other side opened the same room first.
      if (e.code != '23505') rethrow;
      final raced = await _findChatRoom(members);
      if (raced == null) rethrow;
      return raced;
    }
  }

  /// `contains` is an exact match here: rooms always have exactly the
  /// two members the trigger normalized them down to.
  static Future<ChatRoom?> _findChatRoom(List<String> members) async {
    final data = await _client
        .from('chat_rooms')
        .select()
        .contains('member_emails', members)
        .limit(1);
    if (data.isEmpty) return null;
    return ChatRoom.fromJson(data.first);
  }

  /// The inbox, newest activity first, updating as messages land. No
  /// `.eq()` filter: RLS already limits the rows to this account's
  /// rooms, and the pair of members isn't a single-column match.
  static Stream<List<ChatRoom>> streamChatRooms() {
    return _client
        .from('chat_rooms')
        .stream(primaryKey: ['id'])
        .map((rows) {
      final rooms = rows.map<ChatRoom>(ChatRoom.fromJson).toList()
        ..sort((a, b) => b.sortTime.compareTo(a.sortTime));
      return rooms;
    });
  }

  /// One room's messages, oldest first, updating as they arrive.
  ///
  /// The sort is redone here rather than left to the builder: its
  /// `order()` defaults to *descending*, and realtime inserts arrive in
  /// delivery order regardless. The id breaks ties so two messages
  /// written in the same millisecond keep a stable position instead of
  /// swapping places on every rebuild.
  static Stream<List<ChatMessage>> streamChatMessages(String roomId) {
    return _client
        .from('chat_messages')
        .stream(primaryKey: ['id'])
        .eq('room_id', roomId)
        .order('created_at', ascending: true)
        .map((rows) {
      final messages = rows.map<ChatMessage>(ChatMessage.fromJson).toList()
        ..sort((a, b) {
          final byTime = a.createdAt.compareTo(b.createdAt);
          return byTime != 0 ? byTime : a.id.compareTo(b.id);
        });
      return messages;
    });
  }

  static Future<void> sendChatMessage(
      String roomId, String content) async {
    final me = currentUser!;
    await _client.from('chat_messages').insert({
      'room_id': roomId,
      'sender_id': me.id,
      'sender_email': me.email!.toLowerCase(),
      'content': content,
    });
  }

  /// Display names for the given addresses. Only chat partners are
  /// readable (migration 031's profiles policy), and an address with no
  /// account yet simply has no entry - the UI shows the address.
  static Future<Map<String, String>> getChatPartnerNames(
      Iterable<String> emails) async {
    final wanted = emails.map((e) => e.toLowerCase()).toSet().toList();
    if (wanted.isEmpty) return {};
    final data = await _client
        .from('profiles')
        .select('email, display_name')
        .inFilter('email', wanted);
    final names = <String, String>{};
    for (final row in data) {
      final email = (row['email'] as String?)?.toLowerCase();
      final name = row['display_name'] as String?;
      if (email != null && name != null && name.trim().isNotEmpty) {
        names[email] = name.trim();
      }
    }
    return names;
  }
}
