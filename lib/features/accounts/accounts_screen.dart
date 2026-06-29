import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../app/theme/app_colors.dart';
import '../../data/local/app_database.dart';
import '../../shared/providers/account_providers.dart';
import '../../shared/providers/database_provider.dart';

class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(accountsStreamProvider);
    final balancesAsync = ref.watch(accountBalancesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Cuentas',
            style: Theme.of(context).textTheme.headlineMedium),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () => _showAddSheet(context, ref),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: accountsAsync.when(
        data: (accounts) {
          if (accounts.isEmpty) return const _EmptyAccounts();

          final balances = balancesAsync.valueOrNull ?? {};
          final totalCents =
              balances.values.fold<int>(0, (s, v) => s + v);

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
            children: [
              _TotalCard(totalCents: totalCents),
              const SizedBox(height: 20),
              Text('Mis cuentas',
                  style: Theme.of(context)
                      .textTheme
                      .labelLarge
                      ?.copyWith(color: AppColors.textMuted)),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: accounts.asMap().entries.map((e) {
                    final i = e.key;
                    final acc = e.value;
                    final balance = balances[acc.id] ?? 0;
                    return Column(
                      children: [
                        _AccountTile(
                          account: acc,
                          balanceCents: balance,
                          onTap: () =>
                              _showEditSheet(context, ref, acc, balance),
                        ),
                        if (i < accounts.length - 1)
                          const Divider(
                              height: 1, indent: 56, color: AppColors.border),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, st) => const SizedBox(),
      ),
    );
  }

  void _showAddSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AccountFormSheet(),
    );
  }

  void _showEditSheet(
      BuildContext context, WidgetRef ref, Account account, int balance) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _AccountFormSheet(account: account, currentBalance: balance),
    );
  }
}

// ── Tarjeta de total ─────────────────────────────────────────────────────────

class _TotalCard extends StatelessWidget {
  final int totalCents;
  const _TotalCard({required this.totalCents});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(symbol: 'S/ ', decimalDigits: 2);
    final isPositive = totalCents >= 0;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Balance total',
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(color: Colors.white70)),
          const SizedBox(height: 8),
          Text(
            fmt.format(totalCents.abs() / 100),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (!isPositive)
            const Text('Saldo negativo',
                style: TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }
}

// ── Tile de cuenta ───────────────────────────────────────────────────────────

class _AccountTile extends StatelessWidget {
  final Account account;
  final int balanceCents;
  final VoidCallback onTap;

  const _AccountTile({
    required this.account,
    required this.balanceCents,
    required this.onTap,
  });

  IconData _icon(String type) {
    switch (type) {
      case 'bank':
        return Icons.account_balance_outlined;
      case 'savings':
        return Icons.savings_outlined;
      case 'credit':
        return Icons.credit_card_outlined;
      case 'wallet':
        return Icons.account_balance_wallet_outlined;
      default:
        return Icons.attach_money;
    }
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'bank':
        return 'Banco';
      case 'savings':
        return 'Ahorro';
      case 'credit':
        return 'Crédito';
      case 'wallet':
        return 'Cartera';
      default:
        return 'Efectivo';
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(symbol: 'S/ ', decimalDigits: 2);
    final isNegative = balanceCents < 0;

    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(_icon(account.type),
            color: AppColors.primary, size: 20),
      ),
      title: Text(account.name,
          style: Theme.of(context).textTheme.bodyLarge),
      subtitle: Text(_typeLabel(account.type),
          style: Theme.of(context).textTheme.labelSmall),
      trailing: Text(
        fmt.format(balanceCents.abs() / 100),
        style: TextStyle(
          color: isNegative ? AppColors.expense : AppColors.textPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 15,
        ),
      ),
    );
  }
}

// ── Estado vacío ─────────────────────────────────────────────────────────────

