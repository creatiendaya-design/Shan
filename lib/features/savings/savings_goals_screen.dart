import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../app/theme/app_colors.dart';
import '../../data/local/app_database.dart';
import '../../shared/providers/database_provider.dart';

final _goalsProvider = StreamProvider.autoDispose<List<SavingsGoal>>((ref) {
  return ref.watch(databaseProvider).savingsGoalDao.watchAll();
});

const _goalEmojis = ['🎯', '🏠', '✈️', '🚗', '💍', '📱', '🎓', '💪', '🌴', '🎁'];

class SavingsGoalsScreen extends ConsumerWidget {
  const SavingsGoalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalsAsync = ref.watch(_goalsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Metas de ahorro', style: Theme.of(context).textTheme.headlineMedium),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () => _showForm(context, null),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: goalsAsync.when(
        data: (goals) {
          if (goals.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('🎯', style: TextStyle(fontSize: 64)),
                  const SizedBox(height: 16),
                  Text('Sin metas de ahorro',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.textMuted)),
                  const SizedBox(height: 8),
                  Text('Toca + para crear una meta',
                      style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
            children: goals.map((g) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _GoalCard(
                goal: g,
                onTap: () => _showForm(context, g),
                onDeposit: () => _showDeposit(context, ref, g),
              ),
            )).toList(),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, st) => const SizedBox(),
      ),
    );
  }

  void _showForm(BuildContext context, SavingsGoal? goal) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _GoalFormSheet(goal: goal),
    );
  }

  void _showDeposit(BuildContext context, WidgetRef ref, SavingsGoal goal) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DepositSheet(goal: goal),
    );
  }
}

class _GoalCard extends StatelessWidget {
  final SavingsGoal goal;
  final VoidCallback onTap;
  final VoidCallback onDeposit;
  const _GoalCard({required this.goal, required this.onTap, required this.onDeposit});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(symbol: 'S/ ', decimalDigits: 0);
    final progress = goal.targetCents > 0
        ? (goal.savedCents / goal.targetCents).clamp(0.0, 1.0)
        : 0.0;
    final remaining = goal.targetCents - goal.savedCents;
    final completed = goal.savedCents >= goal.targetCents;
    final progressColor = completed ? AppColors.income : AppColors.primary;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: completed ? AppColors.income.withValues(alpha: 0.4) : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(goal.emoji, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(goal.name, style: Theme.of(context).textTheme.titleMedium),
                    if (completed)
                      const Text('¡Meta alcanzada! 🎉',
                          style: TextStyle(color: AppColors.income, fontSize: 12)),
                  ],
                ),
              ),
              if (!completed)
                GestureDetector(
                  onTap: onDeposit,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                    ),
                    child: const Text('+ Abonar',
                        style: TextStyle(color: AppColors.primaryLight, fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(fmt.format(goal.savedCents / 100),
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
              Text('/ ${fmt.format(goal.targetCents / 100)}',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: AppColors.surfaceVariant,
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                completed ? 'Completado' : 'Faltan ${fmt.format(remaining / 100)}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: completed ? AppColors.income : AppColors.textMuted,
                ),
              ),
              Text('${(progress * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                      color: progressColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: onTap,
            child: Text('Editar meta',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.textMuted,
                    decoration: TextDecoration.underline)),
          ),
        ],
      ),
    );
  }
}

// ── Formulario meta ───────────────────────────────────────────────────────────

class _GoalFormSheet extends ConsumerStatefulWidget {
  final SavingsGoal? goal;
  const _GoalFormSheet({this.goal});

  @override
  ConsumerState<_GoalFormSheet> createState() => _GoalFormSheetState();
}

