import 'dart:async';

import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../models/list_invite.dart';
import '../models/purchase_category.dart';
import '../models/shopping_item.dart';
import '../services/local_guesser.dart';
import '../services/supabase_service.dart';
import '../utils/brl.dart';
import '../widgets/list_owner_tabs.dart';
import '../widgets/local_field.dart';
import 'home_shell.dart' show homeShellKey, showNoInternetBanner;
import 'list_invites_screen.dart';

/// Shopping list ("Compras"): reminders of stuff to buy. Checking an
/// item asks for the price and registers the purchase in Gastos.
class ShoppingScreen extends StatefulWidget {
  const ShoppingScreen({super.key});

  @override
  State<ShoppingScreen> createState() => _ShoppingScreenState();
}

class _ShoppingScreenState extends State<ShoppingScreen> {
  /// Every accessible item (own + shared lists); [_items] narrows to
  /// the active list.
  List<ShoppingItem> _allItems = [];
  List<PurchaseCategory> _allCategories = [];
  List<ListOwner> _owners = [];

  /// Tab picked by the user; null falls back to the default list.
  String? _selectedOwnerId;
  bool _isLoading = true;
  bool _isAdding = false;
  final _textController = TextEditingController();
  final _focusNode = FocusNode();
  StreamSubscription? _authSubscription;

