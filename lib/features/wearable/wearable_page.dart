import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:salute_bettin/core/theme.dart';
import 'package:salute_bettin/data/repositories/local_repository.dart';
import 'package:salute_bettin/data/services/health_service.dart';
import 'package:salute_bettin/data/services/settings_service.dart';
import 'package:health/health.dart';
import 'package:salute_bettin/features/wearable/wearable_dettaglio_page.dart';
import 'package:go_router/go_router.dart';
import 'package:salute_bettin/core/router.dart';
import 'package:salute_bettin/data/repositories/repository_provider.dart';

// ─── Provider ─────────────────────────────────────────────────

final wearableBundleProvider = FutureProvider.autoDispose<({
  WearableData data,
  bool hasPermessi,
  double? altezza,
  double? pesoProfilo,
})>((ref) async {
  final svc      = HealthService();
  final hasP     = await svc.hasPermessi();
  final repo = LocalRepository();
  await repo.init();
  final paz      = await repo.getPaziente();
  final sorgente = SettingsService.instance.stepSource;
  if (!hasP) return (
    data: const WearableData(),
    hasPermessi: false, altezza: paz?.altezza, pesoProfilo: paz?.peso,
  );
  // Solo summary recenti — veloce. Medie e serie solo su richiesta grafico.
  final data = await svc.leggiDatiRecenti(stepSource: sorgente);
  return (
    data: data,
    hasPermessi: true,
    altezza: paz?.altezza,
    pesoProfilo: paz?.peso,
  );
});

// ─── Page ─────────────────────────────────────────────────────

class WearablePage extends ConsumerWidget {
  const WearablePage({super.key});

