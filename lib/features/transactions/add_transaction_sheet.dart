import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../app/theme/app_colors.dart';
import '../../data/local/app_database.dart';
import '../../shared/providers/database_provider.dart';
import '../../shared/providers/transaction_providers.dart';
import '../ocr/ocr_service.dart';
import '../streak/streak_service.dart';
import '../../shared/utils/amount_parser.dart';

const _uuid = Uuid();

class AddTransactionSheet extends ConsumerStatefulWidget {
  const AddTransactionSheet({super.key});

  @override
  ConsumerState<AddTransactionSheet> createState() =>
      _AddTransactionSheetState();
}

class _AddTransactionSheetState extends ConsumerState<AddTransactionSheet> {
  String _type = 'expense';
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  Category? _selectedCategory;
  Account? _selectedAccount;
  DateTime _date = DateTime.now();
  TimeOfDay _time = TimeOfDay.now();
  bool _saving = false;
  bool _scanning = false;
  double? _exprResult;

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amountText = _amountController.text.trim();
    final amount = parseAmountExpression(amountText);

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

    await db.transactionDao.insertTransaction(TransactionsCompanion(
      id: Value(_uuid.v4()),
      type: Value(_type),
      amountCents: Value((amount * 100).round()),
      accountId: Value(_selectedAccount!.id),
      categoryId: Value(_selectedCategory?.id),
      date: Value(DateTime(
        _date.year, _date.month, _date.day, _time.hour, _time.minute,
      ).millisecondsSinceEpoch),
      note: Value(
          _noteController.text.trim().isEmpty ? null : _noteController.text.trim()),
      createdAt: Value(now),
      updatedAt: Value(now),
    ));

    await StreakService.recordActivity();
    if (mounted) Navigator.of(context).pop();
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: AppColors.expense));
  }

  Future<void> _scanVoucher(bool fromCamera) async {
    setState(() => _scanning = true);
    OcrResult? result;
    try {
      result = fromCamera
          ? await OcrService.scanFromCamera()
          : await OcrService.scanFromGallery();
    } catch (e) {
      if (mounted) _showError('Error al escanear. Intenta de nuevo.');
      if (mounted) setState(() => _scanning = false);
      return;
    }
    if (mounted) setState(() => _scanning = false);
    if (result == null || !mounted) return;

    final amount = result.suggestedAmount;
    final dt = result.suggestedDateTime;

    if (amount == null && dt == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se detectó información. Ingrésala manualmente.'),
          backgroundColor: AppColors.surfaceVariant,
        ),
      );
      return;
    }

    // Only apply OCR date if it's within the last 30 days — old receipts keep today's date
    final now = DateTime.now();
    final recentDt = dt != null && now.difference(dt).inDays <= 30 && dt.isBefore(now) ? dt : null;

    setState(() {
      if (amount != null) _amountController.text = amount.toStringAsFixed(2);
      if (recentDt != null) {
        _date = recentDt;
        _time = TimeOfDay(hour: recentDt.hour, minute: recentDt.minute);
      }
    });

    final parts = <String>[];
    if (amount != null) parts.add('S/ ${amount.toStringAsFixed(2)}');
    if (recentDt != null) {
      final h = recentDt.hour.toString().padLeft(2, '0');
      final m = recentDt.minute.toString().padLeft(2, '0');
      parts.add('${recentDt.day}/${recentDt.month}/${recentDt.year} $h:$m');
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Detectado: ${parts.join(' · ')}'),
          backgroundColor: AppColors.income,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _time = picked);
  }

  void _showScanOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Escanear baucher',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.camera_alt_outlined,
                      color: AppColors.primary),
                ),
                title: const Text('Tomar foto'),
                subtitle: const Text('Abre la cámara'),
                onTap: () {
                  Navigator.of(context).pop();
                  _scanVoucher(true);
                },
              ),
              ListTile(
                leading: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.photo_library_outlined,
                      color: AppColors.primary),
                ),
                title: const Text('Elegir de galería'),
                subtitle: const Text('Selecciona una foto existente'),
                onTap: () {
                  Navigator.of(context).pop();
                  _scanVoucher(false);
                },
              ),
            ],
          ),
        ),
      ),
    );
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
            // Handle bar
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
                Text('Nueva transacción',
                    style: Theme.of(context).textTheme.titleLarge),
                GestureDetector(
                  onTap: _scanning ? null : _showScanOptions,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                    ),
                    child: _scanning
                        ? const SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(
                                color: AppColors.primaryLight, strokeWidth: 2))
                        : const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.document_scanner_outlined,
                                  color: AppColors.primaryLight, size: 16),
                              SizedBox(width: 6),
                              Text('Baucher',
                                  style: TextStyle(
                                      color: AppColors.primaryLight,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500)),
                            ],
                          ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Tipo
            _TypeSelector(
              selected: _type,
              onChanged: (t) => setState(() {
                _type = t;
                _selectedCategory = null;
              }),
            ),
            const SizedBox(height: 16),

            // Monto
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(
                  fontSize: 28, fontWeight: FontWeight.w700, color: Colors.white),
              decoration: InputDecoration(
                hintText: '0.00',
                prefixText: 'S/ ',
                prefixStyle: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: _type == 'income' ? AppColors.income : AppColors.expense),
                helperText: _exprResult != null
                    ? '= S/ ${_exprResult!.toStringAsFixed(2)}'
                    : null,
                helperStyle: TextStyle(
                    color: _type == 'income' ? AppColors.income : AppColors.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14),
              ),
              onChanged: (v) {
                if (isExpression(v)) {
                  setState(() => _exprResult = parseAmountExpression(v));
                } else {
                  setState(() => _exprResult = null);
                }
              },
            ),
            const SizedBox(height: 16),

            // Cuenta
            if (accounts.isEmpty)
              _NoAccountBanner(onAdd: () => _showAddAccountDialog(context))
            else
              _DropdownField<Account>(
                label: 'Cuenta',
                value: _selectedAccount,
                items: accounts,
                itemLabel: (a) => a.name,
                onChanged: (a) => setState(() => _selectedAccount = a),
              ),
            const SizedBox(height: 12),

            // Categoría
            if (_type != 'transfer')
              _DropdownField<Category>(
                label: 'Categoría',
                value: _selectedCategory,
                items: categories,
                itemLabel: (c) => c.name,
                onChanged: (c) => setState(() => _selectedCategory = c),
              ),
            if (_type != 'transfer') const SizedBox(height: 12),

            // Fecha y hora
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _pickDate,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today_outlined,
                              color: AppColors.textMuted, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            '${_date.day.toString().padLeft(2, '0')}/${_date.month.toString().padLeft(2, '0')}/${_date.year}',
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: _pickTime,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.access_time_outlined,
                            color: AppColors.textMuted, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Nota
            TextField(
              controller: _noteController,
              decoration: const InputDecoration(
                hintText: 'Nota (opcional)',
                prefixIcon: Icon(Icons.notes_outlined, color: AppColors.textMuted),
              ),
            ),
            const SizedBox(height: 24),

            // Guardar
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 20, width: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text('Guardar'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddAccountDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => const _AddAccountDialog(),
    );
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
          _Tab('Transfer.', 'transfer', selected, AppColors.primaryLight, onChanged),
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
            color: isSelected ? color.withValues(alpha: 0.2) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: isSelected ? Border.all(color: color) : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? color : AppColors.textMuted,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

