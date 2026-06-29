import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../app/theme/app_colors.dart';
import '../../data/local/app_database.dart';
import '../../shared/providers/database_provider.dart';
import '../../shared/providers/transaction_providers.dart';

// Maps default icon keys to emoji for display
const _iconToEmoji = {
  'utensils': '🍽️',
  'car': '🚗',
  'heart-pulse': '💊',
  'music': '🎵',
  'shopping-bag': '🛍️',
  'home': '🏠',
  'book-open': '📚',
  'smartphone': '📱',
  'paw-print': '🐾',
  'more-horizontal': '📦',
  'briefcase': '💼',
  'laptop': '💻',
  'trending-up': '📈',
  'gift': '🎁',
  'plus-circle': '➕',
  'wallet': '👛',
};

String iconKeyToEmoji(String key) => _iconToEmoji[key] ?? key;

// Available emojis for custom categories
const _expenseEmojis = [
  '🍽️','🛒','🚗','🏠','💊','👕','📱','🎵','🐾','📚',
  '✈️','🎓','💈','⚽','🎮','🎬','☕','🍕','💄','🔧',
  '🌿','💐','🏋️','🎨','🧴','🛵','🎂','🍺','💒','🌊',
];
const _incomeEmojis = [
  '💼','💻','📈','🎁','💰','🏦','📦','🤝','🏆','⭐',
  '🎯','🔑','💡','🌟','✅','🎪','🛠️','📊','🏅','🎤',
];

const _colorOptions = [
  '#EF4444','#F59E0B','#10B981','#3B82F6','#8B5CF6',
  '#EC4899','#06B6D4','#F97316','#6366F1','#64748B',
  '#881337','#065F46','#1E3A5F','#4C1D95','#78350F',
];

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allAsync = ref.watch(categoriesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Categorías', style: Theme.of(context).textTheme.headlineMedium),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () => _showForm(context, ref, null),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: allAsync.when(
        data: (cats) {
          final expenses = cats.where((c) => c.kind == 'expense').toList();
          final incomes = cats.where((c) => c.kind == 'income').toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
            children: [
              _SectionHeader(label: 'Gastos', color: AppColors.expense),
              const SizedBox(height: 8),
              _CategoryGroup(
                categories: expenses,
                onTap: (c) => _showForm(context, ref, c),
                onDelete: (c) => _confirmDelete(context, ref, c),
              ),
              const SizedBox(height: 24),
              _SectionHeader(label: 'Ingresos', color: AppColors.income),
              const SizedBox(height: 8),
              _CategoryGroup(
                categories: incomes,
                onTap: (c) => _showForm(context, ref, c),
                onDelete: (c) => _confirmDelete(context, ref, c),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => const SizedBox(),
      ),
    );
  }

  void _showForm(BuildContext context, WidgetRef ref, Category? cat) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CategoryFormSheet(category: cat),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, Category cat) async {
    if (cat.isDefault) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Las categorías predeterminadas no se pueden eliminar'),
          backgroundColor: AppColors.surfaceVariant,
        ),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Eliminar categoría'),
        content: Text('¿Eliminar "${cat.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.expense),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(databaseProvider).categoryDao.deleteCategory(cat.id);
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final Color color;
  const _SectionHeader({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(color: color),
      );
}

class _CategoryGroup extends StatelessWidget {
  final List<Category> categories;
  final void Function(Category) onTap;
  final void Function(Category) onDelete;
  const _CategoryGroup({required this.categories, required this.onTap, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Text('Sin categorías', style: Theme.of(context).textTheme.bodyMedium),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: categories.asMap().entries.map((e) {
          final i = e.key;
          final cat = e.value;
          final color = _hexToColor(cat.colorHex);
          final emoji = iconKeyToEmoji(cat.iconKey);

          return Column(
            children: [
              ListTile(
                onTap: () => onTap(cat),
                leading: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(child: Text(emoji, style: const TextStyle(fontSize: 20))),
                ),
                title: Text(cat.name, style: Theme.of(context).textTheme.bodyLarge),
                subtitle: cat.isDefault
                    ? Text('Predeterminada',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.textMuted))
                    : null,
                trailing: cat.isDefault
                    ? const Icon(Icons.lock_outline, color: AppColors.textMuted, size: 16)
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: AppColors.expense, size: 18),
                            onPressed: () => onDelete(cat),
                          ),
                          const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 20),
                        ],
                      ),
              ),
              if (i < categories.length - 1)
                const Divider(height: 1, indent: 56, color: AppColors.border),
            ],
          );
        }).toList(),
      ),
    );
  }

  Color _hexToColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return AppColors.primary;
    }
  }
}