  Future<void> _mostraSorgenti(BuildContext context, WidgetRef ref) async {
    final sorgenti = await HealthService().leggiSorgentiPassi();
    if (!context.mounted) return;
    final salvata = SettingsService.instance.stepSource;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardDark,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Sorgenti STEPS oggi',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text('Tocca la riga del ring per usarla come sorgente.',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryDark)),
          const SizedBox(height: 16),
          if (sorgenti.isEmpty)
            const Text('Nessun record trovato oggi.',
                style: TextStyle(color: AppTheme.textSecondaryDark))
          else
            ...sorgenti.entries.map((e) {
              final parts  = e.key.split('  |  ');
              final nome   = parts[0];
              final pkg    = parts.length > 1 ? parts[1] : parts[0];
              final sel    = salvata == pkg || salvata == nome;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.directions_walk,
                    color: sel ? AppTheme.secondary : AppTheme.textSecondaryDark),
                title: Text(nome, style: TextStyle(fontWeight: FontWeight.w600,
                    color: sel ? AppTheme.secondary : null)),
                subtitle: Text(pkg, style: const TextStyle(
                    fontSize: 11, color: AppTheme.textSecondaryDark)),
                trailing: Text('${e.value} passi', style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: sel ? AppTheme.secondary : AppTheme.primary)),
                onTap: () async {
                  // Salva sourceName — _filtraPassi controlla sia sourceId che sourceName
                  await SettingsService.instance.setStepSource(nome);
                  if (ctx.mounted) Navigator.pop(ctx);
                  ref.invalidate(wearableBundleProvider);
                  if (context.mounted) ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text('Sorgente: $nome')));
                },
              );
            }),
          if (salvata != null) ...[
            const Divider(),
            TextButton.icon(
              icon: const Icon(Icons.clear, size: 16),
              label: const Text('Usa default (Ring Amazfit)'),
              onPressed: () async {
                await SettingsService.instance.setStepSource(null);
                if (ctx.mounted) Navigator.pop(ctx);
                ref.invalidate(wearableBundleProvider);
              },
            ),
          ],
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  Future<void> _mostraDiagnostica(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(children: [
          CircularProgressIndicator(),
          SizedBox(width: 16),
          Text('Lettura Health Connect...'),
        ]),
      ),
    );

    final d = await HealthService().diagnostica();
    if (!context.mounted) return;
    Navigator.pop(context); // chiude loading

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardDark,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        expand: false, initialChildSize: 0.7, maxChildSize: 0.95,
        builder: (_, ctrl) => SingleChildScrollView(
          controller: ctrl,
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.bug_report_outlined, color: AppTheme.primary),
              const SizedBox(width: 8),
              const Text('Diagnostica Health Connect',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 8),
            if (d.errore != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8)),
                child: Text('Errore: ${d.errore}',
                    style: const TextStyle(color: AppTheme.error, fontSize: 12)),
              ),
              const SizedBox(height: 12),
            ],
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: d.haDati
                    ? AppTheme.secondary.withOpacity(0.1)
                    : AppTheme.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8)),
              child: Row(children: [
                Icon(d.haDati ? Icons.check_circle : Icons.warning_amber,
                    color: d.haDati ? AppTheme.secondary : AppTheme.warning,
                    size: 18),
                const SizedBox(width: 8),
                Text(d.haDati
                    ? 'Trovati ${d.totaleRecord} record negli ultimi 30 giorni'
                    : 'NESSUN DATO — Zepp non ha sincronizzato con Health Connect',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: d.haDati ? AppTheme.secondary : AppTheme.warning)),
              ]),
            ),
            const SizedBox(height: 16),
            if (d.perTipo.isEmpty)
              const Text(
                'Cosa fare:\n'
                '1. Apri app Zepp sul telefono\n'
                '2. Aspetta che sincronizzi con il ring\n'
                '3. Vai in Zepp → Profilo → Connessioni terze parti → Health Connect → abilita TUTTO\n'
                '4. Torna qui e premi 🔄',
                style: TextStyle(fontSize: 13, height: 1.8,
                    color: AppTheme.textSecondaryDark))
            else ...[
              const Text('Record per tipo:',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              ...d.perTipo.entries.map((e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(children: [
                  const Icon(Icons.circle, size: 6, color: AppTheme.primary),
                  const SizedBox(width: 8),
                  Expanded(child: Text(e.key,
                      style: const TextStyle(fontSize: 12))),
                  Text('${e.value} rec',
                      style: const TextStyle(
                          fontSize: 11, color: AppTheme.textSecondaryDark)),
                ]),
              )),
              const SizedBox(height: 16),
              const Text('Ultimi valori:',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              ...d.ultimoValPerTipo.entries.map((e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(children: [
                  const Icon(Icons.arrow_right, size: 16,
                      color: AppTheme.secondary),
                  Expanded(child: Text(e.key,
                      style: const TextStyle(fontSize: 12))),
                  Text(e.value,
                      style: const TextStyle(
                          fontSize: 11, color: AppTheme.secondary)),
                ]),
              )),
            ],
            const SizedBox(height: 24),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(wearableBundleProvider);
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: const Text('Wearable'),
        backgroundColor: AppTheme.backgroundDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(AppRoutes.dashboard),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.bug_report_outlined),
            tooltip: 'Diagnostica HC',
            onPressed: () => _mostraDiagnostica(context),
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'Sorgenti passi',
            onPressed: () => _mostraSorgenti(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(wearableBundleProvider),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrView(
            msg: '$e', onRetry: () => ref.invalidate(wearableBundleProvider)),
        data: (rec) => !rec.hasPermessi
            ? _ConnView(onConnetti: () async {
                final r = await HealthService().richiediPermessiDettaglio();
                if (r.ok) ref.invalidate(wearableBundleProvider);
                if (context.mounted) ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(
                  duration: const Duration(seconds: 10),
                  content: Text(r.ok ? 'Connesso a Health Connect!' : r.errore),
                ));
              })
            : _Body(data: rec.data),
      ),
    );
  }
}

// ─── Body ─────────────────────────────────────────────────────

class _Body extends StatelessWidget {
  final WearableData w;
  const _Body({required WearableData data}) : w = data;

  void _go(BuildContext ctx, String titolo, String unita,
      HealthDataType tipo, TipoDispositivo dispositivo,
      double? val, Color colore, {double? min, double? max, String? desc}) {
    Navigator.push(ctx, MaterialPageRoute(builder: (_) => WearableDettaglioPage(
      titolo: titolo, unita: unita,
      tipo: tipo, dispositivo: dispositivo,
      valoreAttuale: val, colore: colore,
      sogliaBassa: min, sogliaAlta: max, descrizione: desc,
    )));
  }

