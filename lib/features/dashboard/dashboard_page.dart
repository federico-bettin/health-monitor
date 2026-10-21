import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart' hide Text;
import 'package:salute_bettin/core/i18n.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:salute_bettin/core/medical_terms.dart';
import 'package:salute_bettin/core/router.dart';
import 'package:salute_bettin/core/theme.dart';
import 'package:salute_bettin/data/models/esame.dart';
import 'package:salute_bettin/data/repositories/local_repository.dart';
import 'package:salute_bettin/data/services/backup_service.dart';
import 'package:salute_bettin/data/services/claude_service.dart';
import 'package:salute_bettin/data/services/health_score_service.dart';
import 'package:salute_bettin/data/services/health_service.dart';
import 'package:salute_bettin/data/services/settings_service.dart';
import 'package:salute_bettin/features/farmaci/prossima_dose_card.dart';
import 'package:salute_bettin/features/import_documento/import_documento_page.dart';
import 'package:salute_bettin/features/statistiche/statistiche_page.dart';

String _hashDati(Map<String, dynamic> dati) {
  final str = jsonEncode(dati);
  return md5.convert(utf8.encode(str)).toString();
}

// ─── Filtra ultimo esame per tipo ─────────────────────────────
Map<String, dynamic> _ultimoPerTipo(List esami) {
  final mappa = <String, dynamic>{};
  final sorted = [...esami]
    ..sort((a, b) => (b.data as DateTime).compareTo(a.data as DateTime));
  for (final e in sorted) {
    mappa.putIfAbsent(e.tipo as String, () => e.toJson());
  }
  return mappa;
}

// ─── Filtra ultima visita per specialità ─────────────────────
Map<String, dynamic> _ultimaPerSpecialita(List visite) {
  final mappa = <String, dynamic>{};
  final sorted = [...visite]
    ..sort((a, b) => (b.data as DateTime).compareTo(a.data as DateTime));
  for (final v in sorted) {
    mappa.putIfAbsent(v.specialita as String, () => v.toJson());
  }
  return mappa;
}

// ─── Provider score ───────────────────────────────────────────
// Aggiornato SOLO:
//   - manualmente con bottone 🔄 (con dialog conferma)
//   - automaticamente dopo salvataggio nuovo esame o visita
//   - MAI per cambio dati wearable (ref.read non crea dipendenza)
final saluteAnalysisProvider =
    FutureProvider.autoDispose<SaluteAnalysis>((ref) async {
  final repo = LocalRepository();
  await repo.init();
  final settings = SettingsService.instance;

  // Score deterministico (v2): scarta i punteggi calcolati in passato dall'AI
  if (settings.scoreAlgoVersione < 2) {
    await settings.clearAllScoreCache();
    await settings.setScoreAlgoVersione(2);
  }

  final paziente = await repo.getPaziente();
  final esami = await repo.getEsami();
  final visite = await repo.getVisite();
  final farmaci = await repo.getFarmaci();

  final pazKey = paziente != null
      ? BackupService.slotKey(paziente.nome, paziente.cognome)
      : 'default';

  if (esami.isEmpty && visite.isEmpty && farmaci.isEmpty) {
    return SaluteAnalysis.vuota();
  }

  // Usa cache se disponibile — NON ricalcola automaticamente
  final cachedData = settings.cachedScoreData(pazKey);
  if (cachedData != null) {
    try {
      return SaluteAnalysis.fromJson(jsonDecode(cachedData));
    } catch (_) {}
  }

  // Nessuna cache → calcola (prima volta o dopo invalidazione da esame/visita)
  // Legge wearable senza creare dipendenza (ref.read) — non verrà ritriggato
  // dal cambio dati wearable (regola #11)
  WearableData? wearable;
  try {
    final svc      = HealthService();
    final sorgente = SettingsService.instance.stepSource;
    if (await svc.hasPermessi()) {
      wearable = await svc.leggiDati(giorni: 7, stepSource: sorgente);
    }
  } catch (_) {}

  // Passi: priorità wearable, fallback manuale profilo
  final passiGiorno =
      wearable?.passiMedi?.round() ?? paziente?.passiGiornoManuale;

  final dati = {
    'paziente': paziente?.toJson(),
    'eta': paziente?.eta,
    'bmi': paziente?.bmi,
    'bmi_categoria': paziente?.bmiCategoria,
    'peso_kg': paziente?.peso,
    'altezza_cm': paziente?.altezza,
    'allergie': paziente?.allergie ?? [],
    'patologie_croniche': paziente?.patologieCroniche ?? [],
    'anamnesi': paziente?.anamnesi ?? '',
    // ── Stile di vita ──────────────────────────────────────
    'stile_vita': {
      'fumo': paziente?.fumo ?? false,
      'sigarette_giorno':
          (paziente?.fumo ?? false) ? paziente?.sigaretteGiorno : null,
      'alcool': paziente?.alcool ?? false,
      'bicchieri_vino_giorno':
          (paziente?.alcool ?? false) ? paziente?.bicchieriGiorno : null,
      'passi_giorno': passiGiorno,
      'fonte_passi': wearable?.passiMedi != null ? 'wearable' : 'manuale',
    },
    // ── Sonno da wearable ──────────────────────────────────
    if (wearable != null && wearable.sonnoOre != null)
      'sonno_ore_notte': wearable.sonnoOre,
    // ── Ultimi esami per tipo (storico non rilevante) ──────
    'ultimi_esami_per_tipo': _ultimoPerTipo(esami).values.toList(),
    // ── Ultima visita per specialità ───────────────────────
    'ultime_visite_per_specialita':
        _ultimaPerSpecialita(visite).values.toList(),
    'farmaci_attivi':
        farmaci.where((f) => f.attivo).map((f) => f.toJson()).toList(),
  };

  final hash = _hashDati(dati);
  final r = await costruisciAnalisi(dati);
  if (r.salva) {
    await settings.saveScoreCache(
        r.analisi.score, jsonEncode(r.analisi.toJson()), hash, pazKey);
  }
  return r.analisi;
});

