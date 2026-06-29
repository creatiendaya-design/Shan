import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../notifications/notification_service.dart';
import '../../app/theme/app_colors.dart';
import '../../data/local/app_database.dart';
import '../../shared/providers/database_provider.dart';
import '../../shared/providers/transaction_providers.dart';
import 'recurring_service.dart';

final _recurringProvider = StreamProvider.autoDispose<List<RecurringTransaction>>((ref) {
  return ref.watch(databaseProvider).recurringTransactionDao.watchAll();
});

const _frequencies = [
  ('daily',   'Diario',   Icons.today_outlined),
  ('weekly',  'Semanal',  Icons.view_week_outlined),
  ('monthly', 'Mensual',  Icons.calendar_month_outlined),
  ('yearly',  'Anual',    Icons.event_repeat_outlined),
];

String _freqLabel(String f) =>
    _frequencies.firstWhere((e) => e.$1 == f, orElse: () => _frequencies[2]).$2;

IconData _freqIcon(String f) =>
    _frequencies.firstWhere((e) => e.$1 == f, orElse: () => _frequencies[2]).$3;

class RecurringScreen extends ConsumerStatefulWidget {
  const RecurringScreen({super.key});

  @override
  ConsumerState<RecurringScreen> createState() => _RecurringScreenState();
}

class _RecurringScreenState extends ConsumerState<RecurringScreen> {
  @override
  void initState() {
    super.initState();
    // Process overdue recurring transactions when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) => _processdue());
  }

  Future<void> _processdue() async {
    final db = ref.read(databaseProvider);
    final count = await applyDueRecurring(db);
    if (count > 0 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$count transacción${count > 1 ? 'es' : ''} recurrente${count > 1 ? 's' : ''} aplicada${count > 1 ? 's' : ''}'),
          backgroundColor: AppColors.income,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final listAsync = ref.watch(_recurringProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Recurrentes', style: Theme.of(context).textTheme.headlineMedium),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync, color: AppColors.primaryLight),
            tooltip: 'Aplicar pendientes',
            onPressed: _processdue,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () => _showForm(context, null),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: listAsync.when(
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.event_repeat_outlined,
                      size: 64, color: AppColors.textMuted),
                  const SizedBox(height: 16),
                  Text('Sin transacciones recurrentes',
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(color: AppColors.textMuted)),
                  const SizedBox(height: 8),
                  Text('Toca + para agregar (salario, Netflix, alquiler…)',
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center),
                ],
              ),
            );
          }

          final active = items.where((r) => r.active).toList();
          final paused = items.where((r) => !r.active).toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
            children: [
              if (active.isNotEmpty) ...[
                _SectionLabel(label: 'Activas'),
                const SizedBox(height: 8),
                _RecurringGroup(items: active, onTap: (r) => _showForm(context, r)),
                const SizedBox(height: 20),
              ],
              if (paused.isNotEmpty) ...[
                _SectionLabel(label: 'Pausadas'),
                const SizedBox(height: 8),
                _RecurringGroup(items: paused, onTap: (r) => _showForm(context, r)),
              ],
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => const SizedBox(),
      ),
    );
  }

  void _showForm(BuildContext context, RecurringTransaction? item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RecurringFormSheet(item: item),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) => Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AppColors.textMuted),
      );
}

