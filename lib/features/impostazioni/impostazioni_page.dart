import 'dart:io';
import 'package:flutter/material.dart' hide Text;
import 'package:salute_bettin/core/i18n.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:salute_bettin/core/constants.dart';
import 'package:salute_bettin/core/theme.dart';
import 'package:salute_bettin/data/models/token_usage.dart';
import 'package:salute_bettin/data/repositories/local_repository.dart';
import 'package:salute_bettin/data/repositories/repository_provider.dart';
import 'package:salute_bettin/data/services/auth_service.dart';
import 'package:salute_bettin/data/services/backup_service.dart';
import 'package:salute_bettin/data/services/settings_service.dart';
import 'package:salute_bettin/features/dashboard/dashboard_page.dart';
import 'package:salute_bettin/features/esami/esami_page.dart';
import 'package:salute_bettin/features/visite/visite_page.dart';
import 'package:salute_bettin/features/farmaci/farmaci_page.dart';
import 'package:salute_bettin/features/calendario/calendario_page.dart';
import 'package:salute_bettin/features/impostazioni/promemoria_section.dart';
import 'package:salute_bettin/features/impostazioni/language_section.dart';
import 'package:salute_bettin/features/impostazioni/api_key_section.dart';
import 'package:salute_bettin/features/impostazioni/drive_sync_section.dart';
import 'package:salute_bettin/data/services/drive_sync_service.dart';

final tokenUsageProvider = FutureProvider<List<TokenUsage>>((ref) async {
  final repo = await ref.read(repositoryProvider.future);
  return repo.getTokenUsage();
});

class ImpostazioniPage extends ConsumerStatefulWidget {
  const ImpostazioniPage({super.key});

  @override
  ConsumerState<ImpostazioniPage> createState() => _ImpostazioniPageState();
}

class _ImpostazioniPageState extends ConsumerState<ImpostazioniPage> {
  late bool _biometricEnabled;
  late String _aiModel;
  bool _biometricAvailable = false;
  bool _backupInCorso = false;
  List<SlotPaziente> _slots = [];
  String? _pazienteAttivoNome;

  @override
  void initState() {
    super.initState();
    final s = SettingsService.instance;
    _biometricEnabled = s.biometricEnabled;
    _aiModel        = s.aiModel;
    _checkBiometric();
    _caricaSlots();
  }

  Future<void> _caricaSlots() async {
    final repo = LocalRepository();
    await repo.init();
    final attivo = await repo.getPaziente();

    // Auto-crea slot per il paziente corrente se non esiste ancora
    if (attivo != null) {
      final key = BackupService.slotKey(attivo.nome, attivo.cognome);
      final slots = await BackupService.instance.elencaSlot();
      final esiste = slots.any((s) => s.key == key);
      if (!esiste) {
        await BackupService.instance.salvaSlotCorrente();
        await SettingsService.instance.setSlotAttivo(key);
      }
    }

    final slots = await BackupService.instance.elencaSlot();
    if (mounted) {
      setState(() {
        _slots = slots;
        _pazienteAttivoNome = attivo != null
            ? BackupService.slotKey(attivo.nome, attivo.cognome)
            : null;
      });
    }
  }