final contatoriProvider = FutureProvider<Map<String, int>>((ref) async {
  final repo = LocalRepository();
  await repo.init();
  return {
    'esami': (await repo.getEsami()).length,
    'visite': (await repo.getVisite()).length,
    'farmaci': (await repo.getFarmaci()).where((f) => f.attivo && !f.archiviato).length,
    'appuntamenti':
        (await repo.getAppuntamenti()).where((a) => !a.isPassato).length,
  };
});

final pazienteDashboardProvider = FutureProvider<String>((ref) async {
  final repo = LocalRepository();
  await repo.init();
  final p = await repo.getPaziente();
  return p?.nome ?? '';
});

final esamiGraficoProvider = FutureProvider<List<Esame>>((ref) async {
  final repo = LocalRepository();
  await repo.init();
  final esami = await repo.getEsami();
  esami.sort((a, b) => b.data.compareTo(a.data));
  return esami;
});

// ─── Provider wearable (legge da Health Connect) ─────────────
// Non blocca su hasPermessi — su Samsung/MIUI può restituire null o false
// anche con permessi concessi. Tenta sempre la lettura e fallisce gracefully.
final wearableProvider = FutureProvider<WearableData>((ref) async {
  final svc      = HealthService();
  final sorgente = SettingsService.instance.stepSource;
  try {
    final data = await svc.leggiDati(
      giorni: 7,
      stepSource: sorgente,
    );
    return data;
  } catch (_) {
    return const WearableData();
  }
});

Future<void> _mostraDiagnostica(BuildContext context) async {
  final diag = await HealthService().diagnostica();
  if (!context.mounted) return;
  await showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Diagnostica Health Connect (ultimi 7 giorni)'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Lettura: ${diag.ok ? "✅ OK" : "❌ ${diag.errore}"}'),
            Text('Record totali: ${diag.totaleRecord}'),
            if (diag.perTipo.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                    'Nessun dato: Zepp/Samsung Health/Fit non stanno scrivendo su Health Connect, '
                    'oppure mancano permessi per alcuni tipi.'),
              )
            else ...[
              const SizedBox(height: 8),
              const Text('Record per tipo:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              ...diag.perTipo.entries.map((e) =>
                  Text('  ${e.key}: ${e.value}'
                      '${diag.ultimoValPerTipo[e.key] != null ? " (ultimo ${diag.ultimoValPerTipo[e.key]})" : ""}')),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: const Text('Chiudi')),
      ],
    ),
  );
}

// ─── Provider wearable config ─────────────────────────────────
final wearableConfigProvider =
    FutureProvider<({bool bilancia, bool ring})>((ref) async {
  final repo = LocalRepository();
  await repo.init();
  final paziente = await repo.getPaziente();
  if (paziente == null) return (bilancia: false, ring: false);
  final key = BackupService.slotKey(paziente.nome, paziente.cognome);
  final s = SettingsService.instance;
  return (bilancia: s.usaBilancia(key), ring: s.usaRing(key));
});

