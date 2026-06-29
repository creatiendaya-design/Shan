import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../app/theme/app_colors.dart';
import '../../data/local/app_database.dart';
import '../../shared/providers/database_provider.dart';

final _debtsProvider = StreamProvider.autoDispose<List<Debt>>((ref) {
  return ref.watch(databaseProvider).debtDao.watchAll();
});

class DebtsScreen extends ConsumerWidget {
  const DebtsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final debtsAsync = ref.watch(_debtsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Deudas', style: Theme.of(context).textTheme.headlineMedium),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () => _showForm(context, ref, null),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: debtsAsync.when(
        data: (debts) {
          if (debts.isEmpty) {
            return _EmptyState(
              onAdd: () => _showForm(context, ref, null),
            );
          }

          final owedToMe = debts.where((d) => d.direction == 'owed_to_me').toList();
          final iOwe = debts.where((d) => d.direction == 'i_owe').toList();
          final totalOwedToMe = owedToMe.where((d) => !d.paid).fold<int>(0, (s, d) => s + d.amountCents);
          final totalIOwe = iOwe.where((d) => !d.paid).fold<int>(0, (s, d) => s + d.amountCents);

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
            children: [
              _SummaryRow(owedToMe: totalOwedToMe, iOwe: totalIOwe),
              const SizedBox(height: 20),
              if (owedToMe.isNotEmpty) ...[
                _SectionHeader(label: 'Me deben', color: AppColors.income),
                const SizedBox(height: 8),
                _DebtGroup(debts: owedToMe, ref: ref),
                const SizedBox(height: 20),
              ],
              if (iOwe.isNotEmpty) ...[
                _SectionHeader(label: 'Yo debo', color: AppColors.expense),
                const SizedBox(height: 8),
                _DebtGroup(debts: iOwe, ref: ref),
              ],
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, st) => const SizedBox(),
      ),
    );
  }

  void _showForm(BuildContext context, WidgetRef ref, Debt? debt) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DebtFormSheet(debt: debt),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final int owedToMe;
  final int iOwe;
  const _SummaryRow({required this.owedToMe, required this.iOwe});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _SummaryCard(label: 'Me deben', cents: owedToMe, color: AppColors.income)),
        const SizedBox(width: 12),
        Expanded(child: _SummaryCard(label: 'Yo debo', cents: iOwe, color: AppColors.expense)),
      ],
    );
  }
}


