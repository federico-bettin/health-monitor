import 'package:flutter/material.dart' hide Text;
import 'package:salute_bettin/core/i18n.dart';
import 'package:salute_bettin/data/models/assunzione_farmaco.dart';
import 'package:salute_bettin/data/models/farmaco.dart';
import 'package:salute_bettin/data/repositories/local_repository.dart';
import 'package:salute_bettin/data/services/farmaci_azioni_notifica.dart';
import 'package:salute_bettin/data/services/notification_service.dart';
import 'package:salute_bettin/data/services/scorte_service.dart';
import 'package:uuid/uuid.dart';

/// ID stabile per una dose prevista: evita doppioni se si tocca due volte.
String idAssunzionePrevista(String farmacoId, DateTime prevista) =>
    idDosePrevista(farmacoId, prevista);

/// Registra l'esito di una dose prevista (Preso / Salta), origine "app".
Future<void> registraDosePrevista(
    Farmaco f, DateTime prevista, StatoAssunzione stato) async {
  final repo = LocalRepository();
  await repo.init();
  final id = idAssunzionePrevista(f.id, prevista);
  final prima = await repo.getAssunzioni(
      prevista, prevista.add(const Duration(minutes: 1)));
  final eraPresa =
      prima.any((a) => a.id == id && a.stato == StatoAssunzione.presa);
  await repo.saveAssunzione(AssunzioneFarmaco(
    id: id,
    farmacoId: f.id,
    dataOraPrevista: prevista,
    dataOraRegistrata: DateTime.now(),
    statoIdx: stato.index,
    origineIdx: OrigineAssunzione.app.index,
  ));
  // Dose già gestita: se c'era un posticipo in attesa, non serve più
  try {
    final ns = NotificationService.instance;
    if (ns.pronto) await ns.plugin.cancel(idSnooze(prevista.millisecondsSinceEpoch));
  } catch (_) {}
  // Scorte: scendono solo se la dose diventa "presa" (e non lo era già)
  final presa = stato == StatoAssunzione.presa;
  if (presa && !eraPresa) await ScorteService.applica(f.id, 1);
  if (!presa && eraPresa) await ScorteService.applica(f.id, -1);
}

/// Annulla la registrazione di una dose (torna "da prendere").
/// Se era "presa", le scorte tornano su.
Future<void> annullaAssunzione(AssunzioneFarmaco a) async {
  final repo = LocalRepository();
  await repo.init();
  await repo.deleteAssunzione(a.id);
  if (a.stato == StatoAssunzione.presa) {
    await ScorteService.applica(a.farmacoId, -1);
  }
}

/// Dialog "Registra assunzione" per farmaci al bisogno: data e ora attuali,
/// modificabili. Ritorna true se è stata salvata.
Future<bool> registraAssunzioneManuale(BuildContext context, Farmaco f) async {
  var quando = DateTime.now();
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) => AlertDialog(
        title: const Text('Registra assunzione'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(f.dosaggio.trim().isEmpty ? f.nome : '${f.nome} · ${f.dosaggio}'),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today),
              title: Text(
                  '${quando.day.toString().padLeft(2, '0')}/${quando.month.toString().padLeft(2, '0')}/${quando.year}'),
              onTap: () async {
                final d = await showDatePicker(
                  context: ctx,
                  initialDate: quando,
                  firstDate: DateTime.now().subtract(const Duration(days: 60)),
                  lastDate: DateTime.now().add(const Duration(days: 1)),
                );
                if (d != null) {
                  setS(() => quando = DateTime(
                      d.year, d.month, d.day, quando.hour, quando.minute));
                }
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.schedule),
              title: Text(hhmm24(quando)),
              onTap: () async {
                final t = await showTimePicker(
                  context: ctx,
                  initialTime:
                      TimeOfDay(hour: quando.hour, minute: quando.minute),
                  builder: (c, child) => MediaQuery(
                    data: MediaQuery.of(c).copyWith(alwaysUse24HourFormat: true),
                    child: child!,
                  ),
                );
                if (t != null) {
                  setS(() => quando = DateTime(quando.year, quando.month,
                      quando.day, t.hour, t.minute));
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annulla')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Registra')),
        ],
      ),
    ),
  );
  if (ok != true) return false;

  final repo = LocalRepository();
  await repo.init();
  await repo.saveAssunzione(AssunzioneFarmaco(
    id: const Uuid().v4(),
    farmacoId: f.id,
    dataOraRegistrata: quando,
    statoIdx: StatoAssunzione.presa.index,
    origineIdx: OrigineAssunzione.manuale.index,
  ));
  await ScorteService.applica(f.id, 1);
  return true;
}

String hhmm24(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
