import 'package:flutter/material.dart';
import 'package:salute_bettin/core/theme.dart';
import 'package:salute_bettin/data/services/notification_service.dart';
import 'package:salute_bettin/data/services/settings_service.dart';

/// Impostazioni dei promemoria per visite ed esami (valide per tutti).
class PromemoriaSection extends StatefulWidget {
  const PromemoriaSection({super.key});

  @override
  State<PromemoriaSection> createState() => _PromemoriaSectionState();
}

class _PromemoriaSectionState extends State<PromemoriaSection> {
  final _s = SettingsService.instance;

  String get _oraTesto {
    final m = _s.notifOraMinuti;
    return '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';
  }

  String get _giorniTesto {
    final n = _s.notifGiorniPrima;
    return n == 0 ? 'Il giorno stesso' : n == 1 ? '1 giorno prima' : '$n giorni prima';
  }

  Future<void> _applica() async {
    await NotificationService.instance.rischedulaTutti();
    if (mounted) setState(() {});
  }

  Future<void> _toggle(bool v) async {
    await _s.setNotifAttive(v);
    if (v) await NotificationService.instance.richiediPermesso();
    await _applica();
  }

  Future<void> _scegliGiorni() async {
    final scelto = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Quando avvisarmi'),
        children: [
          for (final n in const [0, 1, 2, 3, 4, 5, 7, 10, 14])
            RadioListTile<int>(
              title: Text(n == 0
                  ? 'Il giorno stesso'
                  : n == 1
                      ? '1 giorno prima'
                      : '$n giorni prima'),
              value: n,
              groupValue: _s.notifGiorniPrima,
              activeColor: AppTheme.primary,
              onChanged: (v) => Navigator.pop(ctx, v),
            ),
        ],
      ),
    );
    if (scelto == null) return;
    await _s.setNotifGiorniPrima(scelto);
    await _applica();
  }

  Future<void> _scegliOra() async {
    final m = _s.notifOraMinuti;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: m ~/ 60, minute: m % 60),
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (t == null) return;
    await _s.setNotifOraMinuti(t.hour * 60 + t.minute);
    await _applica();
  }

  @override
  Widget build(BuildContext context) {
    final attive = _s.notifAttive;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text('Promemoria visite ed esami',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppTheme.primary, letterSpacing: 0.5)),
          ),
        ),
        SwitchListTile(
          secondary: const Icon(Icons.notifications_active_outlined),
          title: const Text('Notifica prima dell\'appuntamento'),
          subtitle: const Text('Valida per tutte le visite e gli esami'),
          value: attive,
          onChanged: _toggle,
          activeColor: AppTheme.primary,
        ),
        ListTile(
          enabled: attive,
          leading: const Icon(Icons.event_outlined),
          title: const Text('Anticipo'),
          subtitle: Text(_giorniTesto),
          onTap: attive ? _scegliGiorni : null,
        ),
        ListTile(
          enabled: attive,
          leading: const Icon(Icons.schedule),
          title: const Text('Ora della notifica'),
          subtitle: Text(_oraTesto),
          onTap: attive ? _scegliOra : null,
        ),
      ],
    );
  }
}
