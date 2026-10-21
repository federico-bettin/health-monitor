import 'package:flutter/material.dart' hide Text;
import 'package:permission_handler/permission_handler.dart';
import 'package:salute_bettin/core/i18n.dart';
import 'package:salute_bettin/core/theme.dart';
import 'package:salute_bettin/data/services/farmaci_reminder_service.dart';
import 'package:salute_bettin/data/services/settings_service.dart';
import 'package:salute_bettin/features/farmaci/permessi_dialog.dart';

/// Impostazioni → Promemoria dei farmaci: notifiche, privacy del testo,
/// stato dei permessi, riepilogo pianificazione, test e guida Samsung.
class PromemoriaFarmaciSection extends StatefulWidget {
  const PromemoriaFarmaciSection({super.key});

  @override
  State<PromemoriaFarmaciSection> createState() =>
      _PromemoriaFarmaciSectionState();
}

class _PromemoriaFarmaciSectionState extends State<PromemoriaFarmaciSection> {
  final _s = SettingsService.instance;
  final _svc = FarmaciReminderService.instance;
  PermessiPromemoria _permessi = const PermessiPromemoria(null, null);

  @override
  void initState() {
    super.initState();
    _aggiornaPermessi();
  }

  Future<void> _aggiornaPermessi() async {
    final p = await _svc.statoPermessi();
    if (mounted) setState(() => _permessi = p);
  }

  Future<void> _ricostruisci() async {
    await _svc.ricostruisci();
    await _aggiornaPermessi();
  }

  Future<void> _toggleNotifiche(bool v) async {
    if (v) await assicuraPermessiPromemoria(context);
    await _s.setFarmaciNotifAttive(v);
    await _ricostruisci();
  }

  Future<void> _toggleNome(bool v) async {
    await _s.setFarmaciMostraNome(v);
    await _ricostruisci();
  }

  Future<void> _consentiNotifiche() async {
    await _svc.richiediNotifiche();
    await _aggiornaPermessi();
    // Se Android non mostra più la richiesta, resta solo la schermata dell'app
    if (_permessi.notifiche != true) await openAppSettings();
  }

  String get _riepilogo {
    final n = _s.farmaciPianificati;
    if (!_s.farmaciNotifAttive) return tr('Notifiche dei farmaci spente');
    if (n == 0) return tr('Nessun promemoria pianificato');
    final fino = DateTime.tryParse(_s.farmaciPianificatiFino ?? '');
    final data = fino == null
        ? ''
        : ' (${tr('fino al')} ${fino.day.toString().padLeft(2, '0')}/${fino.month.toString().padLeft(2, '0')})';
    return '${tr('Promemoria pianificati')}: $n$data';
  }

  Widget _stato(String titolo, bool? ok, String okTesto, String koTesto,
      {VoidCallback? azione, String? azioneTesto}) {
    final colore = ok == true
        ? AppTheme.secondary
        : ok == false
            ? AppTheme.warning
            : AppTheme.textSecondaryDark;
    return ListTile(
      leading: Icon(
          ok == true ? Icons.check_circle_outline : Icons.warning_amber_rounded,
          color: colore),
      title: Text(titolo),
      subtitle: Text(ok == true ? okTesto : ok == false ? koTesto : tr('Non determinabile')),
      trailing: (ok == false && azione != null)
          ? TextButton(onPressed: azione, child: Text(azioneTesto ?? 'Consenti'))
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final attive = _s.farmaciNotifAttive;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text('Promemoria farmaci',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppTheme.primary, letterSpacing: 0.5)),
          ),
        ),
        if (!_svc.supportato)
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Le notifiche dei farmaci sono disponibili solo su Android'),
            subtitle: Text('Il piano terapeutico e la schermata Oggi funzionano comunque.'),
          )
        else ...[
          SwitchListTile(
            secondary: const Icon(Icons.medication_outlined),
            title: const Text('Notifiche dei farmaci'),
            subtitle: const Text('Avvisi agli orari del piano terapeutico'),
            value: attive,
            onChanged: _toggleNotifiche,
            activeColor: AppTheme.primary,
          ),
          SwitchListTile(
            secondary: const Icon(Icons.visibility_outlined),
            title: const Text('Mostra il nome del farmaco nella notifica'),
            subtitle: const Text(
                'Se spento, la notifica dice solo "Promemoria farmaci"'),
            value: _s.farmaciMostraNome,
            onChanged: attive ? _toggleNome : null,
            activeColor: AppTheme.primary,
          ),
          _stato(
            tr('Permesso notifiche'),
            _permessi.notifiche,
            tr('Consentite'),
            tr('Non consentite: non riceverai i promemoria'),
            azione: _consentiNotifiche,
          ),
          _stato(
            tr('Allarmi esatti'),
            _permessi.allarmiEsatti,
            tr('Consentiti'),
            tr('Non consentiti: le notifiche potrebbero arrivare con qualche minuto di ritardo'),
            azione: () async {
              await _svc.richiediAllarmiEsatti();
              await _ricostruisci();
            },
          ),
          ListTile(
            leading: const Icon(Icons.event_available_outlined),
            title: Text(_riepilogo),
            trailing: IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: tr('Ricostruisci i promemoria'),
              onPressed: _ricostruisci,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.notifications_none),
            title: const Text('Invia notifica di test'),
            subtitle: const Text('Per verificare che le notifiche arrivino'),
            onTap: () async {
              await _svc.inviaTest();
            },
          ),
          ExpansionTile(
            leading: const Icon(Icons.battery_alert_outlined),
            title: const Text('Le notifiche non arrivano? (Samsung)'),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                  "Samsung (One UI) può bloccare le app in background e far arrivare le notifiche in ritardo o per niente. Per evitarlo:"),
              const SizedBox(height: 8),
              const Text(
                  "1. Impostazioni › Applicazioni › Health Monitor › Batteria › scegli \"Senza restrizioni\"."),
              const SizedBox(height: 4),
              const Text(
                  "2. Impostazioni › Batteria › Limiti di utilizzo in background › App mai in sospensione › aggiungi Health Monitor."),
              const SizedBox(height: 4),
              const Text(
                  "3. Lascia attivi \"Notifiche\" e \"Allarmi e promemoria\" nelle autorizzazioni dell'app."),
              const SizedBox(height: 8),
              const Text(
                  "I nomi delle voci possono cambiare un po' tra le versioni di Android.",
                  style: TextStyle(
                      fontSize: 12, color: AppTheme.textSecondaryDark)),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 40)),
                  onPressed: openAppSettings,
                  icon: const Icon(Icons.settings_applications_outlined),
                  label: const Text("Apri le impostazioni dell'app"),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
