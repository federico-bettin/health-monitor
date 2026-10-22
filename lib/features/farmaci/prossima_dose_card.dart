import 'package:flutter/material.dart' hide Text;
import 'package:salute_bettin/core/i18n.dart';
import 'package:salute_bettin/core/theme.dart';
import 'package:salute_bettin/data/models/assunzione_farmaco.dart';
import 'package:salute_bettin/data/models/farmaco.dart';
import 'package:salute_bettin/data/repositories/local_repository.dart';
import 'package:salute_bettin/data/services/farmaci_azioni_notifica.dart';
import 'package:salute_bettin/features/farmaci/oggi_page.dart';
import 'package:salute_bettin/features/farmaci/scheduling/occorrenze.dart';

/// Card della dashboard con la prossima dose del piano terapeutico.
/// Invisibile se non ci sono promemoria attivi. Tocco → schermata "Oggi".
class ProssimaDoseCard extends StatefulWidget {
  const ProssimaDoseCard({super.key});

  @override
  State<ProssimaDoseCard> createState() => _ProssimaDoseCardState();
}

class _ProssimaDoseCardState extends State<ProssimaDoseCard> {
  DateTime? _quando;
  List<Farmaco> _farmaci = [];

  @override
  void initState() {
    super.initState();
    FarmaciAzioni.versione.addListener(_carica);
    _carica();
  }

  @override
  void dispose() {
    FarmaciAzioni.versione.removeListener(_carica);
    super.dispose();
  }

  bool _registrata(List<AssunzioneFarmaco> ass, Farmaco f, DateTime t) {
    for (final a in ass) {
      if (a.farmacoId == f.id &&
          a.dataOraPrevista != null &&
          a.dataOraPrevista!.millisecondsSinceEpoch == t.millisecondsSinceEpoch &&
          (a.stato == StatoAssunzione.presa ||
              a.stato == StatoAssunzione.saltata)) {
        return true;
      }
    }
    return false;
  }

  Future<void> _carica() async {
    try {
      final repo = LocalRepository();
      await repo.init();
      final farmaci =
          (await repo.getFarmaci()).where((f) => !f.archiviato).toList();
      final adesso = DateTime.now();
      // Include le dosi di poco fa ancora da registrare
      final da = adesso.subtract(kSogliaNonRegistrata);
      final a = DateTime(adesso.year, adesso.month, adesso.day + 8);
      final gruppi = raggruppaPerOrario(farmaci, da, a);
      final ass = await repo.getAssunzioni(da, a);

      DateTime? quando;
      var mancanti = <Farmaco>[];
      for (final g in gruppi) {
        final m = g.farmaci.where((f) => !_registrata(ass, f, g.quando)).toList();
        if (m.isNotEmpty) {
          quando = g.quando;
          mancanti = m;
          break;
        }
      }
      if (!mounted) return;
      setState(() {
        _quando = quando;
        _farmaci = mancanti;
      });
    } catch (_) {
      // la card è opzionale: se qualcosa va storto non si mostra
    }
  }

  String _quandoTesto(DateTime t) {
    final adesso = DateTime.now();
    final oggi = DateTime(adesso.year, adesso.month, adesso.day);
    final giorno = DateTime(t.year, t.month, t.day);
    final ora =
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    final diff = giorno.difference(oggi).inDays;
    if (diff == 0) return '${tr('Oggi')} $ora';
    if (diff == 1) return '${tr('Domani')} $ora';
    return '${t.day.toString().padLeft(2, '0')}/${t.month.toString().padLeft(2, '0')} $ora';
  }

  @override
  Widget build(BuildContext context) {
    final t = _quando;
    if (t == null) return const SizedBox.shrink();
    final inRitardo = t.isBefore(DateTime.now());
    final colore = inRitardo ? AppTheme.warning : AppTheme.primary;
    final nomi = _farmaci.map((f) => f.nome).join(', ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        margin: EdgeInsets.zero,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () async {
            await Navigator.push(
                context, MaterialPageRoute(builder: (_) => const OggiPage()));
            _carica();
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              CircleAvatar(
                backgroundColor: colore.withOpacity(0.15),
                child: Icon(Icons.medication, color: colore),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(inRitardo ? tr('Da prendere') : tr('Prossima dose'),
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: colore)),
                    Text('${_quandoTesto(t)} · $nomi',
                        style: Theme.of(context).textTheme.titleMedium,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ]),
          ),
        ),
      ),
    );
  }
}
