import 'package:drift/drift.dart' hide Column;
import '../../shared/utils/amount_parser.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../app/theme/app_colors.dart';
import '../../data/local/app_database.dart';
import '../../shared/providers/database_provider.dart';
import '../../shared/providers/transaction_providers.dart';
import '../streak/streak_service.dart';
import 'quick_transaction.dart';

const _uuid = Uuid();

class QuickTransactionsRow extends ConsumerWidget {
  const QuickTransactionsRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quicks = ref.watch(quickTransactionProvider).valueOrNull ?? [];

    if (quicks.isEmpty) {
      return _AddChip(onTap: () => _showAddSheet(context, ref));
    }

    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          ...quicks.map((q) => _QuickChip(
                quick: q,
                onTap: () => _apply(context, ref, q),
                onLongPress: () => _confirmDelete(context, ref, q),
              )),
          const SizedBox(width: 8),
          _AddChip(onTap: () => _showAddSheet(context, ref)),
        ],
      ),
    );
  }

  Future<void> _apply(BuildContext context, WidgetRef ref, QuickTransaction q) async {
    final db = ref.read(databaseProvider);
    final now = DateTime.now();
    await db.transactionDao.insertTransaction(TransactionsCompanion(
      id: Value(_uuid.v4()),
      type: Value(q.type),
      amountCents: Value(q.amountCents),
      accountId: Value(q.accountId),
      categoryId: Value(q.categoryId),
      date: Value(now.millisecondsSinceEpoch),
      createdAt: Value(now.millisecondsSinceEpoch),
      updatedAt: Value(now.millisecondsSinceEpoch),
    ));
    await StreakService.recordActivity();

    ref.invalidate(monthlySummaryProvider);
    ref.invalidate(totalBalanceProvider);

    if (context.mounted) {
      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${q.name} registrado ✓'),
        duration: const Duration(seconds: 2),
        backgroundColor: AppColors.income,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    }
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, QuickTransaction q) async {
    HapticFeedback.mediumImpact();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Eliminar acceso'),
        content: Text('¿Eliminar "${q.name}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Eliminar',
                  style: TextStyle(color: AppColors.expense))),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(quickTransactionProvider.notifier).remove(q.id);
    }
  }

  Future<void> _showAddSheet(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddQuickSheet(ref: ref),
    );
  }
}

// ── Chip de acceso rápido ─────────────────────────────────────────────────────

class _QuickChip extends StatelessWidget {
  final QuickTransaction quick;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _QuickChip({
    required this.quick,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(symbol: 'S/ ', decimalDigits: 2);
    final isIncome = quick.type == 'income';
    final color = isIncome ? AppColors.income : AppColors.primary;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(
              isIncome ? Icons.add_circle_outline : Icons.remove_circle_outline,
              size: 14,
              color: color,
            ),
            const SizedBox(width: 5),
            Text(
              '${quick.name}  ${fmt.format(quick.amountCents / 100)}',
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _AddChip extends StatelessWidget {
  final VoidCallback onTap;
  const _AddChip({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.add, size: 14, color: AppColors.textMuted),
          SizedBox(width: 4),
          Text('Nuevo', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
        ]),
      ),
    );
  }
}

// ── Sheet para crear acceso rápido ────────────────────────────────────────────

class _AddQuickSheet extends ConsumerStatefulWidget {
  final WidgetRef ref;
  const _AddQuickSheet({required this.ref});

  @override
  ConsumerState<_AddQuickSheet> createState() => _AddQuickSheetState();
}

class _AddQuickSheetState extends ConsumerState<_AddQuickSheet> {
  final _nameCtrl   = TextEditingController();
  final _amountCtrl = TextEditingController();
  String _type = 'expense';
  Account? _account;
  Category? _category;
  bool _saving = false;
  double? _exprResult;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name   = _nameCtrl.text.trim();
    final amount = parseAmountExpression(_amountCtrl.text.trim());
    if (name.isEmpty || amount == null || amount <= 0 || _account == null) return;

    setState(() => _saving = true);
    await widget.ref.read(quickTransactionProvider.notifier).add(QuickTransaction(
      id: _uuid.v4(),
      name: name,
      amountCents: (amount * 100).round(),
      type: _type,
      accountId: _account!.id,
      categoryId: _category?.id,
    ));
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final accounts   = ref.watch(accountsProvider).valueOrNull ?? [];
    final categories = (_type == 'income'
            ? ref.watch(incomeCategoriesProvider)
            : ref.watch(expenseCategoriesProvider))
        .valueOrNull ?? [];

    _account ??= accounts.firstOrNull;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: AppColors.border, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 20),
          Text('Nuevo acceso rápido',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 20),

          // Tipo
          Row(children: ['expense', 'income'].map((t) {
            final sel = _type == t;
            final label = t == 'expense' ? 'Gasto' : 'Ingreso';
            final color = t == 'expense' ? AppColors.expense : AppColors.income;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: t == 'expense' ? 8 : 0),
                child: GestureDetector(
                  onTap: () => setState(() { _type = t; _category = null; }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: sel ? color.withValues(alpha: 0.15) : AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: sel ? color : AppColors.border),
                    ),
                    child: Text(label,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: sel ? color : AppColors.textMuted,
                            fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
                            fontSize: 14)),
                  ),
                ),
              ),
            );
          }).toList()),
          const SizedBox(height: 16),

          // Nombre
          TextField(
            controller: _nameCtrl,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
                labelText: 'Nombre', hintText: 'Almuerzo, Pasaje, Café…'),
          ),
          const SizedBox(height: 12),

          // Monto
          TextField(
            controller: _amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Monto',
              prefixText: 'S/ ',
              hintText: '0.00  ó  3*12  ó  50+30',
              helperText: _exprResult != null
                  ? '= S/ ${_exprResult!.toStringAsFixed(2)}'
                  : null,
              helperStyle: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600),
            ),
            onChanged: (v) {
              if (isExpression(v)) {
                setState(() => _exprResult = parseAmountExpression(v));
              } else {
                setState(() => _exprResult = null);
              }
            },
          ),
          const SizedBox(height: 12),

          // Cuenta
          if (accounts.isNotEmpty)
            DropdownButtonFormField<Account>(
              initialValue: _account,
              dropdownColor: AppColors.surface,
              decoration: const InputDecoration(labelText: 'Cuenta'),
              items: accounts.map((a) => DropdownMenuItem(
                value: a,
                child: Text(a.name),
              )).toList(),
              onChanged: (a) => setState(() => _account = a),
            ),
          const SizedBox(height: 12),

          // Categoría
          if (categories.isNotEmpty)
            DropdownButtonFormField<Category>(
              initialValue: _category,
              dropdownColor: AppColors.surface,
              decoration: const InputDecoration(labelText: 'Categoría (opcional)'),
              items: categories.map((c) => DropdownMenuItem(
                value: c,
                child: Text(c.name),
              )).toList(),
              onChanged: (c) => setState(() => _category = c),
            ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(_saving ? 'Guardando…' : 'Guardar acceso',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
        ]),
      ),
    );
  }
}
