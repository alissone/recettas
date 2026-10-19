import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../models/list_invite.dart';
import '../models/purchase.dart';
import '../models/purchase_category.dart';
import '../services/supabase_service.dart';
import '../utils/brl.dart';
import '../widgets/list_owner_tabs.dart';
import 'web_common.dart';

/// Web "Gastos": one month of gastos, own and shared, with add, edit
/// and delete. No receipts, search, reports or categorizing here.
class WebPurchasesScreen extends StatefulWidget {
  /// Bumped by Compras after it registers a gasto.
  final Listenable? reload;

  const WebPurchasesScreen({super.key, this.reload});

  @override
  State<WebPurchasesScreen> createState() => _WebPurchasesScreenState();
}

class _WebPurchasesScreenState extends State<WebPurchasesScreen> {
  static const _monthNames = [
    'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
    'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro',
  ];

  List<Purchase> _allPurchases = [];
  List<PurchaseCategory> _allCategories = [];
  List<ListOwner> _owners = [];
  String? _selectedOwnerId;
  bool _isLoading = true;

  /// First day of the month being displayed.
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  String get _monthLabel => '${_monthNames[_month.month - 1]} ${_month.year}';

  static String _dateString(DateTime d) =>
      d.toIso8601String().substring(0, 10);

  Set<String> get _ownersWithItems =>
      {for (final p in _allPurchases) p.userId};

  ListOwner? get _activeOwner =>
      activeOwner(_owners, _ownersWithItems, _selectedOwnerId);

  List<Purchase> get _purchases {
    final owner = _activeOwner;
    if (owner == null) return const [];
    return [
      for (final p in _allPurchases)
        if (p.userId == owner.id) p
    ];
  }

  @override
  void initState() {
    super.initState();
    widget.reload?.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    widget.reload?.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final month = _month;
    try {
      final results = await Future.wait([
        SupabaseService.getPurchases(
          fromDate: _dateString(month),
          toDateExclusive: _dateString(DateTime(month.year, month.month + 1)),
        ),
        SupabaseService.getPurchaseCategories(),
        SupabaseService.getListOwners(),
      ]);
      // The month changed while this was loading; that load wins.
      if (!mounted || month != _month) return;
      setState(() {
        _allPurchases = results[0] as List<Purchase>;
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

  void _changeMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
      _isLoading = true;
    });
    _load();
  }

  Future<void> _openForm({Purchase? existing}) async {
    final ownerId = existing?.userId ?? _activeOwner?.id;
    var saved = false;
    await showPurchaseForm(
      context,
      title: existing != null ? 'Editar Gasto' : 'Novo Gasto',
      submitLabel: 'Salvar',
      categories: [
        for (final c in _allCategories)
          if (c.userId == ownerId) c
      ],
      item: existing?.item,
      valor: existing?.valor,
      date: existing?.purchaseDate,
      local: existing?.local,
      categoryId: existing?.categoryId,
      onSubmit: (result) async {
        if (existing != null) {
          await SupabaseService.updatePurchase(existing.id, {
            'item': result.item,
            'valor': result.valor,
            'purchase_date': result.date,
            'local': result.local,
            'category_id': result.categoryId,
          });
        } else {
          await SupabaseService.addPurchase(
            purchaseDate: result.date,
            item: result.item,
            valor: result.valor,
            local: result.local,
            categoryId: result.categoryId,
            ownerId: ownerId,
          );
        }
        saved = true;
      },
    );
    if (saved) _load();
  }

  Future<void> _delete(Purchase p) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir gasto?'),
        content: Text('${p.item} • ${formatBrl(p.valor)}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _allPurchases.removeWhere((x) => x.id == p.id));
    try {
      await SupabaseService.deletePurchase(p.id);
    } catch (e) {
      if (mounted) showWebError(context, e);
    }
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final purchases = _purchases;
    final total = purchases.fold<double>(0, (sum, p) => sum + p.valor);
    final tabs = ownerTabs(_owners, _ownersWithItems);
    return Scaffold(
      backgroundColor: AppTheme.creamBackground,
      body: SafeArea(
        child: WebPage(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              WebHeader(
                title: 'Gastos',
                subtitle: purchases.isEmpty
                    ? 'Registre seus gastos'
                    : '${purchases.length} itens • ${formatBrl(total)}',
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
              _buildMonthBar(),
              Expanded(child: _buildContent()),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'web_purchases_fab',
        tooltip: 'Novo gasto',
        onPressed: () => _openForm(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildMonthBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          boxShadow: AppTheme.softShadow,
        ),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Mês anterior',
              icon: const Icon(Icons.chevron_left, color: AppTheme.mediumBrown),
              onPressed: () => _changeMonth(-1),
            ),
            Expanded(
              child: Text(
                _monthLabel,
                textAlign: TextAlign.center,
                style: AppTheme.valueBold,
              ),
            ),
            IconButton(
              tooltip: 'Próximo mês',
              icon:
                  const Icon(Icons.chevron_right, color: AppTheme.mediumBrown),
              onPressed: () => _changeMonth(1),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) return webSpinner;
    final purchases = _purchases;
    if (purchases.isEmpty) {
      return WebEmptyState(
        icon: Icons.shopping_bag_outlined,
        title: 'Nenhum gasto em $_monthLabel',
        subtitle: 'Toque em + para adicionar',
      );
    }
    final categories = {for (final c in _allCategories) c.id: c};
    return ListView.builder(
      // Bottom room so the FAB doesn't cover the last card's value.
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 88),
      itemCount: purchases.length,
      itemBuilder: (context, index) {
        final p = purchases[index];
        final cat = categories[p.categoryId];
        return Padding(
          key: ValueKey(p.id),
          padding: const EdgeInsets.only(bottom: 12),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              onTap: () => _openForm(existing: p),
              child: WebCard(
                stripe: cat?.color,
                padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            p.item,
                            style: const TextStyle(
                              fontSize: 16,
                              color: AppTheme.darkBrown,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            [
                              p.purchaseDate,
                              if (p.local != null && p.local!.isNotEmpty)
                                p.local!,
                              if (cat != null) cat.name,
                            ].join(' • '),
                            style: AppTheme.caption
                                .copyWith(fontWeight: FontWeight.w400),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(formatBrl(p.valor), style: AppTheme.valueBold),
                    IconButton(
                      tooltip: 'Excluir',
                      icon: Icon(Icons.delete_outline,
                          color: AppTheme.mediumBrown.withValues(alpha: 0.6)),
                      onPressed: () => _delete(p),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