  Future<void> _cambiaPaziente(SlotPaziente slot) async {
    if (slot.key == _pazienteAttivoNome) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cambia paziente'),
        content: Text(
          'I dati correnti verranno salvati automaticamente.\n\n'
          'Vuoi passare a ${slot.nomeCompleto}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annulla')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Cambia')),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    // Salva paziente corrente nel suo slot
    await BackupService.instance.salvaSlotCorrente();
    // Carica il nuovo
    final caricato = await BackupService.instance.caricaSlot(slot.key);
    if (!mounted) return;

    if (caricato) {
      await SettingsService.instance.setSlotAttivo(slot.key);
      ref.invalidate(contatoriProvider);
      ref.invalidate(pazienteDashboardProvider);
      ref.invalidate(esamiGraficoProvider);
      ref.invalidate(saluteAnalysisProvider);
      ref.invalidate(wearableProvider);
      ref.invalidate(wearableConfigProvider);
      ref.invalidate(esamiProvider);
      ref.invalidate(visiteProvider);
      ref.invalidate(farmaciProvider);
      ref.invalidate(appuntamentiProvider);
      await _caricaSlots();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: AppTheme.secondary,
          content: Text('Profilo cambiato: ${slot.nomeCompleto}')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          backgroundColor: AppTheme.error,
          content: Text('Errore nel caricamento del profilo.')));
    }
  }

  Future<void> _salvaNuovoPaziente() async {
    if (_slots.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Massimo 5 pazienti raggiunto.')));
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nuovo paziente'),
        content: const Text(
          'I dati correnti verranno salvati.\n\n'
          'L\'app si azzera per inserire un nuovo paziente.\n'
          'Vai su Profilo per compilare i nuovi dati.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annulla')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Procedi')),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    await BackupService.instance.salvaSlotCorrente();
    final repo = await ref.read(repositoryProvider.future);
    await repo.clear();
    await SettingsService.instance.clearAllScoreCache();
    ref.invalidate(repositoryProvider);
    ref.invalidate(contatoriProvider);
    ref.invalidate(pazienteDashboardProvider);
    ref.invalidate(esamiGraficoProvider);
    ref.invalidate(saluteAnalysisProvider);
    await _caricaSlots();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vai su Profilo per creare il nuovo paziente.')));
  }

  Future<void> _eliminaSlot(SlotPaziente slot) async {
    if (slot.key == _pazienteAttivoNome) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Non puoi eliminare il paziente attivo.')));
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Elimina profilo'),
        content: Text('Eliminare ${slot.nomeCompleto}? I dati non sono recuperabili.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annulla')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Elimina',
                  style: TextStyle(color: AppTheme.error))),
        ],
      ),
    );
    if (ok != true) return;
    await BackupService.instance.eliminaSlot(slot.key);
    await _caricaSlots();
  }

  Future<void> _checkBiometric() async {
    final available = await AuthService().isBiometricAvailable();
    if (mounted) setState(() => _biometricAvailable = available);
  }

  Future<void> _toggleBiometric(bool value) async {
    if (value) {
      final ok = await AuthService().authenticate(
          reason: 'Conferma per abilitare il blocco biometrico');
      if (!ok) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Autenticazione non riuscita.')));
        return;
      }
    }
    await SettingsService.instance.setBiometricEnabled(value);
    setState(() => _biometricEnabled = value);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(value
            ? 'Blocco biometrico attivato.'
            : 'Blocco biometrico disattivato.')));
  }

  // ─── Backup ───────────────────────────────────────────────
  Future<void> _creaBackup() async {
    // Chiede destinazione
    final dest = await _dialogDestinazioneBackup();
    if (dest == null || !mounted) return;

    setState(() => _backupInCorso = true);
    try {
      final data = await BackupService.instance.creaBackupCompleto();

      if (dest == 'locale') {
        final path = await BackupService.instance.salvaLocale(data);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            backgroundColor:
                path != null ? AppTheme.secondary : AppTheme.error,
            duration: const Duration(seconds: 6),
            content: Text(path != null
                ? 'Backup salvato:\n$path'
                : 'Errore nel salvataggio locale.')));
      } else {
        final res = await BackupService.instance.salvaDrive(data);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            backgroundColor:
                res.ok ? AppTheme.secondary : AppTheme.error,
            duration: const Duration(seconds: 6),
            content: Text(res.ok
                ? '✅ ${res.messaggio}'
                : '❌ ${res.messaggio}')));
      }
    } finally {
      if (mounted) setState(() => _backupInCorso = false);
    }
  }

  Future<void> _ripristina() async {
    final dest = await _dialogSorgenteRipristino();
    if (dest == null || !mounted) return;

    Map<String, dynamic>? data;

    if (dest == 'locale') {
      final files = await BackupService.instance.elencaBackupLocali();
      if (!mounted) return;
      if (files.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Nessun backup trovato in Documenti.')));
        return;
      }
      final scelto = await showDialog<String>(
          context: context,
          builder: (ctx) => AlertDialog(
                title: const Text('Seleziona backup'),
                content: SizedBox(
                  width: double.maxFinite,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: files.length,
                    itemBuilder: (_, i) {
                      final nome = files[i].path
                          .split('/')
                          .last
                          .split('\\')
                          .last;
                      return ListTile(
                        leading: const Icon(Icons.restore,
                            color: AppTheme.primary),
                        title: Text(nome,
                            style: const TextStyle(fontSize: 13)),
                        onTap: () =>
                            Navigator.pop(ctx, files[i].path),
                      );
                    },
                  ),
                ),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Annulla')),
                ],
              ));
      if (scelto == null) return;
      data = await BackupService.instance.caricaLocale(scelto);
    } else {
      if (!mounted) return;
      showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const AlertDialog(
                content: Row(children: [
                  CircularProgressIndicator(),
                  SizedBox(width: 16),
                  Text('Scaricando da Drive...'),
                ]),
              ));
      data = await BackupService.instance.caricaDrive();
      // Telefono nuovo: scarica anche i referti PDF mancanti
      if (data != null) {
        await DriveSyncService.instance.scaricaRefertiMancanti(data);
      }
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      if (data == null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            backgroundColor: AppTheme.error,
            content: Text(
                'Nessun backup trovato in Drive/HealthMonitor.')));
        return;
      }
    }

    if (data == null || !mounted) return;

    final ok = await BackupService.instance.ripristinaCompleto(data);
    if (!mounted) return;
    _invalidaTutti();
    await _caricaSlots();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: ok ? AppTheme.secondary : AppTheme.error,
        content: Text(ok
            ? 'Dati ripristinati con successo!'
            : 'Errore nel ripristino.')));
  }

  Future<String?> _dialogDestinazioneBackup() => showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Dove vuoi salvare?'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(
              leading: const Icon(Icons.folder, color: AppTheme.warning),
              title: const Text('Documenti (locale)'),
              subtitle: const Text('Cartella Documenti del dispositivo',
                  style: TextStyle(fontSize: 11)),
              onTap: () => Navigator.pop(ctx, 'locale'),
            ),
            ListTile(
              leading: const Icon(Icons.cloud, color: AppTheme.primary),
              title: const Text('Google Drive'),
              subtitle: const Text('Cartella HealthMonitor su Drive',
                  style: TextStyle(fontSize: 11)),
              onTap: () => Navigator.pop(ctx, 'drive'),
            ),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Annulla')),
          ],
        ),
      );

  Future<String?> _dialogSorgenteRipristino() => showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Da dove vuoi caricare?'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(
              leading: const Icon(Icons.folder, color: AppTheme.warning),
              title: const Text('Documenti (locale)'),
              subtitle: const Text('Cerca backup in cartella Documenti',
                  style: TextStyle(fontSize: 11)),
              onTap: () => Navigator.pop(ctx, 'locale'),
            ),
            ListTile(
              leading: const Icon(Icons.cloud, color: AppTheme.primary),
              title: const Text('Google Drive'),
              subtitle: const Text('Scarica da Drive/HealthMonitor',
                  style: TextStyle(fontSize: 11)),
              onTap: () => Navigator.pop(ctx, 'drive'),
            ),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Annulla')),
          ],
        ),
      );

  void _invalidaTutti() {
    ref.invalidate(repositoryProvider);
    ref.invalidate(contatoriProvider);
    ref.invalidate(pazienteDashboardProvider);
    ref.invalidate(esamiGraficoProvider);
    ref.invalidate(saluteAnalysisProvider);
    ref.invalidate(wearableProvider);
    ref.invalidate(wearableConfigProvider);
    ref.invalidate(esamiProvider);
    ref.invalidate(visiteProvider);
    ref.invalidate(farmaciProvider);
    ref.invalidate(appuntamentiProvider);
  }

  Future<void> _cambiaModello(String? modelId) async {
    if (modelId == null || modelId == _aiModel) return;
    await SettingsService.instance.setAiModel(modelId);
    setState(() => _aiModel = modelId);
    if (mounted) {
      final nome = AppConstants.aiModelli[modelId] ?? modelId;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Modello AI: $nome')));
    }
  }

  Future<void> _chiudiApp() async {
    final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text('Chiudi app'),
              content: const Text('Vuoi chiudere Health Monitor?'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Annulla')),
                TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Chiudi',
                        style: TextStyle(color: AppTheme.error))),
              ],
            ));
    if (ok == true) {
      if (Platform.isAndroid || Platform.isIOS) {
        SystemNavigator.pop();
      } else {
        exit(0);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokenAsync = ref.watch(tokenUsageProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Impostazioni')),
      body: ListView(children: [

        // ─── Pazienti ──────────────────────────────────────
        _SectionHeader(title: 'Pazienti'),
        ..._slots.map((slot) {
          final isAttivo = slot.key == _pazienteAttivoNome;
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: isAttivo
                  ? AppTheme.primary.withOpacity(0.2)
                  : AppTheme.surfaceDark,
              child: Text(
                '${slot.nome[0]}${slot.cognome.isNotEmpty ? slot.cognome[0] : ''}',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isAttivo
                        ? AppTheme.primary
                        : AppTheme.textSecondaryDark),
              ),
            ),
            title: Text(slot.nomeCompleto,
                style: TextStyle(
                    fontWeight: isAttivo
                        ? FontWeight.w700
                        : FontWeight.normal)),
            subtitle: isAttivo
                ? const Text('Attivo',
                    style: TextStyle(
                        color: AppTheme.secondary, fontSize: 11))
                : Text(
                    'Modificato ${slot.ultimaModifica.day}/'
                    '${slot.ultimaModifica.month}/'
                    '${slot.ultimaModifica.year}',
                    style: const TextStyle(fontSize: 11)),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              if (isAttivo)
                const Icon(Icons.check_circle,
                    color: AppTheme.secondary, size: 20),
              if (!isAttivo) ...[
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      size: 18, color: AppTheme.error),
                  onPressed: () => _eliminaSlot(slot),
                ),
              ],
            ]),
            onTap: isAttivo ? null : () => _cambiaPaziente(slot),
          );
        }),
        if (_slots.length < 5)
          ListTile(
            leading: const Icon(Icons.person_add_outlined,
                color: AppTheme.primary),
            title: const Text('Aggiungi paziente'),
            subtitle: Text(
                '${_slots.length}/5 profili salvati',
                style: const TextStyle(fontSize: 11)),
            onTap: _salvaNuovoPaziente,
          ),
        if (_slots.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'Nessun profilo salvato. Il paziente attuale '
              'viene salvato automaticamente al cambio.',
              style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondaryDark),
            ),
          ),

        const Divider(),

        // ─── Sicurezza ─────────────────────────────────────
        _SectionHeader(title: 'Sicurezza'),
        if (_biometricAvailable)
          SwitchListTile(
            secondary: const Icon(Icons.fingerprint),
            title: const Text('Blocco biometrico'),
            subtitle: Text(_biometricEnabled
                ? 'Richiesto all\'avvio'
                : 'Non attivo'),
            value: _biometricEnabled,
            onChanged: _toggleBiometric,
            activeColor: AppTheme.primary,
          )
        else
          const ListTile(
            leading: Icon(Icons.fingerprint,
                color: AppTheme.textSecondaryDark),
            title: Text('Blocco biometrico'),
            subtitle: Text('Non disponibile su questo dispositivo'),
            enabled: false,
          ),

        const Divider(),

        // ─── Lingua ────────────────────────────────────────
        const LanguageSection(),

        const Divider(),

        // ─── Promemoria ────────────────────────────────────
        const PromemoriaSection(),

        const Divider(),

        const ApiKeySection(),

        const Divider(),

        // ─── Modello AI ────────────────────────────────────
        _SectionHeader(title: 'Modello AI'),
        Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 4),
          child: Text(
            'Il modello viene usato per analisi documenti e health score. '
            'Haiku è più veloce ed economico; Opus più accurato.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondaryDark),
          ),
        ),
        const SizedBox(height: 4),
        ...AppConstants.aiModelli.entries.map((e) {
          final modelId  = e.key;
          final nomeUI   = e.value;
          final selected = modelId == _aiModel;
          // Badge costo
          Color badgeColor;
          String badge;
          if (modelId.contains('haiku')) {
            badgeColor = AppTheme.secondary;
            badge = '€';
          } else if (modelId.contains('opus')) {
            badgeColor = AppTheme.error;
            badge = '€€€';
          } else {
            badgeColor = AppTheme.warning;
            badge = '€€';
          }
          return RadioListTile<String>(
            value: modelId,
            groupValue: _aiModel,
            onChanged: _cambiaModello,
            activeColor: AppTheme.primary,
            title: Text(nomeUI.split('(').first.trim(),
                style: const TextStyle(fontWeight: FontWeight.w500)),
            subtitle: Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(badge,
                    style: TextStyle(
                        fontSize: 10,
                        color: badgeColor,
                        fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 6),
              Expanded(
                  child: Text(
                nomeUI.contains('(')
                    ? nomeUI.substring(nomeUI.indexOf('(') + 1,
                        nomeUI.lastIndexOf(')'))
                    : '',
                style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondaryDark),
              )),
            ]),
            secondary: selected
                ? const Icon(Icons.check_circle,
                    color: AppTheme.primary, size: 20)
                : const SizedBox(width: 20),
          );
        }),

        const Divider(),

        // ─── Token AI ──────────────────────────────────────
        _SectionHeader(title: 'Utilizzo AI'),
        tokenAsync.when(
          loading: () =>
              const ListTile(title: Text('Caricamento...')),
          error: (e, _) => ListTile(title: Text('Errore: $e')),
          data: (tokens) => _TokenCard(tokens: tokens),
        ),

        const Divider(),

        // ─── Sync Drive ────────────────────────────────────────
        const DriveSyncSection(),

        const Divider(),

        // ─── Backup ────────────────────────────────────────────
        _SectionHeader(title: 'Backup e Ripristino'),
        ListTile(
          leading: const Icon(Icons.backup, color: AppTheme.secondary),
          title: const Text('Crea backup'),
          subtitle: const Text('Tutti i pazienti in un file'),
          trailing: _backupInCorso
              ? const SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.chevron_right),
          onTap: _backupInCorso ? null : _creaBackup,
        ),
        ListTile(
          leading: const Icon(Icons.restore, color: AppTheme.primary),
          title: const Text('Ripristina da backup'),
          subtitle: const Text('Carica un backup precedente'),
          onTap: _ripristina,
        ),

        const Divider(),

        // ─── Dati ──────────────────────────────────────────
        _SectionHeader(title: 'Dati'),
        ListTile(
          leading:
              const Icon(Icons.delete_forever, color: AppTheme.error),
          title: const Text('Cancella tutti i dati',
              style: TextStyle(color: AppTheme.error)),
          subtitle: const Text('Operazione irreversibile'),
          onTap: () => _confirmReset(context),
        ),

        const Divider(),

        // ─── App ───────────────────────────────────────────
        _SectionHeader(title: 'App'),
        ListTile(
          leading: const Icon(Icons.exit_to_app,
              color: AppTheme.textSecondaryDark),
          title: const Text('Chiudi applicazione'),
          onTap: _chiudiApp,
        ),
        const SizedBox(height: 32),
      ]),
    );
  }

  /// Cancellazione di tutti i dati, con tre protezioni:
  /// 1. bisogna scrivere la parola di conferma;
  /// 2. con il blocco biometrico attivo, serve l'impronta/PIN;
  /// 3. prima si salva un backup in Download; se il backup fallisce,
  ///    non si cancella nulla.
  Future<void> _confirmReset(BuildContext context) async {
    final parola = tr('CANCELLA');
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
        final valido = ctrl.text.trim().toUpperCase() == parola.toUpperCase();
        return AlertDialog(
          title: const Text('Cancella tutti i dati'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                  "Verranno cancellati tutti i dati dell'app su questo telefono. "
                  'Prima viene salvato un backup automatico nella cartella Download.'),
              const SizedBox(height: 14),
              Text(tr('Per confermare scrivi {0}', [parola])),
              TextField(
                controller: ctrl,
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                onChanged: (_) => setS(() {}),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Annulla')),
            TextButton(
                onPressed: valido ? () => Navigator.pop(ctx, true) : null,
                child: Text('Cancella',
                    style: TextStyle(
                        color: valido ? AppTheme.error : Colors.grey))),
          ],
        );
      }),
    );
    // Il controller non si dispone qui: il dialogo sta ancora chiudendosi
    if (ok != true || !mounted) return;

    // Impronta o PIN, se il blocco è attivo
    if (SettingsService.instance.biometricEnabled) {
      final autenticato = await AuthService()
          .authenticate(reason: 'Conferma per cancellare tutti i dati');
      if (!autenticato) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Autenticazione non riuscita.')));
        }
        return;
      }
    }
    if (!mounted) return;

    setState(() => _backupInCorso = true);
    try {
      // Backup di sicurezza di tutti i pazienti, prima di toccare qualsiasi cosa
      String? percorso;
      try {
        final data = await BackupService.instance.creaBackupCompleto();
        percorso = await BackupService.instance.salvaLocale(data);
      } catch (_) {}
      if (percorso == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              backgroundColor: AppTheme.error,
              duration: const Duration(seconds: 6),
              content: Text(
                  'Backup non riuscito: i dati non sono stati cancellati.')));
        }
        return;
      }

      final repo = await ref.read(repositoryProvider.future);
      await repo.clear();
      await SettingsService.instance.clearAllScoreCache();
      ref.invalidate(repositoryProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            duration: const Duration(seconds: 10),
            content: Text(tr('Dati cancellati. Backup salvato in:\n{0}', [percorso]))));
      }
    } finally {
      if (mounted) setState(() => _backupInCorso = false);
    }
  }
}

// ─── Widgets ──────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(title,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: AppTheme.primary, letterSpacing: 0.5)));
  }
}

class _TokenCard extends StatelessWidget {
  final List<TokenUsage> tokens;
  const _TokenCard({required this.tokens});

  @override
  Widget build(BuildContext context) {
    final totIn    = tokens.fold(0, (s, t) => s + t.tokensInput);
    final totOut   = tokens.fold(0, (s, t) => s + t.tokensOutput);
    final totCosto = tokens.fold(0.0, (s, t) => s + t.costoUsd);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.primary.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: AppTheme.primary.withOpacity(0.2))),
        child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _TokenStat(label: 'Input', value: '$totIn'),
              _TokenStat(label: 'Output', value: '$totOut'),
              _TokenStat(
                  label: 'Costo',
                  value: '\$${totCosto.toStringAsFixed(4)}'),
            ])));
  }
}

class _TokenStat extends StatelessWidget {
  final String label, value;
  const _TokenStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppTheme.primary, fontWeight: FontWeight.w700)),
      Text(label, style: Theme.of(context).textTheme.bodySmall),
    ]);
  }
}
