import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../models/list_invite.dart';
import '../models/purchase_category.dart';
import '../models/shopping_item.dart';
import '../services/supabase_service.dart';
import '../utils/brl.dart';
import '../widgets/list_owner_tabs.dart';
import 'web_common.dart';

/// Web "Compras": the shopping list, own and shared. Checking an item
/// asks for the price and registers the gasto, exactly like the app.
class WebShoppingScreen extends StatefulWidget {
  /// Called after a gasto is registered so Gastos can refresh.
  final VoidCallback? onPurchaseAdded;

  const WebShoppingScreen({super.key, this.onPurchaseAdded});

  @override
  State<WebShoppingScreen> createState() => _WebShoppingScreenState();
}

class _WebShoppingScreenState extends State<WebShoppingScreen> {
  List<ShoppingItem> _allItems = [];
  List<PurchaseCategory> _allCategories = [];
  List<ListOwner> _owners = [];
  String? _selectedOwnerId;
  bool _isLoading = true;

  Set<String> get _ownersWithItems => {for (final i in _allItems) i.userId};

  ListOwner? get _activeOwner =>
      activeOwner(_owners, _ownersWithItems, _selectedOwnerId);

  List<ShoppingItem> get _items {
    final owner = _activeOwner;
    if (owner == null) return const [];
    return [
      for (final i in _allItems)
        if (i.userId == owner.id) i
    ];
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        SupabaseService.getShoppingItems(),
        SupabaseService.getPurchaseCategories(),
        SupabaseService.getListOwners(),
      ]);
      if (!mounted) return;
      setState(() {
        _allItems = results[0] as List<ShoppingItem>;
        _allCategories = results[1] as List<PurchaseCategory>;
        _owners = results[2] as List<ListOwner>;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      showWebError(context, e);
    }
  }

  Future<void> _write(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      if (mounted) showWebError(context, e);
    }
    _load();
  }

  Future<void> _add(String text) => _write(
      () => SupabaseService.addShoppingItem(text, ownerId: _activeOwner?.id));

  Future<void> _delete(ShoppingItem item) {
    setState(() => _allItems.removeWhere((i) => i.id == item.id));
    return _write(() => SupabaseService.deleteShoppingItem(item.id));
  }

  /// Checking asks for the price and registers a gasto; unchecking only
  /// unmarks the item (the gasto stays and can be deleted in Gastos).
  Future<void> _toggle(ShoppingItem item) async {
    if (item.isPurchased) {
      return _write(() => SupabaseService.updateShoppingItem(item.id, {
            'is_purchased': false,
            'purchase_id': null,
            'purchased_at': null,
          }));
    }
    var saved = false;
    await showPurchaseForm(
      context,
      title: 'Registrar compra',
      submitLabel: 'Registrar em Gastos',
      lockedItem: item.item,
      // The gasto goes to the list the item belongs to, with that
      // list's categories.
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
        saved = true;
        if (mounted) {
          showWebMessage(context,
              '${item.item} • ${formatBrl(result.valor)} adicionado em Gastos.');
        }
      },
    );
    if (saved) {
      widget.onPurchaseAdded?.call();
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final pending = _items.where((i) => !i.isPurchased).length;
    final tabs = ownerTabs(_owners, _ownersWithItems);
    return Scaffold(
      backgroundColor: AppTheme.creamBackground,
      body: SafeArea(
        child: WebPage(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              WebHeader(
                title: 'Compras',
                subtitle: pending == 0
                    ? 'Sua lista de compras'
                    : pending == 1
                        ? '1 item para comprar'
                        : '$pending itens para comprar',
                actions: [
                  IconButton(
                    tooltip: 'Atualizar',
                    icon: const Icon(Icons.refresh, color: AppTheme.darkBrown),
                    onPressed: _load,
                  ),
                ],
              ),
              if (tabs.isNotEmpty)
                ListOwnerTabs(
                  owners: tabs,
                  activeOwnerId: _activeOwner!.id,
                  onSelect: (o) => setState(() => _selectedOwnerId = o.id),
                ),
              QuickAddField(
                hint: 'O que precisa comprar?',
                icon: Icons.add_shopping_cart,
                onSubmit: _add,
              ),
              Expanded(child: _buildContent()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) return webSpinner;
    final items = _items;
    if (items.isEmpty) {
      return const WebEmptyState(
        icon: Icons.shopping_cart_outlined,
        title: 'Lista de compras vazia',
        subtitle: 'Digite acima para adicionar um item',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Padding(
          key: ValueKey(item.id),
          padding: const EdgeInsets.only(bottom: 12),
          child: WebCard(
            child: Row(
              children: [
                WebCheckbox(
                  checked: item.isPurchased,
                  onTap: () => _toggle(item),
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
                      decoration:
                          item.isPurchased ? TextDecoration.lineThrough : null,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Excluir',
                  icon: Icon(Icons.delete_outline,
                      color: AppTheme.mediumBrown.withValues(alpha: 0.6)),
                  onPressed: () => _delete(item),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
