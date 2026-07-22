import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../app_theme.dart';
import '../models/category_base.dart';
import '../models/list_invite.dart';
import '../models/purchase.dart';
import '../models/purchase_category.dart';
import '../services/category_store.dart';
import '../services/local_guesser.dart';
import '../services/purchase_categorizer.dart';
import '../services/supabase_service.dart';
import '../utils/brl.dart';
import '../widgets/categorize_overlay.dart';
import '../widgets/list_owner_tabs.dart';
import '../widgets/local_field.dart';
import '../widgets/swipe_action_card.dart';
import 'edit_categories_screen.dart';
import 'home_shell.dart' show homeShellKey, showNoInternetBanner;
import 'list_invites_screen.dart';
import 'receipt_queue_screen.dart';

class PurchasesScreen extends StatefulWidget {
  const PurchasesScreen({super.key});

  @override
  State<PurchasesScreen> createState() => _PurchasesScreenState();
}

class _PurchasesScreenState extends State<PurchasesScreen> {
  static const _monthNames = [
    'Janeiro',
    'Fevereiro',
    'Março',
    'Abril',
    'Maio',
    'Junho',
    'Julho',
    'Agosto',
    'Setembro',
    'Outubro',
    'Novembro',
    'Dezembro',
  ];

  /// Every accessible purchase for the month (own + shared lists);
  /// [_purchases] narrows to the active list.
  List<Purchase> _allPurchases = [];
  List<PurchaseCategory> _allCategories = [];
  List<ListOwner> _owners = [];

  /// Tab picked by the user; null falls back to the default list.
  String? _selectedOwnerId;
  bool _isLoading = true;
  bool _uploadingReceipt = false;
  StreamSubscription? _authSubscription;

  bool _searchVisible = false;
  final _searchController = TextEditingController();

  // Categorize overlay state
  Purchase? _categorizingPurchase;
  final _overlayKey = GlobalKey<CategorizeOverlayState>();

  /// First day of the month being displayed.
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  String get _monthLabel =>
      '${_monthNames[_month.month - 1]} ${_month.year}';