// ─── Dashboard ────────────────────────────────────────────────
class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  /// Ricalcolo MANUALE — chiede conferma (ha un costo AI)
  Future<void> _ricalcolaScore(BuildContext context, WidgetRef ref) async {
    // ── 1. Dialog di conferma ──────────────────────────────
    final conferma = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.auto_awesome, color: AppTheme.primary, size: 20),
          SizedBox(width: 8),
          Text('Ricalcola Health Score'),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              ClaudeService.chiaveConfigurata
                  ? 'Il punteggio viene ricalcolato dall\'app con gli ultimi esami, '
                      'visite e i tuoi dati di stile di vita. La spiegazione è scritta '
                      'dall\'AI (Claude) e consuma token.'
                  : 'Il punteggio viene ricalcolato dall\'app con gli ultimi esami, '
                      'visite e i tuoi dati di stile di vita. Nessun costo: '
                      'senza chiave API non c\'è la spiegazione dell\'AI.',
            ),
            SizedBox(height: 12),
            Row(children: [
              Icon(Icons.info_outline,
                  size: 14, color: AppTheme.textSecondaryDark),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Il costo dipende dal modello AI selezionato in Impostazioni.',
                  style: TextStyle(
                      fontSize: 11, color: AppTheme.textSecondaryDark),
                ),
              ),
            ]),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annulla')),
          ElevatedButton.icon(
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Ricalcola'),
              onPressed: () => Navigator.pop(ctx, true)),
        ],
      ),
    );
    if (conferma != true) return;

    // ── 2. Carica dati ────────────────────────────────────
    final repo = LocalRepository();
    await repo.init();
    final settings = SettingsService.instance;
    final paziente = await repo.getPaziente();
    final esami = await repo.getEsami();
    final visite = await repo.getVisite();
    final farmaci = await repo.getFarmaci();

    // Wearable — legge il valore già in cache del provider (no nuova chiamata HC)
    final wearable = ref.read(wearableProvider).valueOrNull;

    // Passi: priorità ring (valore medio), fallback profilo manuale
    final passiGiorno =
        wearable?.passiMedi?.round() ?? paziente?.passiGiornoManuale;

    final dati = {
      'paziente': paziente?.toJson(),
      'eta': paziente?.eta,
      'bmi': paziente?.bmi,
      'bmi_categoria': paziente?.bmiCategoria,
      'peso_kg': paziente?.peso,
      'altezza_cm': paziente?.altezza,
      'allergie': paziente?.allergie ?? [],
      'patologie_croniche': paziente?.patologieCroniche ?? [],
      'anamnesi': paziente?.anamnesi ?? '',
      // ── Stile di vita ────────────────────────────────────
      'stile_vita': {
        'fumo': paziente?.fumo ?? false,
        'sigarette_giorno':
            (paziente?.fumo ?? false) ? paziente?.sigaretteGiorno : null,
        'alcool': paziente?.alcool ?? false,
        'bicchieri_vino_giorno':
            (paziente?.alcool ?? false) ? paziente?.bicchieriGiorno : null,
        'passi_giorno': passiGiorno,
        'fonte_passi': wearable?.passiMedi != null ? 'wearable' : 'manuale',
      },
      // ── Sonno da wearable ────────────────────────────────
      if (wearable != null && wearable.sonnoOre != null)
        'sonno_ore_notte': wearable.sonnoOre,
      if (wearable != null && wearable.hasDati) 'wearable': wearable.toJson(),
      // ── Ultimi esami per tipo ────────────────────────────
      'ultimi_esami_per_tipo': _ultimoPerTipo(esami).values.toList(),
      // ── Ultima visita per specialità ─────────────────────
      'ultime_visite_per_specialita':
          _ultimaPerSpecialita(visite).values.toList(),
      'farmaci_attivi':
          farmaci.where((f) => f.attivo).map((f) => f.toJson()).toList(),
    };

    // ── 3. Loading dialog ─────────────────────────────────
    if (!context.mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AlertDialog(
        content: Row(children: [
          CircularProgressIndicator(),
          SizedBox(width: 20),
          Expanded(
              child: Text('Analisi in corso...\nPuò richiedere 15–30 secondi')),
        ]),
      ),
    );

    // ── 4. Chiama Claude e salva cache ────────────────────
    try {
      final pazKey = paziente != null
          ? BackupService.slotKey(paziente.nome, paziente.cognome)
          : 'default';
      final hash = _hashDati(dati);
      final r = await costruisciAnalisi(dati);
      await settings.saveScoreCache(
          r.analisi.score, jsonEncode(r.analisi.toJson()), hash, pazKey);

      ref.invalidate(saluteAnalysisProvider);
      ref.invalidate(contatoriProvider);
      ref.invalidate(pazienteDashboardProvider);
      ref.invalidate(esamiGraficoProvider);

      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // chiudi loading
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(r.aiFallita
                ? 'Score aggiornato. Analisi AI non disponibile: riprova più tardi.'
                : '✅ Score aggiornato!')));
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // chiudi loading
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Errore: $e'),
          backgroundColor: AppTheme.error,
          duration: const Duration(seconds: 6),
        ));
      }
    }
  }

  Future<void> _chiudiApp(BuildContext context) async {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final analysisAsync = ref.watch(saluteAnalysisProvider);
    final contatoriAsync = ref.watch(contatoriProvider);
    final nomeAsync = ref.watch(pazienteDashboardProvider);
    final wearableAsync = ref.watch(wearableProvider);
    final configAsync = ref.watch(wearableConfigProvider);

    return Scaffold(
      appBar: AppBar(
        title: nomeAsync.when(
          loading: () => const Text('Health Monitor'),
          error: (_, __) => const Text('Health Monitor'),
          data: (nome) =>
              Text(nome.isNotEmpty ? 'Ciao, $nome' : 'Health Monitor'),
        ),
        actions: [
          // Ricalcola score MANUALMENTE (con dialog conferma)
          analysisAsync.when(
            loading: () => const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))),
            error: (_, __) => const SizedBox.shrink(),
            data: (_) => IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: tr('Ricalcola score'),
              onPressed: () => _ricalcolaScore(context, ref),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart),
            tooltip: tr('Statistiche visite ed esami'),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const StatistichePage()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () => context.go(AppRoutes.profilo),
          ),
          IconButton(
            icon: const Icon(Icons.power_settings_new),
            tooltip: tr('Chiudi app'),
            onPressed: () => _chiudiApp(context),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(wearableProvider);
          ref.invalidate(contatoriProvider);
          ref.invalidate(esamiGraficoProvider);
          // NON invalida saluteAnalysisProvider — score non si aggiorna
          // da pull-to-refresh né da cambio wearable
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Health Score
            analysisAsync.when(
              loading: () => const _ScoreCardLoading(),
              error: (e, _) => _ScoreCardError(
                  error: e, onRetry: () => _ricalcolaScore(context, ref)),
              data: (a) => _ScoreCard(analysis: a),
            ),
            const SizedBox(height: 16),

            // Contatori
            contatoriAsync.when(
              loading: () => const SizedBox(height: 70),
              error: (_, __) => const SizedBox.shrink(),
              data: (c) => _ContatoriRow(contatori: c),
            ),
            const SizedBox(height: 16),

            // Prossima dose (solo se c'è un piano con promemoria)
            const ProssimaDoseCard(),

            // Sezione Wearable — dati da Health Connect (qualsiasi app) oppure card "Connetti"
            configAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (config) {
                return wearableAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (w) => w.hasDati
                      ? _WearableSection(data: w)
                      : _WearableConnect(
                          onConnetti: () async {
                            final res = await HealthService()
                                .richiediPermessiDettaglio();
                            final ok = res.ok;
                            ref.invalidate(wearableProvider);
                            if (!context.mounted) return;
                            if (ok) {
                              // permessi ok ma nessun dato: mostra cosa vede Health Connect
                              await _mostraDiagnostica(context);
                              return;
                            }
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text(ok
                                  ? '✅ Permessi concessi. Se non compaiono dati, controlla che l\'app sincronizzi con Health Connect.'
                                  : '⚠️ Permessi non concessi${res.errore.isNotEmpty ? ' (${res.errore})' : ''}. '
                                      'Verifica che l\'app (Zepp, Google Fit, Samsung Health...) sincronizzi con Health Connect.'),
                              duration: const Duration(seconds: 5),
                            ));
                          },
                          onDiagnostica: () => _mostraDiagnostica(context),
                        ),
                );
              },
            ),
            const SizedBox(height: 16),

            // Grafico esami
            _GraficoEsami(),
            const SizedBox(height: 16),

            // Import
            _ImportChip(
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ImportDocumentoPage()))),
            const SizedBox(height: 16),

            // Prossimi appuntamenti
            _ProssimiAppuntamenti(),
            const SizedBox(height: 24),
          ]),
        ),
      ),
    );
  }
}

// ─── Sezione Wearable (dashboard) ─────────────────────────────
// Mostra SOLO: passi di oggi, FC ultima lettura, sonno ultima notte.
// Tap su qualsiasi tile → apre WearablePage con tutti i dettagli.
class _WearableSection extends StatelessWidget {
  final WearableData data;
  const _WearableSection({required this.data});