class _EmptyAccounts extends StatelessWidget {
  const _EmptyAccounts();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.account_balance_wallet_outlined,
              size: 64, color: AppColors.textMuted),
          const SizedBox(height: 16),
          Text('Sin cuentas',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: AppColors.textMuted)),
          const SizedBox(height: 8),
          Text('Toca + para agregar tu primera cuenta',
              style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

// ── Formulario de cuenta ─────────────────────────────────────────────────────

const _accountTypes = [
  ('cash', 'Efectivo'),
  ('bank', 'Banco'),
  ('savings', 'Ahorro'),
  ('credit', 'Crédito'),
  ('wallet', 'Cartera'),
];

class _AccountFormSheet extends ConsumerStatefulWidget {
  final Account? account;
  final int? currentBalance;

  const _AccountFormSheet({this.account, this.currentBalance});

  @override
  ConsumerState<_AccountFormSheet> createState() => _AccountFormSheetState();
}

class _AccountFormSheetState extends ConsumerState<_AccountFormSheet> {
  late TextEditingController _nameController;
  late TextEditingController _balanceController;
  late String _type;
  bool _saving = false;

  bool get _isEdit => widget.account != null;

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: widget.account?.name ?? '');
    _balanceController = TextEditingController(
      text: _isEdit
          ? (widget.account!.initialBalanceCents / 100).toStringAsFixed(2)
          : '',
    );
    _type = widget.account?.type ?? 'cash';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showError('Ingresa el nombre de la cuenta');
      return;
    }

    final balanceText =
        _balanceController.text.trim().replaceAll(',', '.');
    final balance = double.tryParse(balanceText) ?? 0.0;

    setState(() => _saving = true);
    final db = ref.read(databaseProvider);
    final now = DateTime.now().millisecondsSinceEpoch;

    if (_isEdit) {
      await db.accountDao.updateAccount(AccountsCompanion(
        id: Value(widget.account!.id),
        name: Value(name),
        type: Value(_type),
        initialBalanceCents: Value((balance * 100).round()),
      ));
    } else {
      await db.accountDao.insertAccount(AccountsCompanion(
        id: Value(const Uuid().v4()),
        name: Value(name),
        type: Value(_type),
        initialBalanceCents: Value((balance * 100).round()),
        currency: const Value('PEN'),
        createdAt: Value(now),
      ));
    }

    if (mounted) Navigator.of(context, rootNavigator: true).pop();
  }

  Future<void> _archive() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Archivar cuenta'),
        content: const Text(
            '¿Seguro? La cuenta dejará de aparecer pero se conserva el historial.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar',
                style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.expense),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Archivar'),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      final db = ref.read(databaseProvider);
      await db.accountDao.updateAccount(AccountsCompanion(
        id: Value(widget.account!.id),
        archived: const Value(true),
      ));
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: AppColors.expense));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_isEdit ? 'Editar cuenta' : 'Nueva cuenta',
                    style: Theme.of(context).textTheme.titleLarge),
                if (_isEdit)
                  TextButton(
                    onPressed: _archive,
                    child: const Text('Archivar',
                        style: TextStyle(color: AppColors.expense)),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Nombre de la cuenta'),
            ),
            const SizedBox(height: 16),
            Text('Tipo',
                style: Theme.of(context)
                    .textTheme
                    .labelMedium
                    ?.copyWith(color: AppColors.textMuted)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _accountTypes.map((t) {
                final isSelected = _type == t.$1;
                return GestureDetector(
                  onTap: () => setState(() => _type = t.$1),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary.withValues(alpha: 0.15)
                          : AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.border,
                      ),
                    ),
                    child: Text(
                      t.$2,
                      style: TextStyle(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.textSecondary,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w400,
                        fontSize: 13,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _balanceController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Saldo inicial',
                prefixText: 'S/ ',
                helperText: 'Cuánto tienes ahora mismo en esta cuenta',
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 20, width: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : Text(_isEdit ? 'Guardar cambios' : 'Crear cuenta'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