  static String _dateString(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  void _changeMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
      _isLoading = true;
    });
    _loadAll();
  }

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
    _searchController.dispose();
    super.dispose();
  }

  bool get _isAuthenticated => SupabaseService.currentUser != null;

  /// Owners with a non-empty list this month; tabs only appear when
  /// more than one list has items.
  List<ListOwner> get _tabOwners {
    final withItems = [
      for (final o in _owners)
        if (_allPurchases.any((p) => p.userId == o.id)) o
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
      if (_allPurchases.any((p) => p.userId == o.id)) return o;
    }
    return _owners.first;
  }

  List<Purchase> get _purchases {
    final owner = _activeOwner;
    if (owner == null) return const [];
    return [
      for (final p in _allPurchases)
        if (p.userId == owner.id) p
    ];
  }

  List<PurchaseCategory> get _categories {
    final owner = _activeOwner;
    if (owner == null) return const [];
    return [
      for (final c in _allCategories)
        if (c.userId == owner.id) c
    ];
  }

  Future<void> _loadAll() async {
    if (!_isAuthenticated) {
      if (mounted) {
        setState(() {
          _allPurchases = [];
          _allCategories = [];
          _owners = [];
          _isLoading = false;
        });
      }
      return;
    }
    try {
      final results = await Future.wait([
        SupabaseService.getPurchases(
          fromDate: _dateString(_month),
          toDateExclusive:
              _dateString(DateTime(_month.year, _month.month + 1)),
        ),
        SupabaseService.getPurchaseCategories(),
        SupabaseService.getListOwners(),
      ]);
      if (mounted) {
        setState(() {
          _allPurchases = results[0] as List<Purchase>;
          _allCategories = results[1] as List<PurchaseCategory>;
          _owners = results[2] as List<ListOwner>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Purchases shown in the list: everything, or the search matches
  /// (by item, local or category name) while the search bar is open.
  List<Purchase> get _visiblePurchases {
    final query = _searchController.text.trim().toLowerCase();
    if (!_searchVisible || query.isEmpty) return _purchases;
    return _purchases.where((p) {
      final cat = _categoryFor(p);
      return p.item.toLowerCase().contains(query) ||
          (p.local?.toLowerCase().contains(query) ?? false) ||
          (cat?.name.toLowerCase().contains(query) ?? false);
    }).toList();
  }

  void _toggleSearch() {
    setState(() {
      _searchVisible = !_searchVisible;
      if (!_searchVisible) _searchController.clear();
    });
  }

  PurchaseCategory? _categoryFor(Purchase p) {
    if (p.categoryId == null) return null;
    try {
      return _categories.firstWhere((c) => c.id == p.categoryId);
    } catch (_) {
      return null;
    }
  }

  void _openEditCategories() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => EditCategoriesScreen(
              store: PurchaseCategoryStore(ownerId: _activeOwner?.id))),
    );
    _loadAll();
  }

  void _openInvites() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ListInvitesScreen()),
    );
    _loadAll();
  }

  void _openQueue() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ReceiptQueueScreen()),
    );
    _loadAll();
  }

  // --- Auto-categorization ---

  /// Runs the rule-based categorizer (port of categorizar.py) over this
  /// month's purchases without importância, creating any missing
  /// category on the fly.
  Future<void> _autoCategorize() async {
    final uncategorized =
        _purchases.where((p) => p.categoryId == null).toList();
    if (uncategorized.isEmpty) {
      homeShellKey.currentState?.showBanner(
        title: 'Nada para categorizar',
        body: 'Todos os gastos de $_monthLabel já têm categoria.',
        icon: Icons.check_circle_outline,
      );
      return;
    }

    final byCategory = <String, List<Purchase>>{};
    for (final p in uncategorized) {
      final cat = PurchaseCategorizer.categorize(p.item, p.local);
      if (cat != null) byCategory.putIfAbsent(cat, () => []).add(p);
    }
    final matched =
        byCategory.values.fold<int>(0, (sum, l) => sum + l.length);
    if (matched == 0) {
      homeShellKey.currentState?.showBanner(
        title: 'Nenhuma regra correspondeu',
        body: 'Nenhum dos ${uncategorized.length} gastos sem '
            'categoria foi reconhecido pelas regras.',
        icon: Icons.help_outline,
      );
      return;
    }

    final confirmed = await _confirmAutoCategorize(
        byCategory, matched, uncategorized.length);
    if (confirmed != true || !mounted) return;

    setState(() => _isLoading = true);
    try {
      // Existing categories by accent/case-insensitive name; rules
      // whose category doesn't exist yet create it (in the active
      // list) with the default report color.
      final ownerId = _activeOwner?.id;
      final categoryIds = {
        for (final c in _categories)
          PurchaseCategorizer.nameKey(c.name): c.id,
      };
      for (final entry in byCategory.entries) {
        var id = categoryIds[PurchaseCategorizer.nameKey(entry.key)];
        id ??= await SupabaseService.addPurchaseCategory(
          entry.key,
          PurchaseCategorizer.categoryColors[entry.key] ?? 0xFFFF8C42,
          ownerId: ownerId,
        );
        await SupabaseService.updatePurchasesCategory(
            [for (final p in entry.value) p.id], id);
      }
      final left = uncategorized.length - matched;
      homeShellKey.currentState?.showBanner(
        title: matched == 1
            ? '1 gasto categorizado'
            : '$matched gastos categorizados',
        body: left > 0
            ? '$left sem regra correspondente — categorize manualmente.'
            : 'Todos os gastos do mês têm categoria agora.',
        icon: Icons.auto_awesome,
      );
    } catch (e) {
      homeShellKey.currentState?.showBanner(
        title: 'Falha ao categorizar',
        body: '$e',
        icon: Icons.error_outline,
        iconColor: Colors.red,
      );
    }
    await _loadAll();
  }

  Future<bool?> _confirmAutoCategorize(
      Map<String, List<Purchase>> byCategory, int matched, int total) {
    final entries = byCategory.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.creamBackground,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium)),
        title: const Text('Categorizar gastos'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$matched de $total gastos sem categoria foram '
                'reconhecidos:',
                style: AppTheme.bodyText,
              ),
              const SizedBox(height: 12),
              for (final e in entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '• ${e.key}: ${e.value.length}',
                    style: AppTheme.caption,
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryOrange,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Aplicar'),
          ),
        ],
      ),
    );
  }

  // --- Receipt capture ---

  Future<void> _captureReceipt(ImageSource source) async {
    final picker = ImagePicker();
    XFile? file;
    try {
      file = await picker.pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 85,
      );
    } catch (_) {
      // Camera unavailable (emulator etc.); fall back to the gallery.
      file = await picker.pickImage(source: ImageSource.gallery);
    }
    if (file == null) return;

    setState(() => _uploadingReceipt = true);
    try {
      final bytes = await file.readAsBytes();
      final jobId = const Uuid().v4();
      final path = '${SupabaseService.currentUser!.id}/$jobId.jpg';
      await SupabaseService.uploadReceiptImage(path, bytes);
      await SupabaseService.createReceiptJob(jobId, path);
      homeShellKey.currentState?.showBanner(
        title: 'Cupom enviado para a fila',
        body: 'Abra a fila de cupons para processar quando o servidor '
            'estiver ligado.',
        icon: Icons.receipt_long,
      );
    } catch (e) {
      homeShellKey.currentState?.showBanner(
        title: 'Falha ao enviar cupom',
        body: '$e',
        icon: Icons.error_outline,
        iconColor: Colors.red,
      );
    } finally {
      if (mounted) setState(() => _uploadingReceipt = false);
    }
  }

  // --- Manual add / edit ---

  Future<void> _showPurchaseSheet({Purchase? existing}) async {
    // New gastos land on the list being displayed (own or shared).
    final ownerId = _activeOwner?.id;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.creamBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppTheme.radiusLarge)),
      ),
      builder: (_) => _PurchaseSheet(
        existing: existing,
        categories: _categories,
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
          // Refresh the list behind the sheet after every save; in add
          // mode the sheet stays open for the next entry.
          _loadAll();
        },
      ),
    );
  }

  Future<void> _deletePurchase(Purchase p) async {
    await SupabaseService.deletePurchase(p.id);
    _loadAll();
  }

  // --- Swipe to categorize ---

  void _startCategorize(Purchase p) {
    if (_categories.isEmpty) return;
    setState(() => _categorizingPurchase = p);
  }

  void _dismissCategorize() {
    setState(() => _categorizingPurchase = null);
  }

  Future<void> _assignCategory(CategoryBase? category) async {
    final p = _categorizingPurchase;
    setState(() => _categorizingPurchase = null);
    if (p == null) return;
    try {
      await SupabaseService.updatePurchase(
          p.id, {'category_id': category?.id});
    } catch (e) {
      homeShellKey.currentState?.showBanner(
        title: 'Falha ao categorizar',
        body: '$e',
        icon: Icons.error_outline,
        iconColor: Colors.red,
      );
    }
    _loadAll();
  }

  Widget _buildCategorizeOverlay() {
    return CategorizeOverlay(
      key: _overlayKey,
      categories: _categories,
      itemLabel: _categorizingPurchase?.item ?? '',
      onAssign: _assignCategory,
      onDismiss: _dismissCategorize,
    );
  }

  // --- Build ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.creamBackground,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                if (_isAuthenticated && _searchVisible)
                  _buildSearchBar(),
                if (_isAuthenticated && _tabOwners.isNotEmpty)
                  ListOwnerTabs(
                    owners: _tabOwners,
                    activeOwnerId: _activeOwner!.id,
                    onSelect: (o) =>
                        setState(() => _selectedOwnerId = o.id),
                  ),
                if (_isAuthenticated) _buildMonthBar(),
                Expanded(child: _buildContent()),
              ],
            ),
            if (_categorizingPurchase != null)
              _buildCategorizeOverlay(),
          ],
        ),
      ),
      floatingActionButton:
          _isAuthenticated && _categorizingPurchase == null
          ? FloatingActionButton(
              // Unique tag: the other tabs' FABs coexist in the
              // IndexedStack and default hero tags would clash.
              heroTag: 'purchases_fab',
              onPressed: () => _showPurchaseSheet(),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildHeader() {
    final visible = _visiblePurchases;
    final total =
        visible.fold<double>(0, (sum, p) => sum + p.valor);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 8, 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Gastos', style: AppTheme.headingLarge),
                const SizedBox(height: 4),
                Text(
                  _purchases.isEmpty
                      ? 'Registre seus gastos'
                      : '${visible.length} itens • ${formatBrl(total)}',
                  style: AppTheme.bodyText
                      .copyWith(color: AppTheme.mediumBrown),
                ),
              ],
            ),
          ),
          if (_isAuthenticated) ...[
            IconButton(
              tooltip: 'Buscar',
              icon: Icon(
                Icons.search,
                color: _searchVisible
                    ? AppTheme.primaryOrange
                    : AppTheme.darkBrown,
              ),
              onPressed: _toggleSearch,
            ),
            _uploadingReceipt
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.primaryOrange,
                      ),
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Fotografar cupom',
                        icon: const Icon(Icons.photo_camera_outlined,
                            color: AppTheme.darkBrown),
                        onPressed: () =>
                            _captureReceipt(ImageSource.camera),
                      ),
                      IconButton(
                        tooltip: 'Escolher da galeria',
                        icon: const Icon(Icons.photo_library_outlined,
                            color: AppTheme.darkBrown),
                        onPressed: () =>
                            _captureReceipt(ImageSource.gallery),
                      ),
                    ],
                  ),
            IconButton(
              tooltip: 'Fila de cupons',
              icon: const Icon(Icons.receipt_long_outlined,
                  color: AppTheme.darkBrown),
              onPressed: _openQueue,
            ),
            PopupMenuButton<String>(
              icon:
                  const Icon(Icons.more_vert, color: AppTheme.darkBrown),
              shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(AppTheme.radiusSmall),
              ),
              color: AppTheme.white,
              onSelected: (value) {
                if (value == 'categories') _openEditCategories();
                if (value == 'autocat') _autoCategorize();
                if (value == 'invites') _openInvites();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'autocat',
                  child: Row(
                    children: [
                      Icon(Icons.auto_awesome,
                          color: AppTheme.primaryOrange, size: 20),
                      SizedBox(width: 12),
                      Text('Categorizar gastos'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'categories',
                  child: Row(
                    children: [
                      Icon(Icons.category_outlined,
                          color: AppTheme.primaryOrange, size: 20),
                      SizedBox(width: 12),
                      Text('Editar Categorias'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'invites',
                  child: Row(
                    children: [
                      Icon(Icons.group_add_outlined,
                          color: AppTheme.primaryOrange, size: 20),
                      SizedBox(width: 12),
                      Text('Compartilhar listas'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          boxShadow: AppTheme.softShadow,
        ),
        child: TextField(
          controller: _searchController,
          autofocus: true,
          style: AppTheme.bodyText,
          decoration: InputDecoration(
            hintText: 'Buscar por item, local ou importância',
            hintStyle: TextStyle(
                color: AppTheme.mediumBrown.withValues(alpha: 0.5)),
            prefixIcon: const Icon(Icons.search,
                color: AppTheme.mediumBrown),
            suffixIcon: _searchController.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Limpar',
                    icon: const Icon(Icons.close,
                        color: AppTheme.mediumBrown),
                    onPressed: () =>
                        setState(_searchController.clear),
                  ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 14),
          ),
          onChanged: (_) => setState(() {}),
        ),
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
              icon: const Icon(Icons.chevron_left,
                  color: AppTheme.mediumBrown),
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
              icon: const Icon(Icons.chevron_right,
                  color: AppTheme.mediumBrown),
              onPressed: () => _changeMonth(1),
            ),
          ],
        ),
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
    if (_purchases.isEmpty) return _buildEmptyState();
    final visible = _visiblePurchases;
    if (visible.isEmpty) return _buildNoSearchResults();
    return RefreshIndicator(
      color: AppTheme.primaryOrange,
      onRefresh: _loadAll,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: visible.length,
        itemBuilder: (context, index) =>
            _buildPurchaseCard(visible[index]),
      ),
    );
  }

  Widget _buildNoSearchResults() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off,
              size: 64,
              color:
                  AppTheme.primaryOrange.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          const Text('Nenhum gasto encontrado',
              style: AppTheme.sectionTitle),
          const SizedBox(height: 8),
          const Text('Tente outro termo de busca',
              style: AppTheme.caption),
        ],
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
            const Text('Sign in to manage purchases',
                style: AppTheme.headingMedium,
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              'Go to the Profile tab to sign in or create an account',
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
          Icon(Icons.shopping_bag_outlined,
              size: 64,
              color:
                  AppTheme.primaryOrange.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text('Nenhum gasto em $_monthLabel',
              style: AppTheme.sectionTitle),
          const SizedBox(height: 8),
          const Text('Toque em + ou fotografe um cupom',
              style: AppTheme.caption),
        ],
      ),
    );
  }

  Widget _buildPurchaseCard(Purchase p) {
    final cat = _categoryFor(p);
    return SwipeActionCard(
      key: ValueKey(p.id),
      canCategorize: _categories.isNotEmpty,
      onDelete: () => _deletePurchase(p),
      onCategorizeStart: () => _startCategorize(p),
      onCategorizeDragUpdate: (pos) =>
          _overlayKey.currentState?.updateDrag(pos),
      onCategorizeDragEnd: (pos) =>
          _overlayKey.currentState?.endDrag(pos),
      onTap: () => _showPurchaseSheet(existing: p),
      child: ClipRRect(
        borderRadius:
            BorderRadius.circular(AppTheme.radiusMedium),
        child: Container(
              decoration: BoxDecoration(
                color: AppTheme.white,
                borderRadius:
                    BorderRadius.circular(AppTheme.radiusMedium),
                boxShadow: AppTheme.softShadow,
              ),
              child: IntrinsicHeight(
                child: Row(
                  children: [
                    if (cat != null)
                      Container(width: 4, color: cat.color),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
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
                                      if (p.local != null &&
                                          p.local!.isNotEmpty)
                                        p.local!,
                                      if (cat != null) cat.name,
                                    ].join(' • '),
                                    style: AppTheme.caption.copyWith(
                                        fontWeight: FontWeight.w400),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              formatBrl(p.valor),
                              style: AppTheme.valueBold,
                            ),
                          ],
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
// Add / edit purchase bottom sheet
// ---------------------------------------------------------------------------

class _PurchaseFormResult {
  final String item;
  final double valor;
  final String date;
  final String? local;
  final String? categoryId;

  const _PurchaseFormResult({
    required this.item,
    required this.valor,
    required this.date,
    this.local,
    this.categoryId,
  });
}

/// Owns its text controllers so they are only disposed once the sheet's
/// route (including the close animation) is fully gone.
///
/// Edit mode saves and closes; add mode saves and stays open, clearing
/// Item and Valor but keeping Data, Local and Importância so several
/// items from the same receipt can be typed in a row.
class _PurchaseSheet extends StatefulWidget {
  final Purchase? existing;
  final List<PurchaseCategory> categories;
  final Future<void> Function(_PurchaseFormResult result) onSubmit;

  const _PurchaseSheet({
    this.existing,
    required this.categories,
    required this.onSubmit,
  });

  @override
  State<_PurchaseSheet> createState() => _PurchaseSheetState();
}

class _PurchaseSheetState extends State<_PurchaseSheet> {
  late final TextEditingController _itemController;
  late final TextEditingController _valorController;
  late final TextEditingController _localController;
  final _itemFocus = FocusNode();
  final _valorFocus = FocusNode();
  late String _date;
  String? _localPreset;
  String? _categoryId;
  bool _saving = false;
  int _addedCount = 0;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _itemController = TextEditingController(text: existing?.item ?? '');
    _valorController = TextEditingController(
        text: existing != null
            ? existing.valor.toStringAsFixed(2).replaceAll('.', ',')
            : '');
    // A saved local that matches a frequent place lands in the dropdown;
    // anything else goes to the free-text side.
    final existingLocal = existing?.local;
    if (existingLocal != null && kFrequentLocals.contains(existingLocal)) {
      _localPreset = existingLocal;
      _localController = TextEditingController();
    } else {
      _localController = TextEditingController(text: existingLocal ?? '');
    }
    _date = existing?.purchaseDate ??
        DateTime.now().toIso8601String().substring(0, 10);
    _categoryId = existing?.categoryId;
    // New purchases start with the place guessed from where the phone
    // is; edits keep whatever local was saved.
    if (existing == null) _guessLocal();
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
    _itemController.dispose();
    _valorController.dispose();
    _localController.dispose();
    _itemFocus.dispose();
    _valorFocus.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final item = _itemController.text.trim();
    if (item.isEmpty || _saving) return;
    final typedLocal = _localController.text.trim();
    final local =
        _localPreset ?? (typedLocal.isEmpty ? null : typedLocal);
    final result = _PurchaseFormResult(
      item: item,
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
    if (!mounted) return;

    if (widget.existing != null) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      _saving = false;
      _addedCount++;
      _itemController.clear();
      _valorController.clear();
    });
    _itemFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final existing = widget.existing;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            existing != null ? 'Editar Gasto' : 'Novo Gasto',
            style: AppTheme.headingMedium,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _itemController,
            focusNode: _itemFocus,
            autofocus: existing == null,
            textInputAction: TextInputAction.next,
            decoration: _fieldDecoration('Item').copyWith(
              suffixIcon: ValueListenableBuilder<TextEditingValue>(
                valueListenable: _itemController,
                builder: (context, value, _) {
                  final hasText = value.text.trim().isNotEmpty;
                  return IconButton(
                    icon: Icon(hasText
                        ? Icons.content_copy
                        : Icons.content_paste),
                    tooltip: hasText ? 'Copiar' : 'Colar',
                    onPressed: hasText
                        ? () async {
                            await Clipboard.setData(
                                ClipboardData(text: value.text));
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Copiado')),
                            );
                          }
                        : () async {
                            final data = await Clipboard.getData(
                                Clipboard.kTextPlain);
                            final text = data?.text;
                            if (text == null || text.isEmpty) return;
                            _itemController.text = text;
                            _itemController.selection =
                                TextSelection.collapsed(
                                    offset: text.length);
                          },
                  );
                },
              ),
            ),
            onSubmitted: (_) => _valorFocus.requestFocus(),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _valorController,
                  focusNode: _valorFocus,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true),
                  textInputAction: TextInputAction.done,
                  decoration: _fieldDecoration('Valor (R\$)').copyWith(
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.backspace_outlined),
                      tooltip: 'Limpar',
                      onPressed: () {
                        _valorController.clear();
                        _valorFocus.requestFocus();
                      },
                    ),
                  ),
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
                child: Text('Sem importância'),
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
                  : Text(existing != null ? 'Salvar' : 'Adicionar'),
            ),
          ),
          if (existing == null && _addedCount > 0) ...[
            const SizedBox(height: 10),
            Center(
              child: Text(
                '✓ $_addedCount '
                '${_addedCount == 1 ? 'gasto adicionado' : 'gastos adicionados'}',
                style: AppTheme.caption
                    .copyWith(color: Colors.green.shade700),
              ),
            ),
          ],
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
