import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../app_theme.dart';
import '../models/purchase.dart';
import '../models/purchase_category.dart';
import '../services/category_store.dart';
import '../services/supabase_service.dart';
import '../utils/brl.dart';
import 'edit_categories_screen.dart';
import 'home_shell.dart' show homeShellKey;
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

  List<Purchase> _purchases = [];
  List<PurchaseCategory> _categories = [];
  bool _isLoading = true;
  bool _uploadingReceipt = false;
  StreamSubscription? _authSubscription;

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

    _authSubscription =
        SupabaseService.authStateChanges.listen((data) {
      if (mounted) {
        setState(() {});
        _loadAll();
      }
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  bool get _isAuthenticated => SupabaseService.currentUser != null;

  Future<void> _loadAll() async {
    if (!_isAuthenticated) {
      if (mounted) {
        setState(() {
          _purchases = [];
          _categories = [];
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
      ]);
      if (mounted) {
        setState(() {
          _purchases = results[0] as List<Purchase>;
          _categories = results[1] as List<PurchaseCategory>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
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
          builder: (_) =>
              EditCategoriesScreen(store: PurchaseCategoryStore())),
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
            if (_isAuthenticated) _buildMonthBar(),
            Expanded(child: _buildContent()),
          ],
        ),
      ),
      floatingActionButton: _isAuthenticated
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
    final total =
        _purchases.fold<double>(0, (sum, p) => sum + p.valor);
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
                      : '${_purchases.length} itens • ${formatBrl(total)}',
                  style: AppTheme.bodyText
                      .copyWith(color: AppTheme.mediumBrown),
                ),
              ],
            ),
          ),
          if (_isAuthenticated) ...[
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
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'categories',
                  child: Row(
                    children: [
                      Icon(Icons.category_outlined,
                          color: AppTheme.primaryOrange, size: 20),
                      SizedBox(width: 12),
                      Text('Editar Importâncias'),
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
    return RefreshIndicator(
      color: AppTheme.primaryOrange,
      onRefresh: _loadAll,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _purchases.length,
        itemBuilder: (context, index) =>
            _buildPurchaseCard(_purchases[index]),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Dismissible(
        key: ValueKey(p.id),
        direction: DismissDirection.endToStart,
        onDismissed: (_) => _deletePurchase(p),
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
        child: GestureDetector(
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
  late String _date;
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
    _localController = TextEditingController(text: existing?.local ?? '');
    _date = existing?.purchaseDate ??
        DateTime.now().toIso8601String().substring(0, 10);
    _categoryId = existing?.categoryId;
  }

  @override
  void dispose() {
    _itemController.dispose();
    _valorController.dispose();
    _localController.dispose();
    _itemFocus.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final item = _itemController.text.trim();
    if (item.isEmpty || _saving) return;
    final local = _localController.text.trim();
    final result = _PurchaseFormResult(
      item: item,
      valor: parseBrlInput(_valorController.text) ?? 0,
      date: _date,
      local: local.isEmpty ? null : local,
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
            decoration: _fieldDecoration('Item'),
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _valorController,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true),
                  decoration: _fieldDecoration('Valor (R\$)'),
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
          TextField(
            controller: _localController,
            decoration: _fieldDecoration('Local'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            initialValue: _categoryId,
            decoration: _fieldDecoration('Importância'),
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
