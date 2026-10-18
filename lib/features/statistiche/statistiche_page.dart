import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:salute_bettin/core/format.dart';
import 'package:salute_bettin/core/theme.dart';
import 'package:salute_bettin/data/models/appuntamento.dart';
import 'package:salute_bettin/data/repositories/local_repository.dart';

/// Riepilogo di un anno: visite/esami con costo indicato.
class StatAnno {
  final int anno;
  final List<Appuntamento> voci = []; // dal più recente al più vecchio
  int visite = 0;
  int esami = 0;
  double costoVisite = 0;
  double costoEsami = 0;

  StatAnno(this.anno);

  int get totale => visite + esami;
  double get costoTotale => costoVisite + costoEsami;
}

/// Conta gli appuntamenti di tipo visita/esame a cui è stato indicato un costo.
/// autoDispose: i dati vengono ricalcolati ogni volta che si apre la pagina,
/// così includono gli appuntamenti aggiunti/modificati/cancellati nel frattempo.
final statisticheProvider =
    FutureProvider.autoDispose<List<StatAnno>>((ref) async {
  final repo = LocalRepository();
  await repo.init();
  final lista = await repo.getAppuntamenti();
  final map = <int, StatAnno>{};
  for (final a in lista) {
    if (a.costo == null) continue;
    if (a.tipo != TipoAppuntamento.visita &&
        a.tipo != TipoAppuntamento.esame) {
      continue;
    }
    final s = map.putIfAbsent(a.data.year, () => StatAnno(a.data.year));
    s.voci.add(a);
    if (a.tipo == TipoAppuntamento.visita) {
      s.visite++;
      s.costoVisite += a.costo!;
    } else {
      s.esami++;
      s.costoEsami += a.costo!;
    }
  }
  for (final s in map.values) {
    s.voci.sort((a, b) => b.data.compareTo(a.data));
  }
  final anni = map.values.toList()..sort((a, b) => b.anno.compareTo(a.anno));
  return anni; // dal più recente al più vecchio
});

class StatistichePage extends ConsumerWidget {
  const StatistichePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(statisticheProvider);
    const titolo = Text('Statistiche visite ed esami');

    return async.when(
      loading: () => const Scaffold(
        appBar: _SempliceAppBar(),
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: const _SempliceAppBar(),
        body: Center(child: Text('Errore: $e')),
      ),
      data: (anni) {
        if (anni.isEmpty) {
          return const Scaffold(
            appBar: _SempliceAppBar(),
            body: Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Nessuna visita o esame con costo.\n'
                  'Inserisci il costo di un appuntamento dal Calendario '
                  'e comparirà qui.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }
        // Un tab per ogni anno (il più recente per primo).
        // La key forza il ricalcolo dei tab se cambia l'elenco degli anni.
        return DefaultTabController(
          key: ValueKey(anni.map((a) => a.anno).join(',')),
          length: anni.length,
          child: Scaffold(
            appBar: AppBar(
              title: titolo,
              bottom: TabBar(
                isScrollable: anni.length > 4,
                tabs: [for (final a in anni) Tab(text: '${a.anno}')],
              ),
            ),
            body: TabBarView(
              children: [
                for (final a in anni)
                  RefreshIndicator(
                    onRefresh: () async =>
                        ref.refresh(statisticheProvider.future),
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      children: [_AnnoCard(s: a)],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SempliceAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _SempliceAppBar();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) =>
      AppBar(title: const Text('Statistiche visite ed esami'));
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
            Row(children: [
              const Expanded(child: SizedBox()),
              Text('N°', style: t.bodySmall),
              SizedBox(
                  width: 110,
                  child: Text('Costo',
                      textAlign: TextAlign.end, style: t.bodySmall)),
            ]),
            const Divider(),
            _riga(Icons.local_hospital, 'Visite', s.visite, s.costoVisite),
            _riga(Icons.science, 'Esami', s.esami, s.costoEsami),
            const Divider(),
            _riga(Icons.summarize, 'Totale', s.totale, s.costoTotale,
                bold: true),
            const SizedBox(height: 12),
            Text('Dettaglio', style: t.labelLarge?.copyWith(color: AppTheme.primary)),
            const SizedBox(height: 4),
            for (final a in s.voci) _voce(context, a),
          ],
        ),
      ),
    );
  }

  Widget _riga(IconData icona, String label, int n, double costo,
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
          child: Text(formatEuro(costo),
              textAlign: TextAlign.end, style: st),
        ),
      ]),
    );
  }

  Widget _voce(BuildContext context, Appuntamento a) {
    final t = Theme.of(context).textTheme;
    final isEsame = a.tipo == TipoAppuntamento.esame;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Icon(isEsame ? Icons.science : Icons.local_hospital,
            size: 16,
            color: isEsame ? const Color(0xFF4CAF50) : const Color(0xFF2196F3)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(a.titolo, style: t.bodyMedium),
              Text(formatData(a.data), style: t.bodySmall),
            ],
          ),
        ),
        Text(formatEuro(a.costo!), style: t.bodyMedium),
      ]),
    );
  }
}
