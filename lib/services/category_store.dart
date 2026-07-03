import '../models/category_base.dart';
import 'supabase_service.dart';
import 'todo_repository.dart';

/// Backend-agnostic CRUD for a category list, so the same edit screen
/// works for todo categories and purchase categories.
abstract class CategoryStore {
  String get title;

  /// Shown when confirming a delete, explains what happens to items
  /// still using the category.
  String get deleteNote;

  Future<List<CategoryBase>> getAll();
  Future<void> add(String name, int colorValue);
  Future<void> update(String id, {String? name, int? colorValue});
  Future<void> delete(String id);
}

/// Todo categories, served by the offline-first repository.
class TodoCategoryStore extends CategoryStore {
  @override
  String get title => 'Edit Categories';

  @override
  String get deleteNote =>
      'Tasks using this category will become uncategorized.';

  @override
  Future<List<CategoryBase>> getAll() =>
      TodoRepository.instance.getCategories();

  @override
  Future<void> add(String name, int colorValue) =>
      TodoRepository.instance.addCategory(name, colorValue);

  @override
  Future<void> update(String id, {String? name, int? colorValue}) =>
      TodoRepository.instance
          .updateCategory(id, name: name, colorValue: colorValue);

  @override
  Future<void> delete(String id) =>
      TodoRepository.instance.deleteCategory(id);
}

/// Purchase categories ("Importância"), straight from Supabase.
class PurchaseCategoryStore extends CategoryStore {
  @override
  String get title => 'Editar Importâncias';

  @override
  String get deleteNote =>
      'Compras com esta importância ficarão sem categoria.';

  @override
  Future<List<CategoryBase>> getAll() =>
      SupabaseService.getPurchaseCategories();

  @override
  Future<void> add(String name, int colorValue) =>
      SupabaseService.addPurchaseCategory(name, colorValue);

  @override
  Future<void> update(String id, {String? name, int? colorValue}) =>
      SupabaseService.updatePurchaseCategory(id,
          name: name, colorValue: colorValue);

  @override
  Future<void> delete(String id) =>
      SupabaseService.deletePurchaseCategory(id);
}
