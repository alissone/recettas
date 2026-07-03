import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/category_base.dart';
import '../services/category_store.dart';

class EditCategoriesScreen extends StatefulWidget {
  final CategoryStore store;

  const EditCategoriesScreen({super.key, required this.store});

  @override
  State<EditCategoriesScreen> createState() =>
      _EditCategoriesScreenState();
}

class _EditCategoriesScreenState extends State<EditCategoriesScreen> {
  List<CategoryBase> _categories = [];
  bool _isLoading = true;

  CategoryStore get _store => widget.store;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final cats = await _store.getAll();
    if (!mounted) return;
    setState(() {
      _categories = cats;
      _isLoading = false;
    });
  }

  Future<void> _showCategoryDialog({CategoryBase? existing}) async {
    final result = await showDialog<(String, int)>(
      context: context,
      builder: (_) => _CategoryDialog(existing: existing),
    );

    if (result != null) {
      final (name, colorValue) = result;
      if (existing != null) {
        await _store.update(existing.id,
            name: name, colorValue: colorValue);
      } else {
        await _store.add(name, colorValue);
      }
      _load();
    }
  }

  Future<void> _deleteCategory(CategoryBase cat) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.creamBackground,
        shape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(AppTheme.radiusLarge),
        ),
        title: const Text('Delete Category',
            style: AppTheme.sectionTitle),
        content: Text(
          'Delete "${cat.name}"? ${_store.deleteNote}',
          style: AppTheme.bodyText,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: TextStyle(color: AppTheme.mediumBrown)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade400,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                    AppTheme.radiusXSmall),
              ),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _store.delete(cat.id);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.creamBackground,
      appBar: AppBar(
        title: Text(_store.title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                  color: AppTheme.primaryOrange))
          : _categories.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: _categories.length,
                  itemBuilder: (_, i) =>
                      _buildCategoryTile(_categories[i]),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCategoryDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.category_outlined,
              size: 64,
              color:
                  AppTheme.primaryOrange.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          const Text('No categories yet',
              style: AppTheme.sectionTitle),
          const SizedBox(height: 8),
          const Text('Tap + to create one',
              style: AppTheme.caption),
        ],
      ),
    );
  }

  Widget _buildCategoryTile(CategoryBase cat) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius:
            BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: AppTheme.softShadow,
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: cat.color,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              cat.name.isNotEmpty
                  ? cat.name[0].toUpperCase()
                  : '?',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
        ),
        title: Text(cat.name, style: AppTheme.valueBold),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20),
              color: AppTheme.mediumBrown,
              onPressed: () =>
                  _showCategoryDialog(existing: cat),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              color: Colors.red.shade300,
              onPressed: () => _deleteCategory(cat),
            ),
          ],
        ),
        shape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(AppTheme.radiusMedium),
        ),
      ),
    );
  }
}

/// Owns the name controller so it is only disposed once the dialog's
/// route (including the close animation) is fully gone; pops
/// (name, colorValue) on save.
class _CategoryDialog extends StatefulWidget {
  final CategoryBase? existing;

  const _CategoryDialog({this.existing});

  @override
  State<_CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<_CategoryDialog> {
  late final TextEditingController _nameController;
  late int _selectedColor;

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: widget.existing?.name ?? '');
    _selectedColor =
        widget.existing?.colorValue ?? CategoryBase.presetColors.first;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      Navigator.pop(context);
      return;
    }
    Navigator.pop(context, (name, _selectedColor));
  }

  @override
  Widget build(BuildContext context) {
    final existing = widget.existing;
    return AlertDialog(
      backgroundColor: AppTheme.creamBackground,
      shape: RoundedRectangleBorder(
        borderRadius:
            BorderRadius.circular(AppTheme.radiusLarge),
      ),
      title: Text(
        existing != null ? 'Edit Category' : 'New Category',
        style: AppTheme.headingMedium,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _nameController,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Category name',
              hintStyle: TextStyle(
                  color: AppTheme.mediumBrown
                      .withValues(alpha: 0.5)),
              filled: true,
              fillColor: AppTheme.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(
                    AppTheme.radiusSmall),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(
                    AppTheme.radiusSmall),
                borderSide: const BorderSide(
                    color: AppTheme.primaryOrange, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
            ),
          ),
          const SizedBox(height: 20),
          Text('Color',
              style: AppTheme.caption
                  .copyWith(fontSize: 14)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: CategoryBase.presetColors
                .map((c) => GestureDetector(
                      onTap: () =>
                          setState(() => _selectedColor = c),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Color(c),
                          borderRadius:
                              BorderRadius.circular(10),
                          border: _selectedColor == c
                              ? Border.all(
                                  color: AppTheme.darkBrown,
                                  width: 3)
                              : null,
                          boxShadow: _selectedColor == c
                              ? [
                                  BoxShadow(
                                    color: Color(c)
                                        .withValues(alpha: 0.4),
                                    blurRadius: 8,
                                  )
                                ]
                              : null,
                        ),
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel',
              style: TextStyle(color: AppTheme.mediumBrown)),
        ),
        ElevatedButton(
          onPressed: _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryOrange,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                  AppTheme.radiusXSmall),
            ),
          ),
          child: Text(existing != null ? 'Save' : 'Add'),
        ),
      ],
    );
  }
}
