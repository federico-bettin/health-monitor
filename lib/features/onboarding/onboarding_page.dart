import 'package:flutter/material.dart' hide Text;
import 'package:salute_bettin/core/i18n.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:salute_bettin/core/constants.dart';
import 'package:salute_bettin/core/router.dart';
import 'package:salute_bettin/core/theme.dart';
import 'package:salute_bettin/data/services/settings_service.dart';

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  String _storageMode = AppConstants.storageModeLocal;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _completa() async {
    final settings = SettingsService.instance;
    await settings.setStorageMode(_storageMode);
    await settings.setOnboardingDone(true);
    if (mounted) context.go(AppRoutes.dashboard);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(2, (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: _currentPage == i ? 24 : 8, height: 8,
                decoration: BoxDecoration(
                  color: _currentPage == i
                      ? AppTheme.primary : AppTheme.primary.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(4)),
              ))),
          ),
          Expanded(child: PageView(
            controller: _pageController,
            onPageChanged: (i) => setState(() => _currentPage = i),
            children: [
              _PageBenvenuto(onNext: _nextPage),
              _PageStorage(selected: _storageMode,
                  onChanged: (v) => setState(() => _storageMode = v),
                  onCompleta: _completa),
            ],
          )),
        ]),
      ),
    );
  }
}

class _PageBenvenuto extends StatelessWidget {
  final VoidCallback onNext;
  const _PageBenvenuto({required this.onNext});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(width: 90, height: 90,
          decoration: BoxDecoration(shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [AppTheme.primary, AppTheme.primaryDark],
              begin: Alignment.topLeft, end: Alignment.bottomRight),
            boxShadow: [BoxShadow(color: AppTheme.primary.withOpacity(0.4),
                blurRadius: 24, offset: const Offset(0, 8))]),
          child: const Icon(Icons.monitor_heart, size: 44, color: Colors.white)),
        const SizedBox(height: 32),
        Text('Health Monitor',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.displayMedium),
        const SizedBox(height: 16),
        Text('Il tuo monitor della salute personale.\nSemplice, privato, sempre con te.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppTheme.textSecondaryDark)),
        const SizedBox(height: 48),
        ElevatedButton(onPressed: onNext, child: const Text('Inizia')),
      ]),
    );
  }
}

class _PageStorage extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;
  final VoidCallback onCompleta;

  const _PageStorage({required this.selected, required this.onChanged, required this.onCompleta});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Dove salvare i dati?', style: Theme.of(context).textTheme.headlineLarge),
        const SizedBox(height: 8),
        Text('Puoi cambiare questa impostazione in seguito.',
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: AppTheme.textSecondaryDark)),
        const SizedBox(height: 32),
        _StorageCard(icon: Icons.phone_android, titolo: 'Solo dispositivo',
            descrizione: 'I dati restano sul telefono. Nessun account richiesto.',
            mode: AppConstants.storageModeLocal, selected: selected, onTap: onChanged),
        const SizedBox(height: 12),
        _StorageCard(icon: Icons.cloud, titolo: 'Google Drive',
            descrizione: 'Backup automatico su Drive.',
            mode: AppConstants.storageModeDrive, selected: selected, onTap: onChanged),
        const SizedBox(height: 12),
        _StorageCard(icon: Icons.sync, titolo: 'Dispositivo + Drive',
            descrizione: 'Lavora offline, sincronizza quando connesso.',
            mode: AppConstants.storageModeSync, selected: selected, onTap: onChanged),
        const SizedBox(height: 40),
        ElevatedButton(onPressed: onCompleta,
            child: const Text('Inizia a usare Health Monitor')),
      ]),
    );
  }
}

class _StorageCard extends StatelessWidget {
  final IconData icon;
  final String titolo, descrizione, mode, selected;
  final ValueChanged<String> onTap;

  const _StorageCard({required this.icon, required this.titolo, required this.descrizione,
      required this.mode, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isSelected = selected == mode;
    return GestureDetector(
      onTap: () => onTap(mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary.withOpacity(0.1) : AppTheme.cardDark,
          border: Border.all(
              color: isSelected ? AppTheme.primary : AppTheme.borderDark, width: 2),
          borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          Icon(icon, size: 32,
              color: isSelected ? AppTheme.primary : AppTheme.textSecondaryDark),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(titolo, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(descrizione, style: Theme.of(context).textTheme.bodySmall),
          ])),
          if (isSelected) const Icon(Icons.check_circle, color: AppTheme.primary),
        ]),
      ),
    );
  }
}
