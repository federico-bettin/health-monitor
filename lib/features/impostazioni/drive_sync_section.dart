import 'package:flutter/material.dart';
import 'package:salute_bettin/core/theme.dart';
import 'package:salute_bettin/data/services/drive_sync_service.dart';
import 'package:salute_bettin/data/services/settings_service.dart';

/// Sync automatico (sempre attivo) dei dati e dei referti PDF su Google Drive.
class DriveSyncSection extends StatefulWidget {
  const DriveSyncSection({super.key});

  @override
  State<DriveSyncSection> createState() => _DriveSyncSectionState();
}

class _DriveSyncSectionState extends State<DriveSyncSection> {
  final _s = SettingsService.instance;
  bool _inCorso = false;

  String _fmt(DateTime u) =>
      '${u.day.toString().padLeft(2, '0')}/${u.month.toString().padLeft(2, '0')}/${u.year} '
      '${u.hour.toString().padLeft(2, '0')}:${u.minute.toString().padLeft(2, '0')}';

  String get _stato {
    final u = DateTime.tryParse(_s.driveSyncUltima ?? '');
    if (u == null) return 'Non ancora sincronizzato';
    return _s.driveSyncPending
        ? 'Modifiche in attesa di essere caricate (ultimo sync: ${_fmt(u)})'
        : 'Tutto sincronizzato (ultimo sync: ${_fmt(u)})';
  }

  Future<void> _ora() async {
    setState(() => _inCorso = true);
    final r = await DriveSyncService.instance
        .sincronizza(forza: true, interattivo: true);
    if (!mounted) return;
    setState(() => _inCorso = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: r.ok ? null : AppTheme.error,
        content: Text(r.messaggio)));
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final ok = DriveSyncService.instance.supportato;
    final esito = DriveSyncService.instance.ultimoEsito;
    final errore = DriveSyncService.instance.ultimoOk == false;

    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text('Sincronizzazione con Google Drive',
              style: t.labelLarge
                  ?.copyWith(color: AppTheme.primary, letterSpacing: 0.5)),
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: AppTheme.cardDark,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderDark)),
          child: Text(
            ok
                ? 'Il telefono è la fonte principale dei tuoi dati: esami, '
                    'visite, farmaci, calendario e referti PDF sono salvati qui. '
                    'In automatico, ogni volta che modifichi qualcosa e c\'è '
                    'connessione, una copia viene caricata nella cartella '
                    '"HealthMonitor" del tuo Google Drive (i referti PDF nella '
                    'sottocartella "referti").\n\n'
                    'Senza connessione non succede nulla di grave: le modifiche '
                    'restano sul telefono e vengono caricate appena torna la '
                    'rete. Se cambi telefono, usa "Ripristina da backup" → '
                    'Google Drive per recuperare tutto.'
                : 'La sincronizzazione con Google Drive è disponibile solo su '
                    'Android.',
            style: t.bodySmall?.copyWith(color: AppTheme.textSecondaryDark),
          ),
        ),
      ),
      if (ok) ...[
        ListTile(
          leading: Icon(
              errore ? Icons.cloud_off_outlined : Icons.cloud_done_outlined,
              color: errore ? AppTheme.error : AppTheme.secondary),
          title: Text(_stato),
          subtitle: esito != null && errore ? Text(esito) : null,
        ),
        ListTile(
          leading: _inCorso
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.sync),
          title: Text(_s.driveSyncUltima == null || errore
              ? 'Accedi e sincronizza'
              : 'Sincronizza ora'),
          subtitle: const Text(
              'Alla prima volta chiede l\'accesso al tuo account Google'),
          onTap: _inCorso ? null : _ora,
        ),
      ],
    ]);
  }
}
