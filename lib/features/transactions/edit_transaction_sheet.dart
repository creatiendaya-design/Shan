import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/theme/app_colors.dart';
import '../../data/local/app_database.dart';
import '../../shared/providers/database_provider.dart';
import '../../shared/providers/transaction_providers.dart';

class EditTransactionSheet extends ConsumerStatefulWidget {
  final Transaction transaction;
  const EditTransactionSheet({super.key, required this.transaction});

  @override
  ConsumerState<EditTransactionSheet> createState() =>
      _EditTransactionSheetState();
}

class _EditTransactionSheetState extends ConsumerState<EditTransactionSheet> {
  late String _type;
  late TextEditingController _amountController;
  late TextEditingController _noteController;
  Category? _selectedCategory;
  Account? _selectedAccount;
  late DateTime _date;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final tx = widget.transaction;
    _type = tx.type;
    _amountController = TextEditingController(
        text: (tx.amountCents / 100).toStringAsFixed(2));
    _noteController = TextEditingController(text: tx.note ?? '');
    _date = DateTime.fromMillisecondsSinceEpoch(tx.date);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amountText = _amountController.text.trim().replaceAll(',', '.');
    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      _showError('Ingresa un monto válido');
      return;
    }
    if (_selectedAccount == null) {
      _showError('Selecciona una cuenta');
      return;
    }
    if (_type != 'transfer' && _selectedCategory == null) {
      _showError('Selecciona una categoría');
      return;
    }

    setState(() => _saving = true);
    final db = ref.read(databaseProvider);
    final now = DateTime.now().millisecondsSinceEpoch;

    await db.transactionDao.updateTransaction(TransactionsCompanion(
      id: Value(widget.transaction.id),
      type: Value(_type),
      amountCents: Value((amount * 100).round()),
      accountId: Value(_selectedAccount!.id),
      categoryId: Value(_selectedCategory?.id),
      date: Value(_date.millisecondsSinceEpoch),
      note: Value(
          _noteController.text.trim().isEmpty ? null : _noteController.text.trim()),
      updatedAt: Value(now),
    ));

    if (mounted) Navigator.of(context, rootNavigator: true).pop();
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: AppColors.expense));
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _date = picked);
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(accountsProvider).valueOrNull ?? [];
    final categories = ref.watch(
      _type == 'expense' ? expenseCategoriesProvider : incomeCategoriesProvider,
    ).valueOrNull ?? [];

    // Set defaults once data loads
    if (_selectedAccount == null && accounts.isNotEmpty) {
      _selectedAccount = accounts.firstWhere(
        (a) => a.id == widget.transaction.accountId,
        orElse: () => accounts.first,
      );
    }
    if (_selectedCategory == null &&
        categories.isNotEmpty &&
        widget.transaction.categoryId != null) {
      _selectedCategory = categories.firstWhere(
        (c) => c.id == widget.transaction.categoryId,
        orElse: () => categories.first,
      );
    }

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
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
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
                Text('Editar transacción',
                    style: Theme.of(context).textTheme.titleLarge),
                TextButton(
                  onPressed: () => _confirmDelete(context),
                  child: const Text('Eliminar',
                      style: TextStyle(color: AppColors.expense)),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _TypeSelector(
              selected: _type,
              onChanged: (t) => setState(() {
                _type = t;
                _selectedCategory = null;
              }),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: Colors.white),
              decoration: InputDecoration(
                hintText: '0.00',
                prefixText: 'S/ ',
                prefixStyle: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: _type == 'income'
                      ? AppColors.income
                      : AppColors.expense,
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (accounts.isNotEmpty)
              DropdownButtonFormField<Account>(
                initialValue: _selectedAccount,
                dropdownColor: AppColors.surface,
                decoration: const InputDecoration(labelText: 'Cuenta'),
                items: accounts
                    .map((a) => DropdownMenuItem(
                          value: a,
                          child: Text(a.name,
                              style:
                                  const TextStyle(color: Colors.white)),
                        ))
                    .toList(),
                onChanged: (a) => setState(() => _selectedAccount = a),
              ),
            const SizedBox(height: 12),
            if (_type != 'transfer' && categories.isNotEmpty)
              DropdownButtonFormField<Category>(
                initialValue: _selectedCategory,
                dropdownColor: AppColors.surface,
                decoration: const InputDecoration(labelText: 'Categoría'),
                items: categories
                    .map((c) => DropdownMenuItem(
                          value: c,
                          child: Text(c.name,
                              style:
                                  const TextStyle(color: Colors.white)),
                        ))
                    .toList(),
                onChanged: (c) =>
                    setState(() => _selectedCategory = c),
              ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined,
                        color: AppColors.textMuted, size: 18),
                    const SizedBox(width: 10),
                    Text(
                      '${_date.day}/${_date.month}/${_date.year}',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteController,
              decoration: const InputDecoration(
                hintText: 'Nota (opcional)',
                prefixIcon: Icon(Icons.notes_outlined,
                    color: AppColors.textMuted),
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
                    : const Text('Guardar cambios'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Eliminar transacción'),
        content: const Text('¿Seguro que quieres eliminar este movimiento?'),
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
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirm == true && context.mounted) {
      final db = ref.read(databaseProvider);
      await db.transactionDao.deleteTransaction(widget.transaction.id);
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
    }
  }
}

class _TypeSelector extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const _TypeSelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _Tab('Gasto', 'expense', selected, AppColors.expense, onChanged),
          _Tab('Ingreso', 'income', selected, AppColors.income, onChanged),
          _Tab('Transfer.', 'transfer', selected, AppColors.primaryLight,
              onChanged),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final String value;
  final String selected;
  final Color color;
  final ValueChanged<String> onChanged;

  const _Tab(this.label, this.value, this.selected, this.color, this.onChanged);

  @override
  Widget build(BuildContext context) {
    final isSelected = selected == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => onChanged(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withValues(alpha: 0.2)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: isSelected ? Border.all(color: color) : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? color : AppColors.textMuted,
              fontWeight:
                  isSelected ? FontWeight.w600 : FontWeight.w400,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