class _RecurringGroup extends ConsumerWidget {
  final List<RecurringTransaction> items;
  final void Function(RecurringTransaction) onTap;
  const _RecurringGroup({required this.items, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = NumberFormat.currency(symbol: 'S/ ', decimalDigits: 2);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: items.asMap().entries.map((e) {
          final i = e.key;
          final r = e.value;
          final isIncome = r.type == 'income';
          final color = isIncome ? AppColors.income : AppColors.expense;
          final dueDate = DateTime.fromMillisecondsSinceEpoch(r.nextDueDateMs);
          final isOverdue = dueDate.isBefore(DateTime.now());

          return Column(
            children: [
              InkWell(
                onTap: () => onTap(r),
                borderRadius: i == 0
                    ? const BorderRadius.vertical(top: Radius.circular(16))
                    : i == items.length - 1
                        ? const BorderRadius.vertical(bottom: Radius.circular(16))
                        : BorderRadius.zero,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(_freqIcon(r.frequency), color: color, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(r.name, style: Theme.of(context).textTheme.bodyLarge),
                            const SizedBox(height: 2),
                            Row(children: [
                              Text(_freqLabel(r.frequency),
                                  style: Theme.of(context).textTheme.labelSmall),
                              Text('  ·  ',
                                  style: Theme.of(context).textTheme.labelSmall),
                              Text(
                                isOverdue ? 'Vencida' : 'Próx: ${DateFormat('dd/MM/yy').format(dueDate)}',
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: isOverdue ? AppColors.expense : AppColors.textMuted),
                              ),
                            ]),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            fmt.format(r.amountCents / 100),
                            style: TextStyle(
                                color: color, fontWeight: FontWeight.w700, fontSize: 14),
                          ),
                          Transform.scale(
                            scale: 0.8,
                            child: Switch(
                              value: r.active,
                              activeThumbColor: AppColors.income,
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              onChanged: (v) {
                                ref.read(databaseProvider).recurringTransactionDao.updateRecurring(
                                  RecurringTransactionsCompanion(
                                    id: Value(r.id),
                                    active: Value(v),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (i < items.length - 1)
                const Divider(height: 1, indent: 56, color: AppColors.border),
            ],
          );
        }).toList(),
      ),
    );
  }
}

// ── Form ──────────────────────────────────────────────────────────────────────

class _RecurringFormSheet extends ConsumerStatefulWidget {
  final RecurringTransaction? item;
  const _RecurringFormSheet({this.item});

  @override
  ConsumerState<_RecurringFormSheet> createState() => _RecurringFormSheetState();
}

class _RecurringFormSheetState extends ConsumerState<_RecurringFormSheet> {
  late TextEditingController _nameCtrl;
  late TextEditingController _amountCtrl;
  late TextEditingController _noteCtrl;
  late String _type;
  late String _frequency;
  late DateTime _startDate;
  Account? _account;
  Category? _category;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final r = widget.item;
    _nameCtrl = TextEditingController(text: r?.name ?? '');
    _amountCtrl = TextEditingController(
        text: r != null ? (r.amountCents / 100).toStringAsFixed(2) : '');
    _noteCtrl = TextEditingController(text: r?.note ?? '');
    _type = r?.type ?? 'expense';
    _frequency = r?.frequency ?? 'monthly';
    _startDate = r != null
        ? DateTime.fromMillisecondsSinceEpoch(r.nextDueDateMs)
        : DateTime.now();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final amount = double.tryParse(_amountCtrl.text.trim().replaceAll(',', '.'));
    if (name.isEmpty || amount == null || amount <= 0) return;
    if (_account == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona una cuenta'), backgroundColor: AppColors.expense));
      return;
    }

    setState(() => _saving = true);
    final db = ref.read(databaseProvider);
    final now = DateTime.now().millisecondsSinceEpoch;

    final companion = RecurringTransactionsCompanion(
      id: Value(widget.item?.id ?? const Uuid().v4()),
      name: Value(name),
      type: Value(_type),
      amountCents: Value((amount * 100).round()),
      accountId: Value(_account!.id),
      categoryId: Value(_category?.id),
      frequency: Value(_frequency),
      nextDueDateMs: Value(_startDate.millisecondsSinceEpoch),
      note: Value(_noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim()),
      active: const Value(true),
      createdAt: Value(widget.item?.createdAt ?? now),
    );

    if (widget.item == null) {
      await db.recurringTransactionDao.insertRecurring(companion);
    } else {
      await db.recurringTransactionDao.updateRecurring(companion);
    }
    final all = await db.recurringTransactionDao.watchAll().first;
    await rescheduleRecurringNotifications(all);
    if (mounted) Navigator.of(context, rootNavigator: true).pop();
  }

  Future<void> _delete() async {
    final db = ref.read(databaseProvider);
    final nav = Navigator.of(context);
    await db.recurringTransactionDao.deleteRecurring(widget.item!.id);
    final all = await db.recurringTransactionDao.watchAll().first;
    await rescheduleRecurringNotifications(all);
    if (mounted) nav.pop();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(accountsProvider).valueOrNull ?? [];
    final categories = ref.watch(
      _type == 'expense' ? expenseCategoriesProvider : incomeCategoriesProvider,
    ).valueOrNull ?? [];

    // Auto-select first account if not set
    if (_account == null && accounts.isNotEmpty) {
      _account = accounts.first;
    }

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(widget.item == null ? 'Nueva recurrente' : 'Editar recurrente',
                    style: Theme.of(context).textTheme.titleLarge),
                if (widget.item != null)
                  TextButton(
                    onPressed: _delete,
                    child: const Text('Eliminar', style: TextStyle(color: AppColors.expense)),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Tipo
            Container(
              decoration: BoxDecoration(
                  color: AppColors.surfaceVariant, borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                _TypeTab('Gasto', 'expense', _type, AppColors.expense,
                    (v) => setState(() { _type = v; _category = null; })),
                _TypeTab('Ingreso', 'income', _type, AppColors.income,
                    (v) => setState(() { _type = v; _category = null; })),
              ]),
            ),
            const SizedBox(height: 16),

            // Monto
            TextField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white),
              decoration: InputDecoration(
                hintText: '0.00',
                prefixText: 'S/ ',
                prefixStyle: TextStyle(
                    fontSize: 24, fontWeight: FontWeight.w700,
                    color: _type == 'income' ? AppColors.income : AppColors.expense),
              ),
            ),
            const SizedBox(height: 12),

            // Nombre
            TextField(
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Descripción (ej: Netflix, Alquiler)'),
            ),
            const SizedBox(height: 12),

            // Frecuencia
            Text('Frecuencia', style: Theme.of(context).textTheme.labelMedium
                ?.copyWith(color: AppColors.textMuted)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: _frequencies.map((f) {
                final sel = _frequency == f.$1;
                return GestureDetector(
                  onTap: () => setState(() => _frequency = f.$1),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: sel ? AppColors.primary.withValues(alpha: 0.15) : AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: sel ? AppColors.primary : AppColors.border),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(f.$3, size: 14, color: sel ? AppColors.primary : AppColors.textMuted),
                      const SizedBox(width: 6),
                      Text(f.$2, style: TextStyle(
                          color: sel ? AppColors.primary : AppColors.textSecondary,
                          fontSize: 13, fontWeight: sel ? FontWeight.w600 : FontWeight.w400)),
                    ]),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),

            // Próxima fecha
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(children: [
                  const Icon(Icons.calendar_today_outlined,
                      color: AppColors.textMuted, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Próxima: ${_startDate.day.toString().padLeft(2,'0')}/${_startDate.month.toString().padLeft(2,'0')}/${_startDate.year}',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 12),

            // Cuenta
            DropdownButtonFormField<Account>(
              initialValue: _account,
              dropdownColor: AppColors.surface,
              decoration: const InputDecoration(labelText: 'Cuenta'),
              items: accounts.map((a) => DropdownMenuItem(
                value: a,
                child: Text(a.name, style: const TextStyle(color: Colors.white)),
              )).toList(),
              onChanged: (a) => setState(() => _account = a),
            ),
            const SizedBox(height: 12),

            // Categoría
            DropdownButtonFormField<Category>(
              initialValue: _category,
              dropdownColor: AppColors.surface,
              decoration: const InputDecoration(labelText: 'Categoría (opcional)'),
              items: categories.map((c) => DropdownMenuItem(
                value: c,
                child: Text(c.name, style: const TextStyle(color: Colors.white)),
              )).toList(),
              onChanged: (c) => setState(() => _category = c),
            ),
            const SizedBox(height: 12),

            // Nota
            TextField(
              controller: _noteCtrl,
              decoration: const InputDecoration(
                hintText: 'Nota (opcional)',
                prefixIcon: Icon(Icons.notes_outlined, color: AppColors.textMuted),
              ),
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: Text(widget.item == null ? 'Guardar' : 'Actualizar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeTab extends StatelessWidget {
  final String label, value, selected;
  final Color color;
  final ValueChanged<String> onChanged;
  const _TypeTab(this.label, this.value, this.selected, this.color, this.onChanged);

  @override
  Widget build(BuildContext context) {
    final sel = selected == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => onChanged(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: sel ? color.withValues(alpha: 0.2) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: sel ? Border.all(color: color) : null,
          ),
          child: Text(label, textAlign: TextAlign.center,
              style: TextStyle(
                  color: sel ? color : AppColors.textMuted,
                  fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                  fontSize: 13)),
        ),
      ),
    );
  }
}

