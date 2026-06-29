import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/theme/app_colors.dart';
import '../../shared/providers/security_provider.dart';

class SecuritySetupScreen extends ConsumerStatefulWidget {
  const SecuritySetupScreen({super.key});

  @override
  ConsumerState<SecuritySetupScreen> createState() =>
      _SecuritySetupScreenState();
}

class _SecuritySetupScreenState extends ConsumerState<SecuritySetupScreen> {
  String _selected = 'none';
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadCurrent();
  }

  Future<void> _loadCurrent() async {
    final service = ref.read(securityServiceProvider);
    final type = await service.getSecurityType();
    if (mounted) setState(() => _selected = type);
  }

  Future<void> _onSelect(String type) async {
    if (type == 'pin') {
      final result = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const _PinSetupScreen()),
      );
      if (result != true) return;
    }

    if (type == 'none') {
      final service = ref.read(securityServiceProvider);
      await service.deletePin();
    }

    setState(() => _loading = true);
    final service = ref.read(securityServiceProvider);
    await service.setSecurityType(type);
    ref.invalidate(securityTypeProvider);

    if (mounted) {
      setState(() {
        _selected = type;
        _loading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_successMessage(type)),
          backgroundColor: AppColors.income,
        ),
      );
    }
  }

  String _successMessage(String type) {
    switch (type) {
      case 'pin':
        return 'PIN configurado correctamente';
      default:
        return 'Sin bloqueo activado';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Seguridad',
            style: Theme.of(context).textTheme.headlineMedium),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  'Elige cómo proteger Shannon',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 20),
                _SecurityOption(
                  icon: Icons.lock_open_outlined,
                  title: 'Sin bloqueo',
                  subtitle: 'La app abre directo al entrar',
                  selected: _selected == 'none',
                  onTap: () => _onSelect('none'),
                ),
                const SizedBox(height: 12),
                _SecurityOption(
                  icon: Icons.pin_outlined,
                  title: 'PIN',
                  subtitle: 'Código de 4 dígitos que solo tú conoces',
                  selected: _selected == 'pin',
                  onTap: () => _onSelect('pin'),
                ),
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline,
                          color: AppColors.primaryLight, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Tus datos siempre permanecen solo en tu teléfono. Shannon nunca comparte tu información.',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontSize: 13,
                                  ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _SecurityOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _SecurityOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.15)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.primary.withValues(alpha: 0.2)
                      : AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon,
                    color:
                        selected ? AppColors.primary : AppColors.textMuted,
                    size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: selected
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary,
                            )),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: Theme.of(context).textTheme.labelSmall),
                  ],
                ),
              ),
              if (selected)
                const Icon(Icons.check_circle,
                    color: AppColors.primary, size: 22),
            ],
          ),
        ),
    );
  }
}

// ── PIN Setup ────────────────────────────────────────────────────────────────

class _PinSetupScreen extends ConsumerStatefulWidget {
  const _PinSetupScreen();

  @override
  ConsumerState<_PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends ConsumerState<_PinSetupScreen> {
  String _pin = '';
  String _confirmPin = '';
  bool _confirming = false;
  String? _error;

  void _onKey(String digit) {
    setState(() {
      _error = null;
      if (!_confirming) {
        if (_pin.length < 4) {
          _pin += digit;
          if (_pin.length == 4) setState(() => _confirming = true);
        }
      } else {
        if (_confirmPin.length < 4) {
          _confirmPin += digit;
          if (_confirmPin.length == 4) _checkPins();
        }
      }
    });
  }

  void _onDelete() {
    setState(() {
      _error = null;
      if (_confirming) {
        if (_confirmPin.isNotEmpty) {
          _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1);
        }
      } else {
        if (_pin.isNotEmpty) {
          _pin = _pin.substring(0, _pin.length - 1);
        }
      }
    });
  }

  Future<void> _checkPins() async {
    if (_pin != _confirmPin) {
      setState(() {
        _error = 'Los PINs no coinciden. Intenta de nuevo.';
        _confirmPin = '';
        _pin = '';
        _confirming = false;
      });
      return;
    }
    final service = ref.read(securityServiceProvider);
    await service.savePin(_pin);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final current = _confirming ? _confirmPin : _pin;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_confirming ? 'Confirmar PIN' : 'Crear PIN',
            style: Theme.of(context).textTheme.headlineMedium),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_confirming) {
              setState(() {
                _confirming = false;
                _confirmPin = '';
              });
            } else {
              Navigator.of(context).pop(false);
            }
          },
        ),
      ),
      body: Column(
        children: [
          const SizedBox(height: 40),
          Text(
            _confirming ? 'Repite tu PIN' : 'Ingresa un PIN de 4 dígitos',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: 32),
          // Puntos
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(4, (i) {
              final filled = i < current.length;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 10),
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: filled ? AppColors.primary : Colors.transparent,
                  border: Border.all(
                    color: filled ? AppColors.primary : AppColors.textMuted,
                    width: 2,
                  ),
                ),
              );
            }),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!,
                style: const TextStyle(color: AppColors.expense, fontSize: 13)),
          ],
          const Spacer(),
          // Teclado numérico
          _NumPad(onKey: _onKey, onDelete: _onDelete),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _NumPad extends StatelessWidget {
  final ValueChanged<String> onKey;
  final VoidCallback onDelete;

  const _NumPad({required this.onKey, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48),
      child: GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 1.6,
        children: [
          ...keys.map((k) => k.isEmpty
              ? const SizedBox()
              : _NumKey(digit: k, onTap: () => onKey(k))),
          _NumKey(
            digit: '⌫',
            onTap: onDelete,
            isDelete: true,
          ),
        ],
      ),
    );
  }
}

class _NumKey extends StatelessWidget {
  final String digit;
  final VoidCallback onTap;
  final bool isDelete;

  const _NumKey({
    required this.digit,
    required this.onTap,
    this.isDelete = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Center(
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.surface,
            border: Border.all(color: AppColors.border),
          ),
          child: Center(
            child: Text(
              digit,
              style: TextStyle(
                color: isDelete ? AppColors.textMuted : AppColors.textPrimary,
                fontSize: isDelete ? 20 : 24,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