// ── Form sheet ────────────────────────────────────────────────────────────────

class _CategoryFormSheet extends ConsumerStatefulWidget {
  final Category? category;
  const _CategoryFormSheet({this.category});

  @override
  ConsumerState<_CategoryFormSheet> createState() => _CategoryFormSheetState();
}

class _CategoryFormSheetState extends ConsumerState<_CategoryFormSheet> {
  late TextEditingController _nameCtrl;
  late String _emoji;
  late String _colorHex;
  late String _kind;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.category?.name ?? '');
    _emoji = widget.category != null
        ? iconKeyToEmoji(widget.category!.iconKey)
        : '📦';
    _colorHex = widget.category?.colorHex ?? '#3B82F6';
    _kind = widget.category?.kind ?? 'expense';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;

    setState(() => _saving = true);
    final db = ref.read(databaseProvider);
    final now = DateTime.now().millisecondsSinceEpoch;

    final companion = CategoriesCompanion(
      id: Value(widget.category?.id ?? const Uuid().v4()),
      name: Value(name),
      kind: Value(_kind),
      iconKey: Value(_emoji),
      colorHex: Value(_colorHex),
      isDefault: const Value(false),
      sortOrder: Value(widget.category?.sortOrder ?? now),
    );

    if (widget.category == null) {
      await db.categoryDao.insertCategory(companion);
    } else {
      await db.categoryDao.updateCategory(companion);
    }
    if (mounted) Navigator.of(context, rootNavigator: true).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.category != null;
    final isDefault = widget.category?.isDefault ?? false;
    final emojis = _kind == 'expense' ? _expenseEmojis : _incomeEmojis;

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
            Center(child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppColors.border, borderRadius: BorderRadius.circular(2)),
            )),
            const SizedBox(height: 20),

            Text(isEditing ? 'Editar categoría' : 'Nueva categoría',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 20),

            // Tipo (solo al crear)
            if (!isEditing) ...[
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    _KindTab('Gasto', 'expense', _kind, AppColors.expense,
                        (v) => setState(() { _kind = v; _emoji = '📦'; })),
                    _KindTab('Ingreso', 'income', _kind, AppColors.income,
                        (v) => setState(() { _kind = v; _emoji = '💰'; })),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Emoji picker
            if (!isDefault) ...[
              Text('Ícono', style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.textMuted)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6, runSpacing: 6,
                children: emojis.map((e) => GestureDetector(
                  onTap: () => setState(() => _emoji = e),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: _emoji == e
                          ? AppColors.primary.withValues(alpha: 0.2)
                          : AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: _emoji == e ? AppColors.primary : AppColors.border),
                    ),
                    child: Center(child: Text(e, style: const TextStyle(fontSize: 22))),
                  ),
                )).toList(),
              ),
              const SizedBox(height: 16),
            ],

            // Nombre
            TextField(
              controller: _nameCtrl,
              enabled: !isDefault,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Nombre'),
            ),
            const SizedBox(height: 16),

            // Color
            if (!isDefault) ...[
              Text('Color', style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.textMuted)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: _colorOptions.map((hex) {
                  final color = Color(int.parse(hex.replaceFirst('#', '0xFF')));
                  final selected = hex == _colorHex;
                  return GestureDetector(
                    onTap: () => setState(() => _colorHex = hex),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected ? Colors.white : Colors.transparent,
                          width: 3,
                        ),
                        boxShadow: selected ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 8)] : null,
                      ),
                      child: selected
                          ? const Icon(Icons.check, color: Colors.white, size: 16)
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
            ] else
              const SizedBox(height: 8),

            if (isDefault)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.lock_outline, color: AppColors.textMuted, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Las categorías predeterminadas no se pueden editar',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: Text(isEditing ? 'Actualizar' : 'Crear categoría'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _KindTab extends StatelessWidget {
  final String label, value, selected;
  final Color color;
  final ValueChanged<String> onChanged;
  const _KindTab(this.label, this.value, this.selected, this.color, this.onChanged);

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
          child: Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: sel ? color : AppColors.textMuted,
                  fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                  fontSize: 13)),
        ),
      ),
    );
  }
}

