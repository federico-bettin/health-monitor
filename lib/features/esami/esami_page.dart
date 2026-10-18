import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:salute_bettin/core/theme.dart';
import 'package:salute_bettin/data/models/esame.dart';
import 'package:salute_bettin/data/repositories/local_repository.dart';
import 'package:salute_bettin/data/repositories/repository_provider.dart';
import 'esame_form_page.dart';
import 'esame_dettaglio_page.dart';

final esamiProvider = FutureProvider<List<Esame>>((ref) async {
  final repo = LocalRepository();
  await repo.init();
  final esami = await repo.getEsami();
  esami.sort((a, b) => b.data.compareTo(a.data));
  return esami;
});

class EsamiPage extends ConsumerWidget {
  const EsamiPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final esamiAsync = ref.watch(esamiProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Esami')),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const EsameFormPage()),
          );
          ref.invalidate(esamiProvider);
        },
        backgroundColor: AppTheme.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: esamiAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Errore: $e')),
        data: (esami) => esami.isEmpty
            ? _EmptyState()
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: esami.length,
                itemBuilder: (context, i) => _EsameCard(
                  esame: esami[i],
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EsameDettaglioPage(esame: esami[i]),
                      ),
                    );
                    ref.invalidate(esamiProvider);
                  },
                ),
              ),
      ),
    );
  }
}

class _EsameCard extends StatelessWidget {
  final Esame esame;
  final VoidCallback onTap;
  const _EsameCard({required this.esame, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final fuoriRange = esame.valori.any((v) => v.fuoriRange);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor:
              fuoriRange ? AppTheme.error.withOpacity(0.15) : AppTheme.secondary.withOpacity(0.15),
          child: Icon(
            Icons.science,
            color: fuoriRange ? AppTheme.error : AppTheme.secondary,
          ),
        ),
        title: Text(esame.tipo,
            style: Theme.of(context).textTheme.titleMedium),
        subtitle: Text(
          '${esame.data.day}/${esame.data.month}/${esame.data.year}'
          '${esame.laboratorio != null ? ' · ${esame.laboratorio}' : ''}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        trailing: fuoriRange
            ? Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Fuori range',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppTheme.error),
                ),
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
          Icon(Icons.science_outlined,
              size: 80, color: Colors.grey.withOpacity(0.4)),
          const SizedBox(height: 16),
          Text('Nessun esame registrato',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.textSecondaryLight,
                  )),
          const SizedBox(height: 8),
          Text('Tocca + per aggiungere il primo esame',
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