  @override
  Widget build(BuildContext context) {
    void goWearable() => context.go(AppRoutes.wearable);

    final passiOggi = data.passiOggi;
    final fcUltima  = data.fcUltima;
    final sonnoOre  = data.sonnoOre;

    return GestureDetector(
      onTap: goWearable,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.watch, size: 18, color: AppTheme.secondary),
          const SizedBox(width: 8),
          Text('Wearable', style: Theme.of(context).textTheme.titleMedium),
          const Spacer(),
          if (data.ultimoAggiornamento != null)
            Text(
                'Aggiornato ${data.ultimoAggiornamento!.day}/${data.ultimoAggiornamento!.month}',
                style: const TextStyle(
                    fontSize: 11, color: AppTheme.textSecondaryDark)),
          const SizedBox(width: 4),
          const Icon(Icons.arrow_forward_ios,
              size: 12, color: AppTheme.textSecondaryDark),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          // ── Passi oggi (dalle 00:00) ───────────────────────
          Expanded(child: _WearableTile(
            label: 'Passi oggi',
            value: passiOggi != null
                ? (passiOggi >= 1000
                    ? '${(passiOggi / 1000).toStringAsFixed(1)}k'
                    : '$passiOggi')
                : '—',
            icon: Icons.directions_walk,
            color: passiOggi == null
                ? AppTheme.textSecondaryDark
                : passiOggi < 5000
                    ? AppTheme.warning
                    : AppTheme.secondary,
          )),
          const SizedBox(width: 8),
          // ── FC ultima lettura ──────────────────────────────
          Expanded(child: _WearableTile(
            label: 'FC',
            value: fcUltima != null
                ? '${fcUltima.toStringAsFixed(0)} bpm'
                : '—',
            icon: Icons.favorite,
            color: fcUltima == null
                ? AppTheme.textSecondaryDark
                : (fcUltima > 100 || fcUltima < 50)
                    ? AppTheme.error
                    : AppTheme.secondary,
          )),
          const SizedBox(width: 8),
          // ── Sonno ultima notte ─────────────────────────────
          Expanded(child: _WearableTile(
            label: 'Sonno',
            value: sonnoOre != null
                ? '${sonnoOre.toStringAsFixed(1)}h'
                : '—',
            icon: Icons.bedtime,
            color: sonnoOre == null
                ? AppTheme.textSecondaryDark
                : sonnoOre < 6
                    ? AppTheme.error
                    : sonnoOre < 7
                        ? AppTheme.warning
                        : AppTheme.secondary,
          )),
        ]),
      ]),
    );
  }
}

class _WearableTile extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _WearableTile(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2))),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700, color: color),
            textAlign: TextAlign.center),
        Text(label,
            style:
                const TextStyle(fontSize: 9, color: AppTheme.textSecondaryDark),
            textAlign: TextAlign.center),
      ]),
    );
  }
}

class _WearableConnect extends StatelessWidget {
  final VoidCallback onConnetti;
  final VoidCallback? onDiagnostica;
  const _WearableConnect({required this.onConnetti, this.onDiagnostica});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: AppTheme.cardDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.borderDark)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.watch,
                size: 32, color: AppTheme.textSecondaryDark),
            const SizedBox(width: 16),
            const Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('Connetti Health Connect',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  Text('Passi, peso e altri dati da Google Fit, bilancia, anello e altre app via Health Connect',
                      style: TextStyle(
                          fontSize: 12, color: AppTheme.textSecondaryDark)),
                ])),
            ElevatedButton(
                onPressed: onConnetti,
                style: ElevatedButton.styleFrom(
                    minimumSize: Size.zero,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8)),
                child: const Text('Connetti', style: TextStyle(fontSize: 12))),
          ]),
          if (onDiagnostica != null) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: onDiagnostica,
              icon: const Icon(Icons.bug_report_outlined, size: 14),
              label:
                  const Text('Diagnostica HC', style: TextStyle(fontSize: 11)),
              style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  foregroundColor: AppTheme.textSecondaryDark),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Score Card ───────────────────────────────────────────────
class _ScoreCard extends StatelessWidget {
  final SaluteAnalysis analysis;
  const _ScoreCard({required this.analysis});

