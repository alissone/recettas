import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
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

  /// Returns the id of the created purchase.
  static Future<String> addPurchase({
    required String purchaseDate,
    required String item,
    required double valor,
    String? local,
    String? categoryId,
  }) async {
    final data = await _client
        .from('purchases')
        .insert({
          'user_id': currentUser!.id,
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

  static Future<void> addShoppingItem(String item) async {
    await _client.from('shopping_items').insert({
      'user_id': currentUser!.id,
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

  static Future<void> addPurchaseCategory(String name, int colorValue) async {
    await _client.from('purchase_categories').insert({
      'user_id': currentUser!.id,
      'name': name,
      'color_value': colorValue,
    });
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