  @override
  Widget build(BuildContext ctx) {
    final ora = w.ultimoAggiornamento;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        if (ora != null) ...[
          Row(children: [
            const Icon(Icons.access_time, size: 12,
                color: AppTheme.textSecondaryDark),
            const SizedBox(width: 4),
            Text('Aggiornato ${ora.day}/${ora.month}  '
                '${_p(ora.hour)}:${_p(ora.minute)}',
                style: const TextStyle(
                    fontSize: 11, color: AppTheme.textSecondaryDark)),
          ]),
          const SizedBox(height: 20),
        ],

        // ══ BILANCIA ══════════════════════════════════════════
        _Hdr(icon: Icons.monitor_weight_outlined, title: 'Bilancia Amazfit'),
        const SizedBox(height: 10),

        _T(w.peso, 'Peso', 'kg', Icons.monitor_weight, AppTheme.primary,
            sub: 'Ultima misurazione',
            onTap: w.peso != null ? () => _go(ctx, 'Peso', 'kg',
                HealthDataType.WEIGHT, TipoDispositivo.bilancia,
                w.peso, AppTheme.primary) : null),

        _T(w.bmi, 'BMI', '', Icons.accessibility_new, null,
            range: w.bmi != null ? WearableNorme.bmi : null,
            sub: w.bmi != null ? WearableData.bmiCategoria(w.bmi!) : null,
            norma: '18.5 – 24.9',
            onTap: w.bmi != null ? () => _go(ctx, 'BMI', '',
                HealthDataType.WEIGHT, TipoDispositivo.bilancia,
                w.bmi, _c(w.bmi!, WearableNorme.bmi),
                min: WearableNorme.bmi.min, max: WearableNorme.bmi.max) : null),

        _T(w.massaGrassaPct, 'Massa Grassa', '%', Icons.water_drop, null,
            range: w.massaGrassaPct != null ? WearableNorme.massaGrassa : null,
            norma: '10 – 28 %',
            onTap: w.massaGrassaPct != null ? () => _go(ctx, 'Massa Grassa', '%',
                HealthDataType.BODY_FAT_PERCENTAGE, TipoDispositivo.bilancia,
                w.massaGrassaPct, _c(w.massaGrassaPct!, WearableNorme.massaGrassa),
                min: WearableNorme.massaGrassa.min, max: WearableNorme.massaGrassa.max) : null),

        _T(w.massaMuscolare, 'Massa Muscolare', 'kg', Icons.fitness_center,
            AppTheme.secondary, sub: 'Ultima misurazione',
            onTap: w.massaMuscolare != null ? () => _go(ctx, 'Massa Muscolare', 'kg',
                HealthDataType.LEAN_BODY_MASS, TipoDispositivo.bilancia,
                w.massaMuscolare, AppTheme.secondary) : null),

        _T(w.acquaCorporea, 'Acqua Corporea', '%', Icons.opacity, null,
            range: w.acquaCorporea != null ? WearableNorme.acqua : null,
            norma: '45 – 65 %',
            onTap: w.acquaCorporea != null ? () => _go(ctx, 'Acqua Corporea', '%',
                HealthDataType.BODY_WATER_MASS, TipoDispositivo.bilancia,
                w.acquaCorporea, _c(w.acquaCorporea!, WearableNorme.acqua),
                min: WearableNorme.acqua.min, max: WearableNorme.acqua.max) : null),

        // Grasso viscerale — sempre visibile (HC non lo espone ancora)
        const SizedBox(height: 20),

        // ══ RING — CARDIOVASCOLARE ════════════════════════════
        _Hdr(icon: Icons.favorite_border, title: 'Ring — Cardiovascolare'),
        const SizedBox(height: 10),

        _T(w.fcUltima, 'FC (ultima lettura)', 'bpm', Icons.favorite, null,
            range: w.fcUltima != null ? WearableNorme.fc : null,
            norma: '50 – 100 bpm',
            onTap: w.fcUltima != null ? () => _go(ctx, 'Frequenza Cardiaca', 'bpm',
                HealthDataType.HEART_RATE, TipoDispositivo.ring,
                w.fcUltima, _c(w.fcUltima!, WearableNorme.fc),
                min: WearableNorme.fc.min, max: WearableNorme.fc.max) : null),

        // Solo se disponibile da HC
        if (w.fcRiposo != null)
          _T(w.fcRiposo, 'FC Riposo', 'bpm', Icons.favorite_border, null,
              range: WearableNorme.fcRiposo, norma: '50 – 90 bpm',
              onTap: () => _go(ctx, 'FC Riposo', 'bpm',
                  HealthDataType.RESTING_HEART_RATE, TipoDispositivo.ring,
                  w.fcRiposo, _c(w.fcRiposo!, WearableNorme.fcRiposo),
                  min: WearableNorme.fcRiposo.min, max: WearableNorme.fcRiposo.max)),

        if (w.hrv != null)
          _T(w.hrv, 'HRV (RMSSD)', 'ms', Icons.monitor_heart, null,
              range: WearableNorme.hrv, norma: '20 – 80 ms',
              onTap: () => _go(ctx, 'HRV', 'ms',
                  HealthDataType.HEART_RATE_VARIABILITY_RMSSD, TipoDispositivo.ring,
                  w.hrv, _c(w.hrv!, WearableNorme.hrv),
                  min: WearableNorme.hrv.min, max: WearableNorme.hrv.max)),

        _T(w.spo2, 'SpO2', '%', Icons.air, null,
            range: w.spo2 != null ? WearableNorme.spo2 : null,
            norma: '95 – 100 %',
            onTap: w.spo2 != null ? () => _go(ctx, 'SpO2', '%',
                HealthDataType.BLOOD_OXYGEN, TipoDispositivo.ring,
                w.spo2, _c(w.spo2!, WearableNorme.spo2),
                min: WearableNorme.spo2.min, max: WearableNorme.spo2.max) : null),

        if (w.respirazione != null)
          _T(w.respirazione, 'Freq. Respiratoria', 'atti/min',
              Icons.wind_power, null,
              range: WearableNorme.respirazione, norma: '12 – 20 atti/min',
              onTap: () => _go(ctx, 'Freq. Respiratoria', 'atti/min',
                  HealthDataType.RESPIRATORY_RATE, TipoDispositivo.ring,
                  w.respirazione, _c(w.respirazione!, WearableNorme.respirazione),
                  min: WearableNorme.respirazione.min,
                  max: WearableNorme.respirazione.max)),

        const SizedBox(height: 20),

        // ══ RING — ATTIVITÀ GIORNALIERA ═══════════════════════
        _Hdr(icon: Icons.directions_walk, title: 'Ring — Attività di Oggi'),
        const SizedBox(height: 10),

        _Ts('Passi', Icons.directions_walk,
            valore: w.passiOggi != null ? _fp(w.passiOggi!) : 'N/D',
            sub: 'Sorgente ring  ·  Obiettivo 7.500',
            color: w.passiOggi != null
                ? _c(w.passiOggi!.toDouble(), WearableNorme.passi)
                : AppTheme.textSecondaryDark,
            onTap: w.passiOggi != null ? () => _go(ctx, 'Passi', 'passi',
                HealthDataType.STEPS, TipoDispositivo.ring,
                w.passiOggi!.toDouble(), _c(w.passiOggi!.toDouble(), WearableNorme.passi),
                min: WearableNorme.passi.min, max: WearableNorme.passi.max) : null),

        if (w.calorieBruciate != null)
          _T(w.calorieBruciate, 'Calorie Attive', 'kcal',
              Icons.local_fire_department, null,
              range: WearableNorme.calorie, sub: 'Media 7 giorni',
              norma: '300 – 700 kcal',
              onTap: () => _go(ctx, 'Calorie Attive', 'kcal',
                  HealthDataType.ACTIVE_ENERGY_BURNED, TipoDispositivo.ring,
                  w.calorieBruciate, _c(w.calorieBruciate!, WearableNorme.calorie),
                  min: WearableNorme.calorie.min, max: WearableNorme.calorie.max)),

        if (w.calorieTotali != null)
          _T(w.calorieTotali, 'Calorie Totali', 'kcal', Icons.whatshot, null,
              range: WearableNorme.calorieTot, sub: 'Media 7 giorni',
              norma: '1800 – 2500 kcal',
              onTap: () => _go(ctx, 'Calorie Totali', 'kcal',
                  HealthDataType.TOTAL_CALORIES_BURNED, TipoDispositivo.ring,
                  w.calorieTotali, _c(w.calorieTotali!, WearableNorme.calorieTot),
                  min: WearableNorme.calorieTot.min, max: WearableNorme.calorieTot.max)),

        const SizedBox(height: 20),

        // ══ RING — SONNO ULTIMA NOTTE ═════════════════════════
        _Hdr(icon: Icons.bedtime, title: 'Ring — Sonno Ultima Notte'),
        const SizedBox(height: 10),

        // Totale — solo se ha valore
        if (w.sonnoOre != null)
          _Ts('Sonno Totale', Icons.bedtime,
              valore: '${w.sonnoOre!.toStringAsFixed(1)} h',
              sub: 'Norma 7 – 9 ore',
              color: _c(w.sonnoOre!, WearableNorme.sonno),
              onTap: () => _go(ctx, 'Sonno Totale', 'h',
                  HealthDataType.SLEEP_ASLEEP, TipoDispositivo.ring,
                  w.sonnoOre, _c(w.sonnoOre!, WearableNorme.sonno),
                  min: WearableNorme.sonno.min, max: WearableNorme.sonno.max)),

        if (w.sonnoLettoOre != null)
          _Ts('Tempo a Letto', Icons.king_bed,
              valore: '${w.sonnoLettoOre!.toStringAsFixed(1)} h',
              sub: 'Norma 7.5 – 9.5 ore',
              color: _c(w.sonnoLettoOre!, WearableNorme.sonnoLetto),
              onTap: () => _go(ctx, 'Tempo a Letto', 'h',
                  HealthDataType.SLEEP_IN_BED, TipoDispositivo.ring,
                  w.sonnoLettoOre, _c(w.sonnoLettoOre!, WearableNorme.sonnoLetto),
                  min: WearableNorme.sonnoLetto.min, max: WearableNorme.sonnoLetto.max)),

        if (w.sonnoProfondoOre != null)
          _Ts('Sonno Profondo', Icons.nights_stay,
              valore: '${w.sonnoProfondoOre!.toStringAsFixed(1)} h',
              sub: 'Ideale 1 – 2 ore (15-25% del totale)',
              color: AppTheme.primary,
              onTap: () => _go(ctx, 'Sonno Profondo', 'h',
                  HealthDataType.SLEEP_DEEP, TipoDispositivo.ring,
                  w.sonnoProfondoOre, AppTheme.primary)),

        if (w.sonnoRemOre != null)
          _Ts('Sonno REM', Icons.psychology,
              valore: '${w.sonnoRemOre!.toStringAsFixed(1)} h',
              sub: 'Ideale 1.5 – 2 ore (20-25% del totale)',
              color: const Color(0xFF9C27B0),
              onTap: () => _go(ctx, 'Sonno REM', 'h',
                  HealthDataType.SLEEP_REM, TipoDispositivo.ring,
                  w.sonnoRemOre, const Color(0xFF9C27B0))),

        if (w.sonnoLeggeroOre != null)
          _Ts('Sonno Leggero', Icons.hotel,
              valore: '${w.sonnoLeggeroOre!.toStringAsFixed(1)} h',
              sub: 'Fase di transizione',
              color: AppTheme.secondary,
              onTap: () => _go(ctx, 'Sonno Leggero', 'h',
                  HealthDataType.SLEEP_LIGHT, TipoDispositivo.ring,
                  w.sonnoLeggeroOre, AppTheme.secondary)),

        if (w.sonnoSveglioOre != null)
          _Ts('Risvegli Notturni', Icons.wb_twilight,
              valore: '${(w.sonnoSveglioOre! * 60).toStringAsFixed(0)} min',
              sub: 'Tempo sveglio durante la notte',
              color: w.sonnoSveglioOre! > 0.5 ? AppTheme.warning : AppTheme.secondary,
              onTap: () => _go(ctx, 'Risvegli Notturni', 'h',
                  HealthDataType.SLEEP_AWAKE, TipoDispositivo.ring,
                  w.sonnoSveglioOre,
                  w.sonnoSveglioOre! > 0.5 ? AppTheme.warning : AppTheme.secondary)),

        // Messaggio se nessun dato sonno disponibile
        if (w.sonnoOre == null && w.sonnoProfondoOre == null &&
            w.sonnoRemOre == null && w.sonnoLeggeroOre == null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(children: [
              const Icon(Icons.info_outline, size: 14,
                  color: AppTheme.textSecondaryDark),
              const SizedBox(width: 8),
              Text('Nessun dato sonno disponibile',
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.textSecondaryDark)),
            ]),
          ),