class _GoalFormSheetState extends ConsumerState<_GoalFormSheet> {
  late TextEditingController _nameCtrl;
  late TextEditingController _targetCtrl;
  late String _emoji;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.goal?.name ?? '');
    _targetCtrl = TextEditingController(
        text: widget.goal != null ? (widget.goal!.targetCents / 100).toStringAsFixed(0) : '');
    _emoji = widget.goal?.emoji ?? '🎯';
  }

  @override
  void dispose() { _nameCtrl.dispose(); _targetCtrl.dispose(); super.dispose(); }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final target = double.tryParse(_targetCtrl.text.trim().replaceAll(',', '.'));
    if (name.isEmpty || target == null || target <= 0) return;

    setState(() => _saving = true);
    final db = ref.read(databaseProvider);
    final now = DateTime.now().millisecondsSinceEpoch;
    final companion = SavingsGoalsCompanion(
      id: Value(widget.goal?.id ?? const Uuid().v4()),
      name: Value(name),
      targetCents: Value((target * 100).round()),
      savedCents: Value(widget.goal?.savedCents ?? 0),
      emoji: Value(_emoji),
      createdAt: Value(widget.goal?.createdAt ?? now),
    );

    if (widget.goal == null) {
      await db.savingsGoalDao.insert(companion); // insert is fine, no collision
    } else {
      await db.savingsGoalDao.updateGoal(companion);
    }
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
                Text(widget.goal == null ? 'Nueva meta' : 'Editar meta',
                    style: Theme.of(context).textTheme.titleLarge),
                if (widget.goal != null)
                  TextButton(
                    onPressed: () async {
                      final db = ref.read(databaseProvider);
                      final id = widget.goal!.id;
                      final nav = Navigator.of(context);
                      await db.savingsGoalDao.deleteGoal(id);
                      if (!mounted) return;
                      nav.pop();
                    },
                    child: const Text('Eliminar', style: TextStyle(color: AppColors.expense)),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Ícono', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppColors.textMuted)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: _goalEmojis.map((e) => GestureDetector(
                onTap: () => setState(() => _emoji = e),
                child: Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: _emoji == e ? AppColors.primary.withValues(alpha: 0.2) : AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _emoji == e ? AppColors.primary : AppColors.border),
                  ),
                  child: Center(child: Text(e, style: const TextStyle(fontSize: 22))),
                ),
              )).toList(),
            ),
            const SizedBox(height: 16),
            TextField(controller: _nameCtrl,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Nombre de la meta')),
            const SizedBox(height: 12),
            TextField(controller: _targetCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Monto objetivo', prefixText: 'S/ ')),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: Text(widget.goal == null ? 'Crear meta' : 'Actualizar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Abonar a meta ─────────────────────────────────────────────────────────────

class _DepositSheet extends ConsumerStatefulWidget {
  final SavingsGoal goal;
  const _DepositSheet({required this.goal});

  @override
  ConsumerState<_DepositSheet> createState() => _DepositSheetState();
}

class _DepositSheetState extends ConsumerState<_DepositSheet> {
  final _ctrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _save() async {
    final amount = double.tryParse(_ctrl.text.trim().replaceAll(',', '.'));
    if (amount == null || amount <= 0) return;
    setState(() => _saving = true);
    final db = ref.read(databaseProvider);
    await db.savingsGoalDao.updateGoal(SavingsGoalsCompanion(
      id: Value(widget.goal.id),
      savedCents: Value(widget.goal.savedCents + (amount * 100).round()),
    ));
    if (mounted) Navigator.of(context, rootNavigator: true).pop();
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(symbol: 'S/ ', decimalDigits: 0);
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Container(width: 40, height: 4,
              decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),
          Text('Abonar a "${widget.goal.name}"',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text('Ahorrado: ${fmt.format(widget.goal.savedCents / 100)} / ${fmt.format(widget.goal.targetCents / 100)}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted)),
          const SizedBox(height: 20),
          TextField(
            controller: _ctrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: Colors.white),
            decoration: const InputDecoration(hintText: '0', prefixText: 'S/ '),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              child: const Text('Abonar'),
            ),
          ),
        ],
      ),
    );
  }
}