  Color get _color {
    if (analysis.score == 0) return Colors.grey;
    if (analysis.score <= 3) return AppTheme.error;
    if (analysis.score <= 5) return AppTheme.warning;
    if (analysis.score <= 7) return const Color(0xFF8BC34A);
    return AppTheme.secondary;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _mostraDettagli(context),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            gradient: LinearGradient(
                colors: [_color.withOpacity(0.7), _color],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                  color: _color.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4))
            ]),
        child: Row(children: [
          Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                  shape: BoxShape.circle, color: Colors.white.withOpacity(0.2)),
              child: Center(
                child: analysis.score == 0
                    ? const Icon(Icons.help_outline,
                        size: 36, color: Colors.white)
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                            Text('${analysis.score}',
                                style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white)),
                            const Text('/10',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.white70)),
                          ]),
              )),
          const SizedBox(width: 16),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                const Text('Health Score',
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Text(analysis.titolo,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                const Row(children: [
                  Text('Tocca per i dettagli',
                      style: TextStyle(color: Colors.white60, fontSize: 11)),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_forward_ios,
                      size: 10, color: Colors.white60),
                ]),
              ])),
        ]),
      ),
    );
  }

  void _mostraDettagli(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.cardDark,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.70,
        maxChildSize: 0.95,
        builder: (_, ctrl) => SingleChildScrollView(
          controller: ctrl,
          padding: const EdgeInsets.all(24),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Handle
            Center(
                child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: AppTheme.borderDark,
                        borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),

            // Score + titolo
            Row(children: [
              Text('${analysis.score}/10',
                  style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      color: _color)),
              const SizedBox(width: 12),
              Expanded(
                  child: Text(analysis.titolo,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w600))),
            ]),
            const SizedBox(height: 12),

            // ── Stato fisico ──────────────────────────────
            if (analysis.sommario.isNotEmpty) ...[
              _DetailSection(
                titolo: 'Stato fisico',
                color: AppTheme.primary,
                icon: Icons.person_outline,
                child: Text(analysis.sommario,
                    style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondaryDark,
                        height: 1.5)),
              ),
              const SizedBox(height: 16),
            ],

            // ── Benchmark vs media italiana ────────────────
            if (analysis.benchmark.isNotEmpty) ...[
              _DetailSection(
                titolo: 'Vs media italiana (stessa età)',
                color: const Color(0xFF7E57C2),
                icon: Icons.bar_chart,
                child: Text(analysis.benchmark,
                    style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondaryDark,
                        height: 1.5)),
              ),
              const SizedBox(height: 16),
            ],

            // ── Punti di forza ────────────────────────────
            if (analysis.puntiForza.isNotEmpty) ...[
              _InsightSection(
                  titolo: 'Punti di forza',
                  items: analysis.puntiForza,
                  color: AppTheme.secondary,
                  icon: Icons.check_circle_outline),
              const SizedBox(height: 16),
            ],

            // ── Aree di attenzione ────────────────────────
            if (analysis.areeAttenzione.isNotEmpty) ...[
              _InsightSection(
                  titolo: 'Aree di attenzione',
                  items: analysis.areeAttenzione,
                  color: AppTheme.warning,
                  icon: Icons.warning_amber_outlined),
              const SizedBox(height: 16),
            ],

            // ── 3 azioni di miglioramento ─────────────────
            if (analysis.miglioramenti.isNotEmpty) ...[
              _InsightSection(
                  titolo: 'Priorità di miglioramento',
                  items: analysis.miglioramenti,
                  color: AppTheme.primary,
                  icon: Icons.trending_up,
                  numerati: true),
              const SizedBox(height: 16),
            ],

            // ── Esami / visite consigliati ─────────────────
            if (analysis.esamiDaFare.isNotEmpty) ...[
              _InsightSection(
                  titolo: 'Esami e visite consigliati',
                  items: analysis.esamiDaFare,
                  color: const Color(0xFF26C6DA),
                  icon: Icons.medical_services_outlined),
              const SizedBox(height: 16),
            ],

            const SizedBox(height: 16),
          ]),
        ),
      ),
    );
  }
}

// ─── Sezione dettaglio generica ───────────────────────────────
class _DetailSection extends StatelessWidget {
  final String titolo;
  final Color color;
  final IconData icon;
  final Widget child;
  const _DetailSection(
      {required this.titolo,
      required this.color,
      required this.icon,
      required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(titolo,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, color: color)),
        ]),
        const SizedBox(height: 8),
        child,
      ]),
    );
  }
}

// ─── Lista insight ────────────────────────────────────────────
class _InsightSection extends StatelessWidget {
  final String titolo;
  final List<String> items;
  final Color color;
  final IconData icon;
  final bool numerati;
  const _InsightSection(
      {required this.titolo,
      required this.items,
      required this.color,
      required this.icon,
      this.numerati = false});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(titolo,
          style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w700, color: color)),
      const SizedBox(height: 8),
      ...items.asMap().entries.map((entry) {
        final i = entry.key;
        final item = entry.value;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            numerati
                ? Container(
                    width: 20,
                    height: 20,
                    margin: const EdgeInsets.only(top: 1),
                    decoration: BoxDecoration(
                        color: color.withOpacity(0.15), shape: BoxShape.circle),
                    child: Center(
                        child: Text('${i + 1}',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: color))))
                : Icon(icon, size: 15, color: color),
            const SizedBox(width: 8),
            Expanded(child: Text(item, style: const TextStyle(fontSize: 13))),
          ]),
        );
      }),
    ]);
  }
}

class _ScoreCardLoading extends StatelessWidget {
  const _ScoreCardLoading();

  @override
  Widget build(BuildContext context) {
    return Container(
        height: 110,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            color: AppTheme.cardDark,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.borderDark)),
        child: const Row(children: [
          CircularProgressIndicator(strokeWidth: 2),
          SizedBox(width: 16),
          Text('Calcolo health score...'),
        ]));
  }
}

class _ScoreCardError extends StatelessWidget {
  final VoidCallback onRetry;
  final Object? error;
  const _ScoreCardError({required this.onRetry, this.error});

  @override
  Widget build(BuildContext context) {
    if (error is ChiaveApiMancanteException) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.primary.withOpacity(0.25))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: const [
            Icon(Icons.vpn_key_outlined, color: AppTheme.primary),
            SizedBox(width: 8),
            Expanded(
                child: Text('Health Score non disponibile',
                    style: TextStyle(fontWeight: FontWeight.w600))),
          ]),
          const SizedBox(height: 8),
          const Text(
              'Il Health Score e l\'import automatico dei referti usano l\'AI di Claude. '
              'Inserisci la tua chiave API in Impostazioni per attivarli. '
              'Tutto il resto dell\'app funziona normalmente senza chiave.',
              style:
                  TextStyle(fontSize: 12, color: AppTheme.textSecondaryDark)),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => context.go(AppRoutes.impostazioni),
            icon: const Icon(Icons.settings_outlined, size: 18),
            label: const Text('Vai alle Impostazioni'),
          ),
        ]),
      );
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: AppTheme.error.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.error.withOpacity(0.2))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.error_outline, color: AppTheme.error),
          const SizedBox(width: 8),
          const Expanded(
              child: Text('Errore analisi AI',
                  style: TextStyle(fontWeight: FontWeight.w600))),
          TextButton(onPressed: onRetry, child: const Text('Riprova')),
        ]),
        if (error != null) ...[
          const SizedBox(height: 6),
          Text('$error',
              style: const TextStyle(
                  fontSize: 11, color: AppTheme.textSecondaryDark)),
        ],
      ]),
    );
  }
}