class _SummaryCard extends StatelessWidget {
  final String label;
  final int cents;
  final Color color;
  const _SummaryCard({required this.label, required this.cents, required this.color});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(symbol: 'S/ ', decimalDigits: 2);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 6),
          Text(fmt.format(cents / 100),
              style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final Color color;
  const _SectionHeader({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Text(label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(color: color));
  }
}

class _DebtGroup extends ConsumerWidget {
  final List<Debt> debts;
  final WidgetRef ref;
  const _DebtGroup({required this.debts, required this.ref});

  @override
  Widget build(BuildContext context, WidgetRef widgetRef) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: debts.asMap().entries.map((e) {
          final i = e.key;
          final debt = e.value;
          return Column(
            children: [
              _DebtTile(debt: debt),
              if (i < debts.length - 1)
                const Divider(height: 1, indent: 56, color: AppColors.border),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _DebtTile extends ConsumerWidget {
  final Debt debt;
  const _DebtTile({required this.debt});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = NumberFormat.currency(symbol: 'S/ ', decimalDigits: 2);
    final color = debt.direction == 'owed_to_me' ? AppColors.income : AppColors.expense;

    return ListTile(
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _DebtFormSheet(debt: debt),
      ),
      leading: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          debt.direction == 'owed_to_me' ? Icons.arrow_downward : Icons.arrow_upward,
          color: color, size: 18,
        ),
      ),
      title: Row(
        children: [
          Expanded(child: Text(debt.name, style: Theme.of(context).textTheme.bodyLarge)),
          if (debt.paid)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.income.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text('Pagada',
                  style: TextStyle(color: AppColors.income, fontSize: 11)),
            ),
        ],
      ),
      subtitle: debt.note != null
          ? Text(debt.note!, style: Theme.of(context).textTheme.labelSmall)
          : null,
      trailing: Text(
        fmt.format(debt.amountCents / 100),
        style: TextStyle(
          color: debt.paid ? AppColors.textMuted : color,
          fontWeight: FontWeight.w700,
          fontSize: 15,
          decoration: debt.paid ? TextDecoration.lineThrough : null,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.handshake_outlined, size: 64, color: AppColors.textMuted),
          const SizedBox(height: 16),
          Text('Sin deudas registradas',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.textMuted)),
          const SizedBox(height: 8),
          Text('Toca + para agregar una deuda',
              style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

// ── Formulario ────────────────────────────────────────────────────────────────

class _DebtFormSheet extends ConsumerStatefulWidget {
  final Debt? debt;
  const _DebtFormSheet({this.debt});

  @override
  ConsumerState<_DebtFormSheet> createState() => _DebtFormSheetState();
}

class _DebtFormSheetState extends ConsumerState<_DebtFormSheet> {
  late TextEditingController _nameCtrl;
  late TextEditingController _amountCtrl;
  late TextEditingController _noteCtrl;
  late String _direction;
  bool _paid = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.debt?.name ?? '');
    _amountCtrl = TextEditingController(
        text: widget.debt != null ? (widget.debt!.amountCents / 100).toStringAsFixed(2) : '');
    _noteCtrl = TextEditingController(text: widget.debt?.note ?? '');
    _direction = widget.debt?.direction ?? 'i_owe';
    _paid = widget.debt?.paid ?? false;
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _amountCtrl.dispose(); _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final amount = double.tryParse(_amountCtrl.text.trim().replaceAll(',', '.'));
    if (name.isEmpty || amount == null || amount <= 0) return;

    setState(() => _saving = true);
    final db = ref.read(databaseProvider);
    final now = DateTime.now().millisecondsSinceEpoch;
    final companion = DebtsCompanion(
      id: Value(widget.debt?.id ?? const Uuid().v4()),
      name: Value(name),
      direction: Value(_direction),
      amountCents: Value((amount * 100).round()),
      note: Value(_noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim()),
      paid: Value(_paid),
      createdAt: Value(widget.debt?.createdAt ?? now),
    );

    if (widget.debt == null) {
      await db.debtDao.insertDebt(companion);
    } else {
      await db.debtDao.updateDebt(companion);
    }
    if (mounted) Navigator.of(context, rootNavigator: true).pop();
  }

  Future<void> _delete() async {
    final db = ref.read(databaseProvider);
    await db.debtDao.deleteDebt(widget.debt!.id);
    if (mounted) Navigator.of(context, rootNavigator: true).pop();
  }

  @override
  Widget build(BuildContext context) {
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
                Text(widget.debt == null ? 'Nueva deuda' : 'Editar deuda',
                    style: Theme.of(context).textTheme.titleLarge),
                if (widget.debt != null)
                  TextButton(onPressed: _delete,
                      child: const Text('Eliminar', style: TextStyle(color: AppColors.expense))),
              ],
            ),
            const SizedBox(height: 20),
            // Dirección
            Container(
              decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                _DirTab('Yo debo', 'i_owe', _direction, AppColors.expense, (v) => setState(() => _direction = v)),
                _DirTab('Me deben', 'owed_to_me', _direction, AppColors.income, (v) => setState(() => _direction = v)),
              ]),
            ),
            const SizedBox(height: 16),
            TextField(controller: _nameCtrl,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Nombre / Persona')),
            const SizedBox(height: 12),
            TextField(controller: _amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Monto', prefixText: 'S/ ')),
            const SizedBox(height: 12),
            TextField(controller: _noteCtrl,
                decoration: const InputDecoration(hintText: 'Nota (opcional)',
                    prefixIcon: Icon(Icons.notes_outlined, color: AppColors.textMuted))),
            const SizedBox(height: 12),
            if (widget.debt != null)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Marcar como pagada'),
                value: _paid,
                activeThumbColor: AppColors.income,
                onChanged: (v) => setState(() => _paid = v),
              ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: Text(widget.debt == null ? 'Guardar' : 'Actualizar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DirTab extends StatelessWidget {
  final String label, value, selected;
  final Color color;
  final ValueChanged<String> onChanged;
  const _DirTab(this.label, this.value, this.selected, this.color, this.onChanged);

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
              style: TextStyle(color: sel ? color : AppColors.textMuted,
                  fontWeight: sel ? FontWeight.w600 : FontWeight.w400, fontSize: 13)),
        ),
      ),
    );
  }
}