        const SizedBox(height: 32),
      ]),
    );
  }

  // Tile con valore double nullable — nascosto se null
  Widget _T(double? v, String lbl, String unit, IconData icon, Color? fixedColor, {
    WearableRange? range, String? sub, String? norma, VoidCallback? onTap,
  }) {
    if (v == null) return const SizedBox.shrink(); // nasconde il campo
    final color = fixedColor ?? (range != null ? _c(v, range) : AppTheme.primary);
    final parts = [if (sub != null) sub, if (norma != null) 'Norma $norma'];
    final fmt = unit == '' || unit == 'bpm' || unit == 'ms'
        ? v.toStringAsFixed(0)
        : v.toStringAsFixed(1);
    return _Card(icon: icon, label: lbl,
        valore: '$fmt $unit'.trim(),
        sub: parts.join('  ·  '),
        color: color, onTap: onTap);
  }

  // Tile con valore già formattato
  Widget _Ts(String lbl, IconData icon, {
    required String valore, required String sub, required Color color,
    VoidCallback? onTap,
  }) => _Card(icon: icon, label: lbl, valore: valore,
      sub: sub, color: color, onTap: onTap);

  String _p(int n) => n.toString().padLeft(2, '0');
}

// ─── Card widget ──────────────────────────────────────────────