  @override
  void initState() {
    super.initState();
    _loadAll();

    _authSubscription = SupabaseService.authStateChanges.listen((data) {
      if (mounted) {
        setState(() {});
        _loadAll();
      }
    }, onError: (error) {
      if (SupabaseService.isNetworkError(error)) showNoInternetBanner();
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  bool get _isAuthenticated => SupabaseService.currentUser != null;

  /// Owners with a non-empty list; tabs only appear when more than one
  /// list has items.
  List<ListOwner> get _tabOwners {
    final withItems = [
      for (final o in _owners)
        if (_allItems.any((i) => i.userId == o.id)) o
    ];
    return withItems.length > 1 ? withItems : const [];
  }

  /// List being displayed: the picked tab, else the only non-empty
  /// list (so an invited user lands on the inviter's list), else the
  /// user's own list.
  ListOwner? get _activeOwner {
    if (_owners.isEmpty) return null;
    final tabs = _tabOwners;
    if (tabs.isNotEmpty) {
      return tabs.firstWhere((o) => o.id == _selectedOwnerId,
          orElse: () => tabs.first);
    }
    for (final o in _owners) {
      if (_allItems.any((i) => i.userId == o.id)) return o;
    }
    return _owners.first;
  }

  List<ShoppingItem> get _items {
    final owner = _activeOwner;
    if (owner == null) return const [];
    return [
      for (final i in _allItems)
        if (i.userId == owner.id) i
    ];
  }

  Future<void> _loadAll() async {
    if (!_isAuthenticated) {
      if (mounted) {
        setState(() {
          _allItems = [];
          _allCategories = [];
          _owners = [];
          _isLoading = false;
        });
      }
      return;
    }
    try {
      final results = await Future.wait([
        SupabaseService.getShoppingItems(),
        SupabaseService.getPurchaseCategories(),
        SupabaseService.getListOwners(),
      ]);
      if (mounted) {
        setState(() {
          _allItems = results[0] as List<ShoppingItem>;
          _allCategories = results[1] as List<PurchaseCategory>;
          _owners = results[2] as List<ListOwner>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addItem() async {
    final title = _textController.text.trim();
    if (title.isEmpty) return;
    _textController.clear();
    await SupabaseService.addShoppingItem(title,
        ownerId: _activeOwner?.id);
    _loadAll();
  }

  void _openInvites() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ListInvitesScreen()),
    );
    _loadAll();
  }

  void _startAdding() {
    setState(() => _isAdding = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  void _saveAndStopAdding() {
    final title = _textController.text.trim();
    if (title.isNotEmpty) _addItem();
    _textController.clear();
    setState(() => _isAdding = false);
  }

  Future<void> _deleteItem(ShoppingItem item) async {
    await SupabaseService.deleteShoppingItem(item.id);
    _loadAll();
  }

  /// Checking asks for the price and registers a gasto; unchecking only
  /// unmarks the item (the gasto stays and can be deleted in Gastos).
  Future<void> _toggleItem(ShoppingItem item) async {
    if (item.isPurchased) {
      await SupabaseService.updateShoppingItem(item.id, {
        'is_purchased': false,
        'purchase_id': null,
        'purchased_at': null,
      });
      _loadAll();
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.creamBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppTheme.radiusLarge)),
      ),
      // The gasto goes to the same list the item belongs to, using
      // that list's categories.
      builder: (_) => _CompletePurchaseSheet(
        item: item,
        categories: [
          for (final c in _allCategories)
            if (c.userId == item.userId) c
        ],
        onSubmit: (result) async {
          final purchaseId = await SupabaseService.addPurchase(
            purchaseDate: result.date,
            item: item.item,
            valor: result.valor,
            local: result.local,
            categoryId: result.categoryId,
            ownerId: item.userId,
          );
          await SupabaseService.updateShoppingItem(item.id, {
            'is_purchased': true,
            'purchase_id': purchaseId,
            'purchased_at': DateTime.now().toUtc().toIso8601String(),
          });
          homeShellKey.currentState?.showBanner(
            title: 'Compra registrada',
            body: '${item.item} • ${formatBrl(result.valor)} '
                'adicionado em Gastos.',
            icon: Icons.check_circle_outline,
            iconColor: Colors.green,
          );
          _loadAll();
        },
      ),
    );
  }

  // --- Build ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.creamBackground,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            if (_isAuthenticated && _tabOwners.isNotEmpty)
              ListOwnerTabs(
                owners: _tabOwners,
                activeOwnerId: _activeOwner!.id,
                onSelect: (o) =>
                    setState(() => _selectedOwnerId = o.id),
              ),
            Expanded(child: _buildContent()),
          ],
        ),
      ),
      floatingActionButton: _isAuthenticated && !_isAdding
          ? FloatingActionButton(
              // Unique tag: the other tabs' FABs coexist in the
              // IndexedStack and default hero tags would clash.
              heroTag: 'shopping_fab',
              onPressed: _startAdding,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildHeader() {
    final pending = _items.where((i) => !i.isPurchased).length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 8, 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Compras', style: AppTheme.headingLarge),
                const SizedBox(height: 4),
                Text(
                  pending == 0
                      ? 'Sua lista de compras'
                      : pending == 1
                          ? '1 item para comprar'
                          : '$pending itens para comprar',
                  style: AppTheme.bodyText
                      .copyWith(color: AppTheme.mediumBrown),
                ),
              ],
            ),
          ),
          if (_isAuthenticated)
            IconButton(
              tooltip: 'Compartilhar listas',
              icon: const Icon(Icons.group_add_outlined,
                  color: AppTheme.darkBrown),
              onPressed: _openInvites,
            ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (!_isAuthenticated) return _buildSignInPrompt();
    if (_isLoading) {
      return const Center(
        child:
            CircularProgressIndicator(color: AppTheme.primaryOrange),
      );
    }
    if (_isAdding) return _buildAddingView();
    if (_items.isEmpty) return _buildEmptyState();
    return RefreshIndicator(
      color: AppTheme.primaryOrange,
      onRefresh: _loadAll,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _items.length,
        itemBuilder: (context, index) => _buildItemCard(_items[index]),
      ),
    );
  }

  Widget _buildSignInPrompt() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color:
                    AppTheme.primaryOrange.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock_outline,
                  size: 48, color: AppTheme.primaryOrange),
            ),
            const SizedBox(height: 24),
            const Text('Faça login para ver sua lista de compras',
                style: AppTheme.headingMedium,
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              'Vá para a aba Perfil para fazer login ou criar uma conta',
              style: AppTheme.bodyText
                  .copyWith(color: AppTheme.mediumBrown),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_cart_outlined,
              size: 64,
              color:
                  AppTheme.primaryOrange.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          const Text('Lista de compras vazia',
              style: AppTheme.sectionTitle),
          const SizedBox(height: 8),
          const Text('Toque em + para adicionar um item',
              style: AppTheme.caption),
        ],
      ),
    );
  }

  Widget _buildAddingView() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.white,
              borderRadius:
                  BorderRadius.circular(AppTheme.radiusMedium),
              boxShadow: AppTheme.softShadow,
            ),
            child: TextField(
              controller: _textController,
              focusNode: _focusNode,
              decoration: InputDecoration(
                hintText: 'O que precisa comprar?',
                hintStyle: TextStyle(
                    color: AppTheme.mediumBrown
                        .withValues(alpha: 0.5)),
                prefixIcon: const Icon(Icons.add_shopping_cart,
                    color: AppTheme.primaryOrange),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(
                      AppTheme.radiusMedium),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(
                      AppTheme.radiusMedium),
                  borderSide: const BorderSide(
                      color: AppTheme.primaryOrange, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 16),
              ),
              onSubmitted: (_) => _saveAndStopAdding(),
            ),
          ),
        ),
        Expanded(
          child: GestureDetector(
            onTap: _saveAndStopAdding,
            behavior: HitTestBehavior.opaque,
            child: const SizedBox.expand(),
          ),
        ),
      ],
    );
  }

  Widget _buildItemCard(ShoppingItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Dismissible(
        key: ValueKey(item.id),
        direction: DismissDirection.endToStart,
        onDismissed: (_) => _deleteItem(item),
        background: Container(
          decoration: BoxDecoration(
            color: Colors.red.shade400,
            borderRadius:
                BorderRadius.circular(AppTheme.radiusMedium),
          ),
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          child: const Icon(Icons.delete_outline,
              color: Colors.white, size: 24),
        ),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.white,
            borderRadius:
                BorderRadius.circular(AppTheme.radiusMedium),
            boxShadow: AppTheme.softShadow,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 12),
            child: Row(
              children: [
                // Checkbox
                GestureDetector(
                  onTap: () => _toggleItem(item),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: item.isPurchased
                          ? AppTheme.primaryOrange
                          : AppTheme.primaryOrange
                              .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: item.isPurchased
                          ? null
                          : Border.all(
                              color: AppTheme.borderOrange,
                              width: 2),
                    ),
                    child: item.isPurchased
                        ? const Icon(Icons.check,
                            size: 18, color: Colors.white)
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.item,
                    style: TextStyle(
                      fontSize: 16,
                      color: item.isPurchased
                          ? AppTheme.mediumBrown
                          : AppTheme.darkBrown,
                      decoration: item.isPurchased
                          ? TextDecoration.lineThrough
                          : null,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bottom sheet shown when checking an item: asks for the gasto details
// ---------------------------------------------------------------------------

class _CompletePurchaseResult {
  final double valor;
  final String date;
  final String? local;
  final String? categoryId;

  const _CompletePurchaseResult({
    required this.valor,
    required this.date,
    this.local,
    this.categoryId,
  });
}

class _CompletePurchaseSheet extends StatefulWidget {
  final ShoppingItem item;
  final List<PurchaseCategory> categories;
  final Future<void> Function(_CompletePurchaseResult result) onSubmit;

  const _CompletePurchaseSheet({
    required this.item,
    required this.categories,
    required this.onSubmit,
  });

  @override
  State<_CompletePurchaseSheet> createState() =>
      _CompletePurchaseSheetState();
}

class _CompletePurchaseSheetState extends State<_CompletePurchaseSheet> {
  final _valorController = TextEditingController();
  final _localController = TextEditingController();
  late String _date;
  String? _localPreset;
  String? _categoryId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _date = DateTime.now().toIso8601String().substring(0, 10);
    _guessLocal();
  }

  Future<void> _guessLocal() async {
    final guess = await LocalGuesser.guess();
    if (!mounted || guess == null) return;
    // The user picked or typed a place while the GPS was working.
    if (_localPreset != null || _localController.text.isNotEmpty) return;
    setState(() => _localPreset = guess);
  }

  @override
  void dispose() {
    _valorController.dispose();
    _localController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final typedLocal = _localController.text.trim();
    final local =
        _localPreset ?? (typedLocal.isEmpty ? null : typedLocal);
    final result = _CompletePurchaseResult(
      valor: parseBrlInput(_valorController.text) ?? 0,
      date: _date,
      local: local,
      categoryId: _categoryId,
    );

    setState(() => _saving = true);
    try {
      await widget.onSubmit(result);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar: $e')),
        );
      }
      return;
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Registrar compra', style: AppTheme.headingMedium),
          const SizedBox(height: 4),
          Text(
            widget.item.item,
            style: AppTheme.bodyText
                .copyWith(color: AppTheme.mediumBrown),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _valorController,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true),
                  decoration: _fieldDecoration('Valor (R\$)'),
                  onSubmitted: (_) => _save(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate:
                          DateTime.tryParse(_date) ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      setState(() => _date =
                          picked.toIso8601String().substring(0, 10));
                    }
                  },
                  child: InputDecorator(
                    decoration: _fieldDecoration('Data'),
                    child: Text(_date, style: AppTheme.bodyText),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LocalField(
            preset: _localPreset,
            onPresetChanged: (v) => setState(() => _localPreset = v),
            controller: _localController,
            decorationBuilder: _fieldDecoration,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            initialValue: _categoryId,
            decoration: _fieldDecoration('Categoria'),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('Sem categoria'),
              ),
              for (final c in widget.categories)
                DropdownMenuItem<String?>(
                  value: c.id,
                  child: Row(
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: c.color,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(c.name),
                    ],
                  ),
                ),
            ],
            onChanged: (v) => setState(() => _categoryId = v),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryOrange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppTheme.radiusSmall),
                ),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Registrar em Gastos'),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _fieldDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
          color: AppTheme.mediumBrown.withValues(alpha: 0.8)),
      filled: true,
      fillColor: AppTheme.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        borderSide:
            const BorderSide(color: AppTheme.primaryOrange, width: 2),
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}