// ─── Contatori ────────────────────────────────────────────────
class _ContatoriRow extends StatelessWidget {
  final Map<String, int> contatori;
  const _ContatoriRow({required this.contatori});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      _ContCard(
          label: 'Esami',
          value: contatori['esami'] ?? 0,
          color: const Color(0xFF4CAF50),
          onTap: () => context.go(AppRoutes.esami)),
      const SizedBox(width: 8),
      _ContCard(
          label: 'Visite',
          value: contatori['visite'] ?? 0,
          color: AppTheme.primary,
          onTap: () => context.go(AppRoutes.visite)),
      const SizedBox(width: 8),
      _ContCard(
          label: 'Farmaci',
          value: contatori['farmaci'] ?? 0,
          color: AppTheme.warning,
          onTap: () => context.go(AppRoutes.farmaci)),
      const SizedBox(width: 8),
      _ContCard(
          label: 'In agenda',
          value: contatori['appuntamenti'] ?? 0,
          color: const Color(0xFF9C27B0),
          onTap: () => context.go(AppRoutes.calendario)),
    ]);
  }
}

class _ContCard extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final VoidCallback onTap;
  const _ContCard(
      {required this.label,
      required this.value,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
        child: GestureDetector(
      onTap: onTap,
      child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.2))),
          child: Column(children: [
            Text('$value',
                style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w700, color: color)),
            Text(label,
                style: const TextStyle(
                    fontSize: 11, color: AppTheme.textSecondaryDark),
                textAlign: TextAlign.center),
          ])),
    ));
  }
}

// ─── Grafico Esami ────────────────────────────────────────────
class _GraficoEsami extends ConsumerStatefulWidget {
  @override
  ConsumerState<_GraficoEsami> createState() => _GraficoEsamiState();
}

class _GraficoEsamiState extends ConsumerState<_GraficoEsami> {
  String? _valoreSelezionato;
  String? _categoriaSelezionata;

  Map<String, List<_PuntoGrafico>> _estraiValori(List<Esame> esami) {
    final map = <String, List<_PuntoGrafico>>{};
    final sorted = [...esami]..sort((a, b) => a.data.compareTo(b.data));
    for (final esame in sorted) {
      for (final v in esame.valori) {
        final valore = double.tryParse(v.valore.replaceAll(',', '.'));
        if (valore == null) continue;
        final nomeNorm = MedicalTerms.normalizza(v.nome);
        map.putIfAbsent(nomeNorm, () => []);
        map[nomeNorm]!.add(_PuntoGrafico(
          data: esame.data,
          valore: valore,
          refMin:
              double.tryParse((v.riferimentoMin ?? '').replaceAll(',', '.')),
          refMax:
              double.tryParse((v.riferimentoMax ?? '').replaceAll(',', '.')),
          unita: v.unita,
          fuoriRange: v.fuoriRange,
        ));
      }
    }
    return map;
  }

  // Categorie esami sangue — mostrate prima delle altre
  static const _categorieSangue = {
    'Lipidi', 'Glicemia', 'Emocromo', 'Fegato',
    'Reni', 'Infiammazione', 'Ferro', 'Vitamine',
    'Elettroliti', 'Tiroide', 'Coagulazione', 'Cardiaco',
  };

  List<String> _ordinaCategorie(
      Map<String, List<String>> categorie,
      Map<String, List<_PuntoGrafico>> valoriMap) {
    bool haFuori(String cat) =>
        (categorie[cat] ?? []).any((v) => (valoriMap[v] ?? []).any((p) => p.fuoriRange));

    return categorie.keys.toList()
      ..sort((a, b) {
        // 1. "Altri" sempre ultima
        if (a == 'Altri') return 1;
        if (b == 'Altri') return -1;
        // 2. Fuori range prima di in range
        final aFuori = haFuori(a) ? 0 : 1;
        final bFuori = haFuori(b) ? 0 : 1;
        if (aFuori != bFuori) return aFuori.compareTo(bFuori);
        // 3. Categorie sangue prima delle altre
        final aSangue = _categorieSangue.contains(a) ? 0 : 1;
        final bSangue = _categorieSangue.contains(b) ? 0 : 1;
        if (aSangue != bSangue) return aSangue.compareTo(bSangue);
        // 4. Alfabetico
        return a.compareTo(b);
      });
  }

  Map<String, List<String>> _raggruppaPerCategoria(
      Map<String, List<_PuntoGrafico>> map) {
    final result = <String, List<String>>{};
    for (final nome in map.keys) {
      final cat = MedicalTerms.categoria(nome);
      result.putIfAbsent(cat, () => []);
      result[cat]!.add(nome);
    }
    // Ordina: fuori range prima
    for (final cat in result.keys) {
      result[cat]!.sort((a, b) {
        final aFuori = map[a]!.any((p) => p.fuoriRange) ? 0 : 1;
        final bFuori = map[b]!.any((p) => p.fuoriRange) ? 0 : 1;
        if (aFuori != bFuori) return aFuori.compareTo(bFuori);
        return a.compareTo(b);
      });
    }
    return result;
  }

  Color _coloreValore(List<_PuntoGrafico> punti) {
    final ultimo = punti.last;
    if (!ultimo.fuoriRange) return AppTheme.secondary;
    if (ultimo.refMin == null && ultimo.refMax == null) return AppTheme.error;
    final v = ultimo.valore;
    double percentuale = 0;
    if (ultimo.refMax != null && v > ultimo.refMax!) {
      percentuale = ((v - ultimo.refMax!) / ultimo.refMax!) * 100;
    } else if (ultimo.refMin != null && v < ultimo.refMin!) {
      percentuale = ((ultimo.refMin! - v) / ultimo.refMin!) * 100;
    }
    return percentuale >= 20 ? AppTheme.error : AppTheme.warning;
  }

