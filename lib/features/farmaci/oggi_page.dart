import 'package:flutter/material.dart' hide Text;
import 'package:salute_bettin/core/i18n.dart';
import 'package:salute_bettin/core/theme.dart';
import 'package:salute_bettin/data/models/assunzione_farmaco.dart';
import 'package:salute_bettin/data/models/farmaco.dart';
import 'package:salute_bettin/data/repositories/local_repository.dart';
import 'package:salute_bettin/data/services/farmaci_azioni_notifica.dart';
import 'package:salute_bettin/data/services/scorte_service.dart';
import 'package:salute_bettin/features/farmaci/aderenza_card.dart';
import 'package:salute_bettin/features/farmaci/registra_assunzione.dart';
import 'package:salute_bettin/features/farmaci/scheduling/occorrenze.dart';
import 'package:salute_bettin/features/farmaci/scheduling/scorte.dart';

enum _StatoUi { daPrendere, presa, saltata, nonRegistrata }

class _Dose {
  final Farmaco farmaco;
  final DateTime prevista;
  final AssunzioneFarmaco? assunzione;
  const _Dose(this.farmaco, this.prevista, this.assunzione);
}

/// Dosi di oggi dal piano terapeutico, con Preso / Salta, più i farmaci
/// "al bisogno". Si apre anche toccando una notifica dei promemoria.
class OggiPage extends StatefulWidget {
  const OggiPage({super.key});

  @override
  State<OggiPage> createState() => _OggiPageState();
}

class _OggiPageState extends State<OggiPage> {
  bool _loading = true;
  int _rev = 0; // fa ricaricare la card dell'aderenza
  String? _errore;
  List<_Dose> _dosi = [];
  List<Farmaco> _alBisogno = [];
  List<AssunzioneFarmaco> _alBisognoOggi = [];
  List<(Farmaco, StatoScorte)> _avvisiScorte = [];

  @override
  void initState() {
    super.initState();
    FarmaciAzioni.versione.addListener(_carica);
    // Registra subito i "Preso" toccati sulle notifiche
    FarmaciAzioni.applicaCoda();
    _carica();
  }

  @override
  void dispose() {
    FarmaciAzioni.versione.removeListener(_carica);
    super.dispose();
  }

  AssunzioneFarmaco? _trova(
      List<AssunzioneFarmaco> lista, String farmacoId, DateTime prevista) {
    for (final a in lista) {
      if (a.farmacoId == farmacoId &&
          a.dataOraPrevista != null &&
          a.dataOraPrevista!.millisecondsSinceEpoch ==
              prevista.millisecondsSinceEpoch) {
        return a;
      }
    }
    return null;
  }

  Future<void> _carica() async {
    try {
      final repo = LocalRepository();
      await repo.init();
      final farmaci =
          (await repo.getFarmaci()).where((f) => !f.archiviato).toList();
      final adesso = DateTime.now();
      final inizio = DateTime(adesso.year, adesso.month, adesso.day);
      final fine = DateTime(adesso.year, adesso.month, adesso.day + 1);
      final registrate = await repo.getAssunzioni(inizio, fine);

      final dosi = <_Dose>[];
      for (final f in farmaci) {
        for (final t in generaOccorrenze(f, inizio, fine)) {
          dosi.add(_Dose(f, t, _trova(registrate, f.id, t)));
        }
      }
      dosi.sort((a, b) {
        final c = a.prevista.compareTo(b.prevista);
        return c != 0
            ? c
            : a.farmaco.nome.toLowerCase().compareTo(b.farmaco.nome.toLowerCase());
      });

      final alBisogno = farmaci
          .where((f) =>
              f.attivo && f.frequenzaTipo == FrequenzaFarmaco.alBisogno)
          .toList();
      final idAlBisogno = alBisogno.map((f) => f.id).toSet();
      final alBisognoOggi = registrate
          .where((a) =>
              a.dataOraPrevista == null && idAlBisogno.contains(a.farmacoId))
          .toList();

      // Farmaci in uso con scorte in esaurimento
      final avvisi = <(Farmaco, StatoScorte)>[];
      for (final f in farmaci) {
        if (!f.attivo || f.isScaduto) continue;
        final s = statoScorte(f, adesso);
        if (s != null && s.inAvviso) avvisi.add((f, s));
      }

      if (!mounted) return;
      setState(() {
        _rev++;
        _avvisiScorte = avvisi;
        _dosi = dosi;
        _alBisogno = alBisogno;
        _alBisognoOggi = alBisognoOggi;
        _errore = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errore = '$e';
        _loading = false;
      });
    }
  }

  _StatoUi _stato(_Dose d) {
    final a = d.assunzione;
    if (a != null && a.stato == StatoAssunzione.presa) return _StatoUi.presa;
    if (a != null && a.stato == StatoAssunzione.saltata) return _StatoUi.saltata;
    if (DateTime.now().isAfter(d.prevista.add(kSogliaNonRegistrata))) {
      return _StatoUi.nonRegistrata;
    }
    return _StatoUi.daPrendere;
  }

  Future<void> _segna(_Dose d, StatoAssunzione s) async {
    await registraDosePrevista(d.farmaco, d.prevista, s);
    await _carica();
  }

