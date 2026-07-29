import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
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

class SupabaseService {
  static SupabaseClient get _client => Supabase.instance.client;

  // Auth
  static User? get currentUser => _client.auth.currentUser;
  static Stream<AuthState> get authStateChanges =>
      _client.auth.onAuthStateChange;

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

  // Recipes
  static Future<List<Recipe>> getRecipes() async {
    final data = await _client.from('recipes').select().order('created_at');
    return data.map<Recipe>((json) => Recipe.fromJson(json)).toList();
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

  /// Food log between two YYYY-MM-DD dates, [toDateExclusive] excluded.
  static Future<List<FoodEntry>> getFoodEntries({
    required String fromDate,
    required String toDateExclusive,
    required Map<NutrientId, Nutrient> catalog,
  }) async {
    final data = await _client
        .from('food_entries')
        .select('*, food:foods(*, food_nutrients(nutrient_id, amount))')
        .gte('entry_date', fromDate)
        .lt('entry_date', toDateExclusive)
        .order('entry_date', ascending: false)
        .order('created_at', ascending: false);
    return data
        .map<FoodEntry>((json) => FoodEntry.fromJson(json, catalog))
        .toList();
  }

  static Future<void> addFoodEntry({
    required String entryDate,
    required String foodId,
    required double amount,
  }) async {
    await _client.from('food_entries').insert({
      'user_id': currentUser!.id,
      'entry_date': entryDate,
      'food_id': foodId,
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

  /// One row per (day, exercise): logging the same exercise twice on a
  /// day overwrites it, via the unique index from migration 017.
  static Future<void> upsertGymEntry({
    required String entryDate,
    required String exerciseId,
    required int sets,
    required int reps,
    double? weight,
    String? notes,
  }) async {
    await _client.from('gym_entries').upsert({
      'user_id': currentUser!.id,
      'entry_date': entryDate,
      'exercise_id': exerciseId,
      'sets': sets,
      'reps': reps,
      'weight': weight,
      'notes': notes,
    }, onConflict: 'user_id,entry_date,exercise_id');
  }

  static Future<void> deleteGymEntry(String id) async {
    await _client.from('gym_entries').delete().eq('id', id);
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
  static final Map<String, String> _habitImageUrls = {};

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
  static Future<String> habitImageUrl(String path) async {
    final cached = _habitImageUrls[path];
    if (cached != null) return cached;
    // A day outlives any realistic session, so a memoized URL never
    // expires while it is still in the map.
    final url = await _client.storage
        .from('habits')
        .createSignedUrl(path, 60 * 60 * 24);
    _habitImageUrls[path] = url;
    return url;
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

  static Future<void> updateProfile(
      {String? displayName, String? avatarUrl}) async {
    final updates = <String, dynamic>{};
    if (displayName != null) updates['display_name'] = displayName;
    if (avatarUrl != null) updates['avatar_url'] = avatarUrl;

    await _client
        .from('profiles')
        .update(updates)
        .eq('id', currentUser!.id);
  }
}
