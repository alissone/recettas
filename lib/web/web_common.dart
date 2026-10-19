// Small pieces shared by the web build's screens. Kept apart from the
// app's widgets so nothing here drags HomeShell (and through it every
// other tab) into the web bundle.
import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../models/category_base.dart';
import '../models/list_invite.dart';
import '../models/purchase_category.dart';
import '../services/supabase_service.dart';
import '../utils/brl.dart';
import '../widgets/local_field.dart';

/// Content width on desktop browsers; phones use the full width.
const double kWebMaxWidth = 720;

/// Centers [child] and caps its width so lists don't stretch across a
/// wide monitor.
class WebPage extends StatelessWidget {
  final Widget child;

  const WebPage({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: kWebMaxWidth),
        child: child,
      ),
    );
  }
}

/// Title + subtitle row at the top of each tab, with the sign-out button
/// after any [actions].
class WebHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> actions;

  const WebHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 8, 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTheme.headingLarge),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style:
                      AppTheme.bodyText.copyWith(color: AppTheme.mediumBrown),
                ),
              ],
            ),
          ),
          ...actions,
          const SignOutButton(),
        ],
      ),
    );
  }
}

class SignOutButton extends StatelessWidget {
  const SignOutButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Sair',
      icon: const Icon(Icons.logout),
      color: AppTheme.mediumBrown,
      onPressed: SupabaseService.signOut,
    );
  }
}

/// Single-line "type and press Enter" field used to add todos and
/// shopping items.
class QuickAddField extends StatefulWidget {
  final String hint;
  final IconData icon;
  final Future<void> Function(String text) onSubmit;

  const QuickAddField({
    super.key,
    required this.hint,
    required this.icon,
    required this.onSubmit,
  });

  @override
  State<QuickAddField> createState() => _QuickAddFieldState();
}

class _QuickAddFieldState extends State<QuickAddField> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    // Keep focus so several entries can be typed in a row.
    _focus.requestFocus();
    widget.onSubmit(text);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          boxShadow: AppTheme.softShadow,
        ),
        child: TextField(
          controller: _controller,
          focusNode: _focus,
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle:
                TextStyle(color: AppTheme.mediumBrown.withValues(alpha: 0.5)),
            prefixIcon: Icon(widget.icon, color: AppTheme.primaryOrange),
            suffixIcon: IconButton(
              tooltip: 'Adicionar',
              icon: const Icon(Icons.add, color: AppTheme.primaryOrange),
              onPressed: _submit,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              borderSide:
                  const BorderSide(color: AppTheme.primaryOrange, width: 2),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          onSubmitted: (_) => _submit(),
        ),
      ),
    );
  }
}

/// The orange rounded checkbox used on todo and shopping cards.
class WebCheckbox extends StatelessWidget {
  final bool checked;
  final VoidCallback onTap;

  const WebCheckbox({super.key, required this.checked, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: checked
                ? AppTheme.primaryOrange
                : AppTheme.primaryOrange.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: checked
                ? null
                : Border.all(color: AppTheme.borderOrange, width: 2),
          ),
          child: checked
              ? const Icon(Icons.check, size: 18, color: Colors.white)
              : null,
        ),
      ),
    );
  }
}

/// White rounded card with an optional category stripe on the left.
class WebCard extends StatelessWidget {
  final Color? stripe;
  final Widget child;
  final EdgeInsetsGeometry padding;

  const WebCard({
    super.key,
    this.stripe,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: AppTheme.softShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (stripe != null) Container(width: 4, color: stripe),
              Expanded(child: Padding(padding: padding, child: child)),
            ],
          ),
        ),
      ),
    );
  }
}

class WebEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const WebEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 64,
                color: AppTheme.primaryOrange.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text(title,
                style: AppTheme.sectionTitle, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(subtitle,
                style: AppTheme.caption, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

const webSpinner = Center(
  child: CircularProgressIndicator(color: AppTheme.primaryOrange),
);

void showWebError(BuildContext context, Object error) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Erro: $error')),
  );
}

void showWebMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message)),
  );
}

InputDecoration webFieldDecoration(String label) {
  return InputDecoration(
    labelText: label,
    labelStyle: TextStyle(color: AppTheme.mediumBrown.withValues(alpha: 0.8)),
    filled: true,
    fillColor: AppTheme.white,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      borderSide: const BorderSide(color: AppTheme.primaryOrange, width: 2),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  );
}

// Same rules as the app's Compras/Gastos tabs for shared lists.

/// Owners with a non-empty list; tabs only appear when more than one
/// list has items.
List<ListOwner> ownerTabs(List<ListOwner> owners, Set<String> withItems) {
  final tabs = [
    for (final o in owners)
      if (withItems.contains(o.id)) o
  ];
  return tabs.length > 1 ? tabs : const [];
}

/// List being displayed: the picked tab, else the only non-empty list
/// (so an invited user lands on the inviter's list), else the user's
/// own list.
ListOwner? activeOwner(
    List<ListOwner> owners, Set<String> withItems, String? selectedId) {
  if (owners.isEmpty) return null;
  final tabs = ownerTabs(owners, withItems);
  if (tabs.isNotEmpty) {
    return tabs.firstWhere((o) => o.id == selectedId,
        orElse: () => tabs.first);
  }
  for (final o in owners) {
    if (withItems.contains(o.id)) return o;
  }
  return owners.first;
}