class _DropdownField<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<T> items;
  final String Function(T) itemLabel;
  final ValueChanged<T?> onChanged;

  const _DropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      dropdownColor: AppColors.surface,
      decoration: InputDecoration(labelText: label),
      items: items
          .map((i) => DropdownMenuItem(
                value: i,
                child: Text(itemLabel(i),
                    style: const TextStyle(color: Colors.white)),
              ))
          .toList(),
      onChanged: onChanged,
    );
  }
}

class _NoAccountBanner extends StatelessWidget {
  final VoidCallback onAdd;
  const _NoAccountBanner({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AppColors.primaryLight, size: 18),
          const SizedBox(width: 10),
          const Expanded(
            child: Text('Necesitas al menos una cuenta',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          ),
          TextButton(
            onPressed: onAdd,
            child: const Text('Agregar',
                style: TextStyle(color: AppColors.primaryLight)),
          ),
        ],
      ),
    );
  }
}

class _AddAccountDialog extends ConsumerStatefulWidget {
  const _AddAccountDialog();

  @override
  ConsumerState<_AddAccountDialog> createState() => _AddAccountDialogState();
}

class _AddAccountDialogState extends ConsumerState<_AddAccountDialog> {
  final _nameController = TextEditingController();
  String _type = 'cash';

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    final db = ref.read(databaseProvider);
    await db.accountDao.insertAccount(AccountsCompanion(
      id: Value(_uuid.v4()),
      name: Value(name),
      type: Value(_type),
      createdAt: Value(DateTime.now().millisecondsSinceEpoch),
    ));
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text('Nueva cuenta'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(hintText: 'Ej: BBVA, Efectivo...'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _type,
            dropdownColor: AppColors.surface,
            decoration: const InputDecoration(labelText: 'Tipo'),
            items: const [
              DropdownMenuItem(value: 'cash', child: Text('Efectivo')),
              DropdownMenuItem(value: 'bank', child: Text('Banco')),
              DropdownMenuItem(value: 'savings', child: Text('Ahorros')),
              DropdownMenuItem(value: 'credit', child: Text('Tarjeta de crédito')),
              DropdownMenuItem(value: 'wallet', child: Text('Billetera digital')),
            ],
            onChanged: (v) => setState(() => _type = v!),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar',
                style: TextStyle(color: AppColors.textMuted))),
        ElevatedButton(onPressed: _save, child: const Text('Guardar')),
      ],
    );
  }
}