  @override
  Widget build(BuildContext context) {
    final esamiAsync = ref.watch(esamiGraficoProvider);
    return esamiAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (esami) {
        final valoriMap = _estraiValori(esami);
        if (valoriMap.isEmpty) return const SizedBox.shrink();
        final categorie = _raggruppaPerCategoria(valoriMap);
        final categorieKeys = _ordinaCategorie(categorie, valoriMap);
        _categoriaSelezionata ??= categorieKeys.first;
        if (!categorieKeys.contains(_categoriaSelezionata)) {
          _categoriaSelezionata = categorieKeys.first;
        }
        final valoriCategoria = categorie[_categoriaSelezionata] ?? [];
        if (_valoreSelezionato == null ||
            !valoriCategoria.contains(_valoreSelezionato)) {
          _valoreSelezionato =
              valoriCategoria.isNotEmpty ? valoriCategoria.first : null;
        }
        final punti = _valoreSelezionato != null
            ? (valoriMap[_valoreSelezionato] ?? [])
            : <_PuntoGrafico>[];

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: AppTheme.cardDark,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.borderDark)),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.show_chart, size: 18, color: AppTheme.primary),
              const SizedBox(width: 8),
              Text('Andamento esami',
                  style: Theme.of(context).textTheme.titleMedium),
            ]),
            const SizedBox(height: 12),
            Text('Categoria',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppTheme.textSecondaryDark, fontSize: 11)),
            const SizedBox(height: 6),
            SizedBox(
                height: 34,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: categorieKeys.length,
                  itemBuilder: (ctx, i) {
                    final cat = categorieKeys[i];
                    final isSelected = cat == _categoriaSelezionata;
                    final haFuori = (categorie[cat] ?? [])
                        .any((v) => valoriMap[v]!.any((p) => p.fuoriRange));
                    return GestureDetector(
                      onTap: () => setState(() {
                        _categoriaSelezionata = cat;
                        final vals = categorie[cat] ?? [];
                        _valoreSelezionato =
                            vals.isNotEmpty ? vals.first : null;
                      }),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                            color: isSelected
                                ? AppTheme.primary.withOpacity(0.2)
                                : AppTheme.surfaceDark,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: isSelected
                                    ? AppTheme.primary
                                    : AppTheme.borderDark)),
                        child: Row(children: [
                          if (haFuori) ...[
                            const Icon(Icons.warning_amber,
                                size: 10, color: AppTheme.warning),
                            const SizedBox(width: 3),
                          ],
                          Text(cat,
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: isSelected
                                      ? AppTheme.primary
                                      : AppTheme.textSecondaryDark)),
                        ]),
                      ),
                    );
                  },
                )),
            const SizedBox(height: 10),
            if (valoriCategoria.isNotEmpty) ...[
              Text('Valore',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AppTheme.textSecondaryDark, fontSize: 11)),
              const SizedBox(height: 6),
              SizedBox(
                  height: 34,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: valoriCategoria.length,
                    itemBuilder: (ctx, i) {
                      final nome = valoriCategoria[i];
                      final isSelected = nome == _valoreSelezionato;
                      final puntiV = valoriMap[nome] ?? [];
                      final colore = _coloreValore(puntiV);
                      return GestureDetector(
                        onTap: () => setState(() => _valoreSelezionato = nome),
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                              color: isSelected
                                  ? colore.withOpacity(0.2)
                                  : AppTheme.surfaceDark,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: isSelected
                                      ? colore
                                      : AppTheme.borderDark)),
                          child: Row(children: [
                            Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                    color: colore, shape: BoxShape.circle)),
                            const SizedBox(width: 5),
                            Text(nome,
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: isSelected
                                        ? colore
                                        : AppTheme.textSecondaryDark)),
                          ]),
                        ),
                      );
                    },
                  )),
              const SizedBox(height: 14),
            ],
            if (punti.length >= 2)
              GestureDetector(
                onTap: () =>
                    _apriDettaglio(context, _valoreSelezionato!, punti),
                child: Stack(children: [
                  _LineChart(
                      punti: punti,
                      coloreLinea: _valoreSelezionato != null
                          ? _coloreValore(punti)
                          : AppTheme.primary),
                  // Overlay trasparente: cattura il tap su Windows dove
                  // fl_chart consuma i pointer events prima del GestureDetector
                  Positioned.fill(
                    child: GestureDetector(
                      onTap: () =>
                          _apriDettaglio(context, _valoreSelezionato!, punti),
                      behavior: HitTestBehavior.translucent,
                      child: const SizedBox.expand(),
                    ),
                  ),
                ]),
              )
            else if (_valoreSelezionato != null)
              Center(
                  child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: punti.length == 1
                    ? Column(children: [
                        Text(
                            '${punti.first.valore.toStringAsFixed(2)} ${punti.first.unita ?? ""}',
                            style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: _coloreValore(punti))),
                        Text(
                            '${punti.first.data.day}/${punti.first.data.month}/${punti.first.data.year}',
                            style: const TextStyle(
                                color: AppTheme.textSecondaryDark,
                                fontSize: 11)),
                      ])
                    : Text('Nessun dato',
                        style: TextStyle(
                            color: AppTheme.textSecondaryDark, fontSize: 12)),
              )),
          ]),
        );
      },
    );
  }

  void _apriDettaglio(
      BuildContext context, String nome, List<_PuntoGrafico> punti) {
    final colore = _coloreValore(punti);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.cardDark,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.95,
        builder: (_, ctrl) => SingleChildScrollView(
          controller: ctrl,
          padding: const EdgeInsets.all(20),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(
                child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: AppTheme.borderDark,
                        borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Row(children: [
              Container(
                  width: 12,
                  height: 12,
                  decoration:
                      BoxDecoration(color: colore, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(nome,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700))),
            ]),
            const SizedBox(height: 16),
            if (punti.length >= 2)
              _LineChart(punti: punti, coloreLinea: colore, altezza: 220),
            const SizedBox(height: 16),
            ...punti.reversed.map((p) {
              final fuori = p.fuoriRange;
              Color pctColor = colore;
              double? pct;
              if (fuori) {
                if (p.refMax != null && p.valore > p.refMax!) {
                  pct = ((p.valore - p.refMax!) / p.refMax!) * 100;
                  pctColor = pct >= 20 ? AppTheme.error : AppTheme.warning;
                } else if (p.refMin != null && p.valore < p.refMin!) {
                  pct = ((p.refMin! - p.valore) / p.refMin!) * 100;
                  pctColor = pct >= 20 ? AppTheme.error : AppTheme.warning;
                } else {
                  pctColor = AppTheme.error;
                }
              }
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                    color: fuori
                        ? pctColor.withOpacity(0.06)
                        : AppTheme.surfaceDark,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: fuori
                            ? pctColor.withOpacity(0.3)
                            : AppTheme.borderDark)),
                child: Row(children: [
                  Icon(fuori ? Icons.warning_amber : Icons.check_circle_outline,
                      size: 16, color: fuori ? pctColor : AppTheme.secondary),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Text(
                          '${p.data.day}/${p.data.month}/${p.data.year}',
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondaryDark))),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('${p.valore.toStringAsFixed(2)} ${p.unita ?? ""}',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color:
                                fuori ? pctColor : AppTheme.textPrimaryDark)),
                    if (pct != null)
                      Text('+${pct.toStringAsFixed(1)}% dal range',
                          style: TextStyle(fontSize: 10, color: pctColor)),
                  ]),
                ]),
              );
            }),
            const SizedBox(height: 32),
          ]),
        ),
      ),
    );
  }
}