  Future<void> _annulla(_Dose d) async {
    final a = d.assunzione;
    if (a == null) return;
    await annullaAssunzione(a);
    await _carica();
  }

  Future<void> _registraAlBisogno(Farmaco f) async {
    final ok = await registraAssunzioneManuale(context, f);
    if (ok) {
      await _carica();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Assunzione registrata')));
      }
    }
  }

  String _hhmm(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Oggi')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _errore != null
              ? Center(child: Text('Errore: $_errore'))
              : RefreshIndicator(
                  onRefresh: _carica,
                  child: _contenuto(),
                ),
    );
  }

  Widget _bannerScorte() => Card(
        margin: const EdgeInsets.only(bottom: 12),
        color: AppTheme.warning.withOpacity(0.12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.inventory_2_outlined,
                    size: 18, color: AppTheme.warning),
                const SizedBox(width: 8),
                const Text('Scorte in esaurimento',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ]),
              for (final (f, s) in _avvisiScorte)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(testoAvvisoScorte(f, s)),
                ),
            ],
          ),
        ),
      );

  Widget _contenuto() {
    if (_dosi.isEmpty && _alBisogno.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(32),
        children: [
          if (_avvisiScorte.isNotEmpty) _bannerScorte(),
          const SizedBox(height: 48),
          Icon(Icons.check_circle_outline,
              size: 72, color: Colors.grey.withOpacity(0.4)),
          const SizedBox(height: 16),
          const Text('Nessuna dose prevista oggi',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          const Text(
              'Per ricevere i promemoria, apri un farmaco e attiva il promemoria con gli orari.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondaryDark)),
        ],
      );
    }

    final prese = _dosi.where((d) => _stato(d) == _StatoUi.presa).length;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        if (_avvisiScorte.isNotEmpty) _bannerScorte(),
        if (_dosi.isNotEmpty) ...[
          Text(tr('Dosi di oggi: {0} su {1} prese', [prese, _dosi.length]),
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          AderenzaCard(rev: _rev),
          for (final d in _dosi) _cardDose(d),
        ],
        if (_alBisogno.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Al bisogno', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final f in _alBisogno) _cardAlBisogno(f),
        ],
      ],
    );
  }

  Widget _cardDose(_Dose d) {
    final stato = _stato(d);
    final (colore, etichetta, icona) = switch (stato) {
      _StatoUi.presa => (AppTheme.secondary, tr('Presa'), Icons.check_circle),
      _StatoUi.saltata => (AppTheme.warning, tr('Saltata'), Icons.skip_next),
      _StatoUi.nonRegistrata =>
        (AppTheme.error, tr('Non registrata'), Icons.help_outline),
      _StatoUi.daPrendere =>
        (AppTheme.primary, tr('Da prendere'), Icons.schedule),
    };
    final registrata = stato == _StatoUi.presa || stato == _StatoUi.saltata;
    final dettagli = <String>[
      if (d.farmaco.dosaggio.trim().isNotEmpty) d.farmaco.dosaggio.trim(),
      if ((d.farmaco.istruzioni ?? '').trim().isNotEmpty)
        d.farmaco.istruzioni!.trim(),
    ].join(' · ');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text(_hhmm(d.prevista),
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(d.farmaco.nome,
                        style: Theme.of(context).textTheme.titleMedium),
                    if (dettagli.isNotEmpty)
                      Text(dettagli, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: colore.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(icona, size: 14, color: colore),
                  const SizedBox(width: 4),
                  Text(etichetta,
                      style: TextStyle(fontSize: 12, color: colore)),
                ]),
              ),
            ]),
            const SizedBox(height: 8),
            if (registrata)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _annulla(d),
                  icon: const Icon(Icons.undo, size: 16),
                  label: const Text('Annulla'),
                ),
              )
            else
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                OutlinedButton(
                    style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 40)),
                    onPressed: () => _segna(d, StatoAssunzione.saltata),
                    child: const Text('Salta')),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                        minimumSize: const Size(0, 40)),
                    onPressed: () => _segna(d, StatoAssunzione.presa),
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Preso')),
              ]),
          ],
        ),
      ),
    );
  }

  Widget _cardAlBisogno(Farmaco f) {
    final oggi = _alBisognoOggi.where((a) => a.farmacoId == f.id).toList()
      ..sort((a, b) => (a.dataOraRegistrata ?? DateTime(2000))
          .compareTo(b.dataOraRegistrata ?? DateTime(2000)));
    final orari = oggi
        .where((a) => a.dataOraRegistrata != null)
        .map((a) => _hhmm(a.dataOraRegistrata!))
        .join(', ');
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: const Icon(Icons.medication_outlined),
        title: Text(f.nome),
        subtitle: Text(orari.isEmpty
            ? f.dosaggio
            : '${f.dosaggio} · ${tr('Oggi')}: $orari'),
        trailing: ElevatedButton(
            style: ElevatedButton.styleFrom(minimumSize: const Size(0, 40)),
            onPressed: () => _registraAlBisogno(f),
            child: const Text('Registra')),
      ),
    );
  }
}
