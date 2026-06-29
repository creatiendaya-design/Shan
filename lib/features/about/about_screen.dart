import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Acerca de Shannon',
            style: Theme.of(context).textTheme.headlineMedium),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 12),
            _AppLogo(),
            const SizedBox(height: 32),
            _MessageCard(),
            const SizedBox(height: 24),
            _InfoSection(),
            const SizedBox(height: 24),
            _PrivacyCard(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

// ── Logo ─────────────────────────────────────────────────────────────────────

class _AppLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primary, AppColors.primaryDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.4),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Center(
            child: Text('S',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 40,
                    fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(height: 16),
        Text('Shannon',
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                )),
        const SizedBox(height: 4),
        Text('Tu app de finanzas personales',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.textMuted)),
        const SizedBox(height: 8),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.3)),
          ),
          child: const Text('Versión 1.0.0',
              style: TextStyle(
                  color: AppColors.primaryLight,
                  fontSize: 12,
                  fontWeight: FontWeight.w500)),
        ),
      ],
    );
  }
}

// ── Mensaje personal ─────────────────────────────────────────────────────────

class _MessageCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.2),
            AppColors.primaryDark.withValues(alpha: 0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.favorite,
                  color: AppColors.primaryLight, size: 16),
              const SizedBox(width: 8),
              Text('Un mensaje',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppColors.primaryLight,
                        letterSpacing: 0.5,
                      )),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Shannon',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 12),
          Text(
            'Toda reina merece un regalo\nque lleve su nombre.\n\nEsta app es tuya.\nCreada para ti, solo para ti.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white.withValues(alpha: 0.85),
                  height: 1.7,
                ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '— Lionel',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.primaryLight,
                    fontStyle: FontStyle.italic,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Info de la app ───────────────────────────────────────────────────────────

class _InfoSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.smartphone_outlined, 'Plataformas', 'Android e iOS'),
      (Icons.lock_outline, 'Privacidad', '100% local, sin internet'),
      (Icons.storage_outlined, 'Datos', 'Guardados solo en tu celular'),
      (Icons.block_outlined, 'Sin anuncios', 'Sin rastreo, sin publicidad'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: items.asMap().entries.map((e) {
          final i = e.key;
          final item = e.value;
          return Column(
            children: [
              ListTile(
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(item.$1,
                      color: AppColors.primaryLight, size: 18),
                ),
                title: Text(item.$2,
                    style: Theme.of(context).textTheme.bodyLarge),
                trailing: Text(item.$3,
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: AppColors.textMuted)),
              ),
              if (i < items.length - 1)
                const Divider(
                    height: 1, indent: 56, color: AppColors.border),
            ],
          );
        }).toList(),
      ),
    );
  }
}

// ── Privacidad ────────────────────────────────────────────────────────────────

class _PrivacyCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.shield_outlined,
              color: AppColors.income, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tu privacidad es la prioridad',
                    style: Theme.of(context)
                        .textTheme
                        .labelLarge
                        ?.copyWith(color: AppColors.income)),
                const SizedBox(height: 4),
                Text(
                  'Shannon nunca envía tus datos a ningún servidor. Todo vive en tu teléfono. Solo tú tienes acceso.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.5,
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