class _Card extends StatelessWidget {
  final IconData icon;
  final String label, valore, sub;
  final Color color;
  final VoidCallback? onTap;
  const _Card({required this.icon, required this.label, required this.valore,
      required this.sub, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2))),
      child: Row(children: [
        Container(width: 38, height: 38,
          decoration: BoxDecoration(color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 19, color: color)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Text(label, style: const TextStyle(
              fontSize: 12, color: AppTheme.textSecondaryDark)),
          if (sub.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(sub, style: const TextStyle(
                fontSize: 10, color: AppTheme.textSecondaryDark)),
          ],
        ])),
        Text(valore, style: TextStyle(fontSize: 16,
            fontWeight: FontWeight.w700, color: color)),
        if (onTap != null) ...[
          const SizedBox(width: 6),
          const Icon(Icons.arrow_forward_ios, size: 12,
              color: AppTheme.textSecondaryDark),
        ],
      ]),
    ),
  );
}

class _Nd extends StatelessWidget {
  final String label; final IconData icon;
  const _Nd(this.label, this.icon);
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    decoration: BoxDecoration(
      color: AppTheme.cardDark.withOpacity(0.4),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppTheme.borderDark)),
    child: Row(children: [
      Container(width: 38, height: 38,
        decoration: BoxDecoration(
            color: AppTheme.textSecondaryDark.withOpacity(0.07),
            borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, size: 19, color: AppTheme.textSecondaryDark)),
      const SizedBox(width: 14),
      Expanded(child: Text(label, style: const TextStyle(
          fontSize: 12, color: AppTheme.textSecondaryDark))),
      const Text('—', style: TextStyle(fontSize: 16,
          fontWeight: FontWeight.w600, color: AppTheme.textSecondaryDark)),
    ]),
  );
}