class _PuntoGrafico {
  final DateTime data;
  final double valore;
  final double? refMin, refMax;
  final String? unita;
  final bool fuoriRange;
  _PuntoGrafico(
      {required this.data,
      required this.valore,
      this.refMin,
      this.refMax,
      this.unita,
      required this.fuoriRange});
}

class _LineChart extends StatelessWidget {
  final List<_PuntoGrafico> punti;
  final double altezza;
  final Color coloreLinea;
  const _LineChart(
      {required this.punti,
      this.altezza = 180,
      this.coloreLinea = AppTheme.primary});

  @override
  Widget build(BuildContext context) {
    final valori = punti.map((p) => p.valore).toList();
    final minV = valori.reduce(min);
    final maxV = valori.reduce(max);
    final refMin = punti.first.refMin;
    final refMax = punti.first.refMax;
    final unita = punti.first.unita ?? '';
    double minY = refMin != null ? min(minV, refMin) * 0.9 : minV * 0.9;
    double maxY = refMax != null ? max(maxV, refMax) * 1.1 : maxV * 1.1;
    if (minY == maxY) {
      minY -= 1;
      maxY += 1;
    }
    final spots = punti
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.valore))
        .toList();

    return SizedBox(
        height: altezza,
        child: LineChart(LineChartData(
          minY: minY,
          maxY: maxY,
          gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (_) =>
                  FlLine(color: AppTheme.borderDark, strokeWidth: 0.5)),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
                sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 44,
                    getTitlesWidget: (v, _) => Text(v.toStringAsFixed(1),
                        style: const TextStyle(
                            fontSize: 10, color: AppTheme.textSecondaryDark)))),
            bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    getTitlesWidget: (v, _) {
                      final i = v.toInt();
                      if (i < 0 || i >= punti.length) {
                        return const SizedBox.shrink();
                      }
                      final d = punti[i].data;
                      return Text('${d.day}/${d.month}',
                          style: const TextStyle(
                              fontSize: 9, color: AppTheme.textSecondaryDark));
                    })),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          extraLinesData: ExtraLinesData(horizontalLines: [
            if (refMin != null)
              HorizontalLine(
                  y: refMin,
                  color: AppTheme.secondary.withOpacity(0.5),
                  strokeWidth: 1,
                  dashArray: [4, 4],
                  label: HorizontalLineLabel(
                      show: true,
                      labelResolver: (_) => 'min',
                      style: const TextStyle(
                          fontSize: 9, color: AppTheme.secondary))),
            if (refMax != null)
              HorizontalLine(
                  y: refMax,
                  color: AppTheme.secondary.withOpacity(0.5),
                  strokeWidth: 1,
                  dashArray: [4, 4],
                  label: HorizontalLineLabel(
                      show: true,
                      labelResolver: (_) => 'max',
                      style: const TextStyle(
                          fontSize: 9, color: AppTheme.secondary))),
          ]),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.3,
              color: coloreLinea,
              barWidth: 2.5,
              dotData: FlDotData(
                  show: true,
                  getDotPainter: (spot, _, __, i) {
                    final fuori = i < punti.length && punti[i].fuoriRange;
                    return FlDotCirclePainter(
                        radius: 4,
                        color: fuori ? AppTheme.error : coloreLinea,
                        strokeWidth: 2,
                        strokeColor: AppTheme.backgroundDark);
                  }),
              belowBarData:
                  BarAreaData(show: true, color: coloreLinea.withOpacity(0.08)),
            )
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (_) => AppTheme.surfaceDark,
                getTooltipItems: (spots) => spots.map((s) {
                      final i = s.spotIndex;
                      if (i >= punti.length) return null;
                      return LineTooltipItem(
                          '${s.y.toStringAsFixed(2)} $unita',
                          const TextStyle(
                              color: AppTheme.textPrimaryDark, fontSize: 12));
                    }).toList()),
          ),
        )));
  }
}

// ─── Import Chip ──────────────────────────────────────────────
class _ImportChip extends StatelessWidget {
  final VoidCallback onTap;
  const _ImportChip({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
              border: Border.all(color: AppTheme.primary.withOpacity(0.5)),
              borderRadius: BorderRadius.circular(20)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.document_scanner, size: 16, color: AppTheme.primary),
            const SizedBox(width: 8),
            Text('Importa documento',
                style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w500)),
          ]),
        ),
      ),
    );
  }
}

// ─── Prossimi Appuntamenti ────────────────────────────────────
class _ProssimiAppuntamenti extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder(
      future: () async {
        final repo = LocalRepository();
        await repo.init();
        final list = await repo.getAppuntamenti();
        return list.where((a) => !a.isPassato).take(3).toList()
          ..sort((a, b) => a.data.compareTo(b.data));
      }(),
      builder: (context, snap) {
        if (!snap.hasData || snap.data!.isEmpty) {
          return const SizedBox.shrink();
        }
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('In agenda', style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            TextButton(
                onPressed: () => context.go(AppRoutes.calendario),
                child: const Text('Tutti')),
          ]),
          ...snap.data!.map((a) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                    dense: true,
                    leading: const Icon(Icons.event, color: Color(0xFF9C27B0)),
                    title: Text(a.titolo),
                    subtitle:
                        Text('${a.data.day}/${a.data.month}/${a.data.year}'
                            '${a.ora != null ? " · ${a.ora}" : ""}')),
              )),
        ]);
      },
    );
  }
}
