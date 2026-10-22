import 'package:flutter/material.dart' hide Text;
import 'package:salute_bettin/core/i18n.dart';
import 'package:salute_bettin/core/theme.dart';
import 'package:salute_bettin/data/repositories/local_repository.dart';
import 'package:salute_bettin/data/services/farmaci_azioni_notifica.dart';
import 'package:salute_bettin/features/farmaci/scheduling/aderenza.dart';

/// Aderenza agli ultimi [kGiorniAderenza] giorni e striscia di giorni
/// completi. Con [farmacoId] vale per un solo farmaco, altrimenti per tutti.
/// Si ricarica da sola quando una notifica registra una dose; [rev] permette
/// alla pagina che la contiene di forzare un aggiornamento.
class AderenzaCard extends StatefulWidget {
  final String? farmacoId;
  final int rev;
  const AderenzaCard({super.key, this.farmacoId, this.rev = 0});

  @override
  State<AderenzaCard> createState() => _AderenzaCardState();
}

class _AderenzaCardState extends State<AderenzaCard> {
  Aderenza? _aderenza;
  int _striscia = 0;

  @override
  void initState() {
    super.initState();
    FarmaciAzioni.versione.addListener(_carica);
    _carica();
  }

  @override
  void didUpdateWidget(AderenzaCard old) {
    super.didUpdateWidget(old);
    if (old.rev != widget.rev || old.farmacoId != widget.farmacoId) _carica();
  }

  @override
  void dispose() {
    FarmaciAzioni.versione.removeListener(_carica);
    super.dispose();
  }

  Future<void> _carica() async {
    try {
      final repo = LocalRepository();
      await repo.init();
      final adesso = DateTime.now();
      final oggi = DateTime(adesso.year, adesso.month, adesso.day);
      final da = DateTime(oggi.year, oggi.month, oggi.day - kGiorniStoricoAderenza);
      final a = DateTime(oggi.year, oggi.month, oggi.day + 1);

      var farmaci = (await repo.getFarmaci()).where((f) => !f.archiviato);
      if (widget.farmacoId != null) {
        farmaci = farmaci.where((f) => f.id == widget.farmacoId);
      }
      final dosi = valutaDosi(
        farmaci: farmaci.toList(),
        assunzioni: await repo.getAssunzioni(da, a),
        da: da,
        a: a,
        adesso: adesso,
      );
      final dal = DateTime(oggi.year, oggi.month, oggi.day - kGiorniAderenza + 1);
      if (!mounted) return;
      setState(() {
        _aderenza = calcolaAderenza(dosi, dal: dal);
        _striscia = calcolaStriscia(dosi);
      });
    } catch (_) {
      // La card è un extra: se non si carica, resta nascosta
    }
  }

  Color _colore(double pct) => pct >= 90
      ? AppTheme.secondary
      : pct >= 70
          ? AppTheme.warning
          : AppTheme.error;

  @override
  Widget build(BuildContext context) {
    final ad = _aderenza;
    if (ad == null) return const SizedBox.shrink();

    final piccolo = Theme.of(context)
        .textTheme
        .bodySmall
        ?.copyWith(color: AppTheme.textSecondaryDark);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: ad.percentuale == null
            ? Text("L'aderenza terapeutica si calcola dalla prima dose che registri.",
                style: piccolo)
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr('Aderenza terapeutica (ultimi {0} giorni)', [kGiorniAderenza]),
                      style: piccolo),
                  const SizedBox(height: 6),
                  Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                    Text('${ad.percentuale!.round()}%',
                        style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w700,
                            color: _colore(ad.percentuale!))),
                    const Spacer(),
                    Icon(Icons.local_fire_department,
                        size: 22,
                        color: _striscia > 0 ? AppTheme.warning : Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                        _striscia == 0
                            ? tr('Nessuna striscia attiva')
                            : _striscia == 1
                                ? tr('1 giorno di fila')
                                : tr('{0} giorni di fila', [_striscia]),
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: _striscia > 0 ? AppTheme.warning : Colors.grey)),
                  ]),
                  const SizedBox(height: 6),
                  Text(
                      tr('{0} prese · {1} saltate · {2} non registrate',
                          [ad.prese, ad.saltate, ad.nonRegistrate]),
                      style: piccolo),
                ],
              ),
      ),
    );
  }
}