class _Hdr extends StatelessWidget {
  final IconData icon; final String title;
  const _Hdr({required this.icon, required this.title});
  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, size: 15, color: AppTheme.secondary),
    const SizedBox(width: 8),
    Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(
        color: AppTheme.secondary, fontWeight: FontWeight.w600)),
  ]);
}

class _ConnView extends StatelessWidget {
  final Future<void> Function() onConnetti;
  const _ConnView({required this.onConnetti});
  @override
  Widget build(BuildContext context) => Center(child: Padding(
    padding: const EdgeInsets.all(32),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.watch, size: 80, color: AppTheme.textSecondaryDark),
      const SizedBox(height: 24),
      const Text('Connetti i tuoi dispositivi',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
      const SizedBox(height: 12),
      const Text('Autorizza Health Connect per leggere i dati da bilancia e ring.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppTheme.textSecondaryDark)),
      const SizedBox(height: 32),
      ElevatedButton.icon(onPressed: onConnetti,
          icon: const Icon(Icons.link),
          label: const Text('Connetti Health Connect')),
    ]),
  ));
}

class _ErrView extends StatelessWidget {
  final String msg; final VoidCallback onRetry;
  const _ErrView({required this.msg, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(child: Column(
    mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.error_outline, size: 48, color: AppTheme.error),
      const SizedBox(height: 12),
      Text(msg, style: const TextStyle(color: AppTheme.textSecondaryDark)),
      const SizedBox(height: 16),
      ElevatedButton(onPressed: onRetry, child: const Text('Riprova')),
    ],
  ));
}

// ─── Helpers ──────────────────────────────────────────────────

Color _c(double v, WearableRange r) {
  switch (r.status(v)) {
    case RangeStatus.ok:      return AppTheme.secondary;
    case RangeStatus.warning: return AppTheme.warning;
    case RangeStatus.error:   return AppTheme.error;
  }
}

String _fp(int p) => p >= 1000 ? '${(p/1000).toStringAsFixed(1)}k' : '$p';
