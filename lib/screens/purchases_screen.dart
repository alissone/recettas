import 'dart:async';
import 'dart:io';

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
  List<Purchase> _purchases = [];
  List<PurchaseCategory> _categories = [];
  bool _isLoading = true;
  bool _uploadingReceipt = false;
  StreamSubscription? _authSubscription;

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
        SupabaseService.getPurchases(),
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

  Future<void> _captureReceipt() async {
    final picker = ImagePicker();
    final useCamera = Platform.isAndroid || Platform.isIOS;
    XFile? file;
    try {
      file = await picker.pickImage(
        source: useCamera ? ImageSource.camera : ImageSource.gallery,
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
    final result = await showModalBottomSheet<_PurchaseFormResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.creamBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppTheme.radiusLarge)),
      ),
      builder: (_) =>
          _PurchaseSheet(existing: existing, categories: _categories),
    );

    if (result == null) return;
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
    _loadAll();
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
            Expanded(child: _buildContent()),
          ],
        ),
      ),
      floatingActionButton: _isAuthenticated
          ? FloatingActionButton(
              // Unique tag: the Afazeres FAB coexists in the
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
                const Text('Compras', style: AppTheme.headingLarge),
                const SizedBox(height: 4),
                Text(
                  _purchases.isEmpty
                      ? 'Registre suas compras'
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
                : IconButton(
                    tooltip: 'Fotografar cupom',
                    icon: const Icon(Icons.photo_camera_outlined,
                        color: AppTheme.darkBrown),
                    onPressed: _captureReceipt,
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
          const Text('Nenhuma compra ainda',
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
/// route (including the close animation) is fully gone; results come
/// back through Navigator.pop.
class _PurchaseSheet extends StatefulWidget {
  final Purchase? existing;
  final List<PurchaseCategory> categories;

  const _PurchaseSheet({this.existing, required this.categories});

  @override
  State<_PurchaseSheet> createState() => _PurchaseSheetState();
}

class _PurchaseSheetState extends State<_PurchaseSheet> {
  late final TextEditingController _itemController;
  late final TextEditingController _valorController;
  late final TextEditingController _localController;
  late String _date;
  String? _categoryId;

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
    super.dispose();
  }

  void _save() {
    final item = _itemController.text.trim();
    if (item.isEmpty) {
      Navigator.pop(context);
      return;
    }
    final local = _localController.text.trim();
    Navigator.pop(
      context,
      _PurchaseFormResult(
        item: item,
        valor: parseBrlInput(_valorController.text) ?? 0,
        date: _date,
        local: local.isEmpty ? null : local,
        categoryId: _categoryId,
      ),
    );
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
            existing != null ? 'Editar Compra' : 'Nova Compra',
            style: AppTheme.headingMedium,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _itemController,
            autofocus: existing == null,
            decoration: _fieldDecoration('Item'),
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
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryOrange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppTheme.radiusSmall),
                ),
              ),
              child: Text(existing != null ? 'Salvar' : 'Adicionar'),
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
