import 'package:flutter/material.dart' hide Text;
import 'package:salute_bettin/core/i18n.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:salute_bettin/core/theme.dart';
import 'package:salute_bettin/data/models/farmaco.dart';
import 'package:salute_bettin/data/repositories/local_repository.dart';
import 'package:salute_bettin/data/repositories/repository_provider.dart';
import 'farmaco_form_page.dart';
import 'oggi_page.dart';
import 'piano_testi.dart';
import 'farmaco_dettaglio_page.dart';

final farmaciProvider = FutureProvider<List<Farmaco>>((ref) async {
  final repo = LocalRepository();
  await repo.init();
  // I farmaci archiviati (eliminati ma con registro assunzioni) restano solo nello storico
  final farmaci = (await repo.getFarmaci()).where((f) => !f.archiviato).toList();
  farmaci.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  return farmaci;
});

class FarmaciPage extends ConsumerWidget {
  const FarmaciPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final farmaciAsync = ref.watch(farmaciProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Farmaci'),
        actions: [
          IconButton(
            icon: const Icon(Icons.today),
            tooltip: tr('Oggi'),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const OggiPage()),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const FarmacoFormPage()),
          );
          ref.invalidate(farmaciProvider);
        },
        backgroundColor: const Color(0xFFFF9800),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: farmaciAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Errore: $e')),
        data: (farmaci) {
          final attivi = farmaci.where((f) => f.attivo).toList();
          final inattivi = farmaci.where((f) => !f.attivo).toList();
          return farmaci.isEmpty
              ? _EmptyState()
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (attivi.isNotEmpty) ...[
                      Text('In corso',
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 8),
                      ...attivi.map((f) => _FarmacoCard(
                            farmaco: f,
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        FarmacoDettaglioPage(farmaco: f)),
                              );
                              ref.invalidate(farmaciProvider);
                            },
                          )),
                    ],
                    if (inattivi.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text('Storico',
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 8),
                      ...inattivi.map((f) => _FarmacoCard(
                            farmaco: f,
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        FarmacoDettaglioPage(farmaco: f)),
                              );
                              ref.invalidate(farmaciProvider);
                            },
                          )),
                    ],
                  ],
                );
        },
      ),
    );
  }
}

class _FarmacoCard extends StatelessWidget {
  final Farmaco farmaco;
  final VoidCallback onTap;
  const _FarmacoCard({required this.farmaco, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: farmaco.attivo
              ? const Color(0xFFFF9800).withOpacity(0.15)
              : Colors.grey.withOpacity(0.15),
          child: Icon(Icons.medication,
              color: farmaco.attivo
                  ? const Color(0xFFFF9800)
                  : Colors.grey),
        ),
        title: Text(farmaco.nome,
            style: Theme.of(context).textTheme.titleMedium),
        subtitle: Text(
          '${farmaco.dosaggio} · ${etichettaFrequenza(farmaco)}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        trailing: farmaco.promemoriaAttivo
            ? const Icon(Icons.notifications_active,
                size: 20, color: AppTheme.primary)
            : farmaco.attivo
            ? Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.secondary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('Attivo',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppTheme.secondary)),
              )
            : const Icon(Icons.chevron_right),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.medication_outlined,
              size: 80, color: Colors.grey.withOpacity(0.4)),
          const SizedBox(height: 16),
          Text('Nessun farmaco registrato',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.textSecondaryLight,
                  )),
          const SizedBox(height: 8),
          Text('Tocca + per aggiungere il primo farmaco',
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
