import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/recipe.dart';
import '../models/todo.dart';

class SupabaseService {
  static SupabaseClient get _client => Supabase.instance.client;

  // Auth
  static User? get currentUser => _client.auth.currentUser;
  static Stream<AuthState> get authStateChanges =>
      _client.auth.onAuthStateChange;

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

  // Todos
  static Future<List<Todo>> getTodos() async {
    final data = await _client
        .from('todos')
        .select()
        .order('created_at', ascending: false);
    return data.map<Todo>((json) => Todo.fromJson(json)).toList();
  }

  static Future<void> addTodo(String title) async {
    await _client.from('todos').insert({
      'user_id': currentUser!.id,
      'title': title,
    });
  }

  static Future<void> toggleTodo(String id, bool isCompleted) async {
    await _client
        .from('todos')
        .update({'is_completed': isCompleted}).eq('id', id);
  }

  static Future<void> deleteTodo(String id) async {
    await _client.from('todos').delete().eq('id', id);
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
