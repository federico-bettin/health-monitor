import 'package:flutter/material.dart' hide Text;
import 'package:salute_bettin/core/i18n.dart';
import 'package:salute_bettin/data/services/farmaci_reminder_service.dart';

/// Prima di attivare i promemoria: spiega perché servono le notifiche e poi
/// chiede il permesso (Android 13+). Ritorna lo stato aggiornato dei permessi.
/// Su Windows e altre piattaforme non fa nulla.
Future<PermessiPromemoria> assicuraPermessiPromemoria(BuildContext context) async {
  final svc = FarmaciReminderService.instance;
  if (!svc.supportato) return const PermessiPromemoria(null, null);
  var p = await svc.statoPermessi();
  if (p.notifiche != true && context.mounted) {
    final vai = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Notifiche per i promemoria'),
        content: const Text(
            "Per ricordarti i farmaci all'ora giusta, Health Monitor deve poter "
            'inviare notifiche. Ora Android ti chiederà il permesso.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Non ora')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Continua')),
        ],
      ),
    );
    if (vai == true) {
      await svc.richiediNotifiche();
      p = await svc.statoPermessi();
    }
  }
  return p;
}