String todayDateString() => DateTime.now().toIso8601String().substring(0, 10);

// ---------------------------------------------------------------------------
// Gasto form: adding/editing in Gastos and checking an item in Compras
// ---------------------------------------------------------------------------

class PurchaseFormResult {
  final String item;
  final double valor;
  final String date;
  final String? local;
  final String? categoryId;

  const PurchaseFormResult({
    required this.item,
    required this.valor,
    required this.date,
    this.local,
    this.categoryId,
  });
}

/// Opens the gasto form as a dialog. Resolves once the dialog closes;
/// [onSubmit] runs the save and keeps the dialog open if it throws.
///
/// [lockedItem] shows the item name as a subtitle instead of a field
/// (Compras: the item is the shopping list entry).
Future<void> showPurchaseForm(
  BuildContext context, {
  required String title,
  required String submitLabel,
  required List<PurchaseCategory> categories,
  required Future<void> Function(PurchaseFormResult result) onSubmit,
  String? lockedItem,
  String? item,
  double? valor,
  String? date,
  String? local,
  String? categoryId,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => Dialog(
      backgroundColor: AppTheme.creamBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: _PurchaseForm(
          title: title,
          submitLabel: submitLabel,
          categories: categories,
          onSubmit: onSubmit,
          lockedItem: lockedItem,
          item: item,
          valor: valor,
          date: date,
          local: local,
          categoryId: categoryId,
        ),
      ),
    ),
  );
}

class _PurchaseForm extends StatefulWidget {
  final String title;
  final String submitLabel;
  final List<PurchaseCategory> categories;
  final Future<void> Function(PurchaseFormResult result) onSubmit;
  final String? lockedItem;
  final String? item;
  final double? valor;
  final String? date;
  final String? local;
  final String? categoryId;

  const _PurchaseForm({
    required this.title,
    required this.submitLabel,
    required this.categories,
    required this.onSubmit,
    this.lockedItem,
    this.item,
    this.valor,
    this.date,
    this.local,
    this.categoryId,
  });

  @override
  State<_PurchaseForm> createState() => _PurchaseFormState();
}

class _PurchaseFormState extends State<_PurchaseForm> {
  late final TextEditingController _itemController;
  late final TextEditingController _valorController;
  late final TextEditingController _localController;
  late String _date;
  String? _localPreset;
  String? _categoryId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _itemController = TextEditingController(text: widget.item ?? '');
    _valorController = TextEditingController(
        text: widget.valor?.toStringAsFixed(2).replaceAll('.', ',') ?? '');
    // Same split as the app: a known place goes to the dropdown,
    // anything else to the free-text side. No GPS guess on the web.
    final local = widget.local;
    if (local != null && kFrequentLocals.contains(local)) {
      _localPreset = local;
      _localController = TextEditingController();
    } else {
      _localController = TextEditingController(text: local ?? '');
    }
    _date = widget.date ?? todayDateString();
    // Drop a category that belongs to another list.
    _categoryId = widget.categories.any((c) => c.id == widget.categoryId)
        ? widget.categoryId
        : null;
  }

  @override
  void dispose() {
    _itemController.dispose();
    _valorController.dispose();
    _localController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final item = widget.lockedItem ?? _itemController.text.trim();
    if (item.isEmpty || _saving) return;
    final typedLocal = _localController.text.trim();
    final result = PurchaseFormResult(
      item: item,
      valor: parseBrlInput(_valorController.text) ?? 0,
      date: _date,
      local: _localPreset ?? (typedLocal.isEmpty ? null : typedLocal),
      categoryId: _categoryId,
    );
    setState(() => _saving = true);
    try {
      await widget.onSubmit(result);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showWebError(context, e);
      }
      return;
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(_date) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _date = picked.toIso8601String().substring(0, 10));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.title, style: AppTheme.headingMedium),
          if (widget.lockedItem != null) ...[
            const SizedBox(height: 4),
            Text(
              widget.lockedItem!,
              style: AppTheme.bodyText.copyWith(color: AppTheme.mediumBrown),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 16),
          if (widget.lockedItem == null) ...[
            TextField(
              controller: _itemController,
              autofocus: true,
              decoration: webFieldDecoration('Item'),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _valorController,
                  autofocus: widget.lockedItem != null,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: webFieldDecoration('Valor (R\$)'),
                  onSubmitted: (_) => _save(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: _pickDate,
                  child: InputDecorator(
                    decoration: webFieldDecoration('Data'),
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
            decorationBuilder: webFieldDecoration,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            initialValue: _categoryId,
            decoration: webFieldDecoration('Categoria'),
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
                      CategoryDot(category: c),
                      const SizedBox(width: 8),
                      Text(c.name),
                    ],
                  ),
                ),
            ],
            onChanged: (v) => setState(() => _categoryId = v),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _saving ? null : () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryOrange,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text(widget.submitLabel),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class CategoryDot extends StatelessWidget {
  final CategoryBase category;

  const CategoryDot({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: category.color,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}
