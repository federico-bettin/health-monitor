import 'package:flutter/material.dart' hide Text;
import 'package:salute_bettin/core/i18n.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:salute_bettin/core/theme.dart';
import 'package:salute_bettin/data/models/visita.dart';
import 'package:salute_bettin/data/repositories/local_repository.dart';
import 'package:salute_bettin/data/repositories/repository_provider.dart';
import 'visita_form_page.dart';
import 'visita_dettaglio_page.dart';

final visiteProvider = FutureProvider<List<Visita>>((ref) async {
  final repo = LocalRepository();
  await repo.init();
  final visite = await repo.getVisite();
  visite.sort((a, b) => b.data.compareTo(a.data));
  return visite;
});

class VisitePage extends ConsumerWidget {
  const VisitePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visiteAsync = ref.watch(visiteProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Visite')),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const VisitaFormPage()),
          );
          ref.invalidate(visiteProvider);
        },
        backgroundColor: AppTheme.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: visiteAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Errore: $e')),
        data: (visite) => visite.isEmpty
            ? _EmptyState()
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: visite.length,
                itemBuilder: (context, i) => _VisitaCard(
                  visita: visite[i],
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            VisitaDettaglioPage(visita: visite[i]),
                      ),
                    );
                    ref.invalidate(visiteProvider);
                  },
                ),
              ),
      ),
    );
  }
}

class _VisitaCard extends StatelessWidget {
  final Visita visita;
  final VoidCallback onTap;
  const _VisitaCard({required this.visita, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: AppTheme.primary.withOpacity(0.15),
          child: const Icon(Icons.local_hospital, color: AppTheme.primary),
        ),
        title: Text(visita.specialita,
            style: Theme.of(context).textTheme.titleMedium),
        subtitle: Text(
          '${visita.data.day}/${visita.data.month}/${visita.data.year}'
          '${visita.medico != null ? ' · ${visita.medico}' : ''}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        trailing: visita.diagnosi != null
            ? const Icon(Icons.assignment, color: AppTheme.primary, size: 20)
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
          Icon(Icons.local_hospital_outlined,
              size: 80, color: Colors.grey.withOpacity(0.4)),
          const SizedBox(height: 16),
          Text('Nessuna visita registrata',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.textSecondaryLight,
                  )),
          const SizedBox(height: 8),
          Text('Tocca + per aggiungere la prima visita',
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
