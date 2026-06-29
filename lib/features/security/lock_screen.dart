import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/theme/app_colors.dart';
import '../../shared/providers/security_provider.dart';

class LockScreen extends ConsumerStatefulWidget {
  final VoidCallback onUnlocked;

  const LockScreen({super.key, required this.onUnlocked});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  String _securityType = 'none';
  String _pin = '';
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final service = ref.read(securityServiceProvider);
    final type = await service.getSecurityType();
    setState(() {
      _securityType = type;
      _loading = false;
    });
    if (type == 'none') {
      widget.onUnlocked();
    }
  }

  void _onKey(String digit) {
    if (_pin.length >= 4) return;
    setState(() {
      _error = null;
      _pin += digit;
    });
    if (_pin.length == 4) _verifyPin();
  }

  void _onDelete() {
    if (_pin.isEmpty) return;
    setState(() {
      _error = null;
      _pin = _pin.substring(0, _pin.length - 1);
    });
  }

  Future<void> _verifyPin() async {
    final service = ref.read(securityServiceProvider);
    final ok = await service.verifyPin(_pin);
    if (ok) {
      widget.onUnlocked();
    } else {
      setState(() {
        _error = 'PIN incorrecto';
        _pin = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
            child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            // Logo / nombre
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Center(
                child: Text('S',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 16),
            Text('Shannon',
                style: Theme.of(context).textTheme.headlineLarge),
            const SizedBox(height: 8),
            Text(
              'Ingresa tu PIN',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 40),

            if (_securityType == 'pin') ...[
              // Puntos PIN
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (i) {
                  final filled = i < _pin.length;
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color:
                          filled ? AppColors.primary : Colors.transparent,
                      border: Border.all(
                        color: filled
                            ? AppColors.primary
                            : AppColors.textMuted,
                        width: 2,
                      ),
                    ),
                  );
                }),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!,
                    style: const TextStyle(
                        color: AppColors.expense, fontSize: 13)),
              ],
            ],

            const Spacer(),

            if (_securityType == 'pin') ...[
              _NumPadLock(onKey: _onKey, onDelete: _onDelete),
              const SizedBox(height: 32),
            ],
          ],
        ),
      ),
    );
  }
}

class _NumPadLock extends StatelessWidget {
  final ValueChanged<String> onKey;
  final VoidCallback onDelete;

  const _NumPadLock({required this.onKey, required this.onDelete});

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
              : _Key(digit: k, onTap: () => onKey(k))),
          _Key(digit: '⌫', onTap: onDelete, isDelete: true),
        ],
      ),
    );
  }
}

class _Key extends StatelessWidget {
  final String digit;
  final VoidCallback onTap;
  final bool isDelete;

  const _Key(
      {required this.digit, required this.onTap, this.isDelete = false});

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
                color:
                    isDelete ? AppColors.textMuted : AppColors.textPrimary,
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
