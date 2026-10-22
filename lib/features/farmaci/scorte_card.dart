import 'package:flutter/material.dart' hide Text;
import 'package:salute_bettin/core/i18n.dart';
import 'package:salute_bettin/core/theme.dart';
import 'package:salute_bettin/data/models/farmaco.dart';
import 'package:salute_bettin/data/repositories/local_repository.dart';
import 'package:salute_bettin/features/farmaci/scheduling/scorte.dart';

/// Scorte di un farmaco nel dettaglio: unità rimaste, giorni stimati e
/// pulsante "Rifornimento". Mostra i dati aggiornati dal registro.
class ScorteCard extends StatefulWidget {
  final String farmacoId;
  const ScorteCard({super.key, required this.farmacoId});

  @override
  State<ScorteCard> createState() => _ScorteCardState();
}

class _ScorteCardState extends State<ScorteCard> {
  Farmaco? _farmaco;
  StatoScorte? _stato;

  @override
  void initState() {
    super.initState();
    _carica();
  }

  Future<void> _carica() async {
    try {
      final repo = LocalRepository();
      await repo.init();
      final f = await repo.getFarmaco(widget.farmacoId);
      if (!mounted) return;
      setState(() {
        _farmaco = f;
        _stato = f == null ? null : statoScorte(f, DateTime.now());
      });
    } catch (_) {}
  }

  Future<void> _rifornimento() async {
    final f = _farmaco;
    if (f == null) return;
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rifornimento'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: trDeco(InputDecoration(
              labelText: 'Unità aggiunte', hintText: 'es. 30')),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annulla')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Aggiungi')),
        ],
      ),
    );
    // Il controller non si dispone qui: il dialogo sta ancora chiudendosi
    final n = double.tryParse(ctrl.text.trim().replaceAll(',', '.'));
    if (ok != true || n == null || n <= 0) return;

    final repo = LocalRepository();
    await repo.init();
    final attuale = await repo.getFarmaco(f.id);
    if (attuale == null) return;
    attuale.scorte = (attuale.scorte ?? 0) + n;
    attuale.updatedAt = DateTime.now();
    // Il piano delle notifiche non cambia: niente ricostruzione
    await repo.saveFarmaco(attuale, ricostruisciPromemoria: false);
    await _carica();
  }

  String _durata(StatoScorte s, Farmaco f) {
    if (!s.conPiano) return '';
    final g = s.giorni;
    if (g == null) {
      return f.dataFine != null
          ? tr('Bastano fino a fine terapia')
          : tr('Bastano per oltre {0} giorni', [kOrizzonteScorteGiorni]);
    }
    return g == 0
        ? tr('Scorte finite')
        : tr('Bastano per circa {0} giorni', [g]);
  }

  @override
  Widget build(BuildContext context) {
    final f = _farmaco;
    final s = _stato;
    if (f == null || s == null) return const SizedBox.shrink();

    final colore = s.inAvviso ? AppTheme.warning : AppTheme.secondary;
    final durata = _durata(s, f);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Icon(Icons.inventory_2_outlined, color: colore),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr('{0} unità rimaste', [formattaUnita(s.unita)]),
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700, color: colore)),
                if (durata.isNotEmpty)
                  Text(durata,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppTheme.textSecondaryDark)),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: _rifornimento,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Rifornimento'),
          ),
        ]),
      ),
    );
  }
}
