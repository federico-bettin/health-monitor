import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:salute_bettin/core/theme.dart';
import 'package:salute_bettin/data/models/appuntamento.dart';
import 'package:salute_bettin/data/repositories/local_repository.dart';

/// Riepilogo di un anno: visite/esami effettuati e relativo costo.
class StatAnno {
  final int anno;
  int visite = 0;
  int esami = 0;
  double costoVisite = 0;
  double costoEsami = 0;
  int senzaCosto = 0; // effettuati senza costo indicato

  StatAnno(this.anno);

  int get totale => visite + esami;
  double get costoTotale => costoVisite + costoEsami;
}

/// Conta solo gli appuntamenti di tipo visita/esame marcati "effettuato".
final statisticheProvider = FutureProvider<List<StatAnno>>((ref) async {
  final repo = LocalRepository();
  await repo.init();
  final lista = await repo.getAppuntamenti();
  final map = <int, StatAnno>{};
  for (final a in lista) {
    if (!a.completato) continue;
    if (a.tipo != TipoAppuntamento.visita &&
        a.tipo != TipoAppuntamento.esame) {
      continue;
    }
    final s = map.putIfAbsent(a.data.year, () => StatAnno(a.data.year));
    final c = a.costo ?? 0;
    if (a.costo == null) s.senzaCosto++;
    if (a.tipo == TipoAppuntamento.visita) {
      s.visite++;
      s.costoVisite += c;
    } else {
      s.esami++;
      s.costoEsami += c;
    }
  }
  final anni = map.values.toList()..sort((a, b) => b.anno.compareTo(a.anno));
  return anni; // dal più recente al più vecchio
});

class StatistichePage extends ConsumerWidget {
  const StatistichePage({super.key});

  static String _chf(double v) => 'CHF ${v.toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(statisticheProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Statistiche per anno')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Errore: $e')),
        data: (anni) {
          if (anni.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Nessuna visita o esame effettuato.\n'
                  'Dal Calendario tocca ✓ su un appuntamento per segnarlo come effettuato.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: anni.length,
            itemBuilder: (_, i) => _AnnoCard(s: anni[i]),
          );
        },
      ),
    );
  }
}

class _AnnoCard extends StatelessWidget {
  final StatAnno s;
  const _AnnoCard({required this.s});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${s.anno}', style: t.titleLarge),
            const SizedBox(height: 8),
            Row(children: [
              const Expanded(child: SizedBox()),
              Text('N°', style: t.bodySmall),
              SizedBox(
                  width: 110,
                  child: Text('Costo',
                      textAlign: TextAlign.end, style: t.bodySmall)),
            ]),
            const Divider(),
            _riga(context, Icons.local_hospital, 'Visite', s.visite,
                s.costoVisite),
            _riga(context, Icons.science, 'Esami', s.esami, s.costoEsami),
            const Divider(),
            _riga(context, Icons.summarize, 'Totale', s.totale, s.costoTotale,
                bold: true),
            if (s.senzaCosto > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '${s.senzaCosto} senza costo indicato',
                  style: t.bodySmall?.copyWith(color: AppTheme.textSecondaryLight),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _riga(BuildContext context, IconData icona, String label, int n,
      double costo,
      {bool bold = false}) {
    final st = TextStyle(fontWeight: bold ? FontWeight.bold : null);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Icon(icona, size: 18, color: AppTheme.primary),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: st)),
        Text('$n', style: st),
        SizedBox(
          width: 110,
          child: Text(StatistichePage._chf(costo),
              textAlign: TextAlign.end, style: st),
        ),
      ]),
    );
  }
}
