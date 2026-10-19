import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart' hide Text;
import 'package:salute_bettin/core/i18n.dart';
import 'package:health/health.dart';
import 'package:intl/intl.dart';
import 'package:salute_bettin/core/theme.dart';
import 'package:salute_bettin/data/services/health_service.dart';
import 'package:salute_bettin/data/services/settings_service.dart';

// ─── Tipi ─────────────────────────────────────────────────────

enum TipoDispositivo { bilancia, ring }

enum _PeriodoBilancia {
  gg30('30 giorni', 30),
  anno1('1 anno', 365),
  tutto('Tutti', 1825);

  final String label;
  final int giorni;
  const _PeriodoBilancia(this.label, this.giorni);
}

enum _PeriodoRing { ore24('24 ore'), gg30('30 giorni');
  final String label;
  const _PeriodoRing(this.label);
}

// ─── Page ─────────────────────────────────────────────────────

class WearableDettaglioPage extends StatefulWidget {
  final String titolo;
  final String unita;
  final HealthDataType tipo;
  final TipoDispositivo dispositivo;
  final double? valoreAttuale;
  final Color colore;
  final double? sogliaBassa;
  final double? sogliaAlta;
  final String? descrizione;

  const WearableDettaglioPage({
    super.key,
    required this.titolo,
    required this.unita,
    required this.tipo,
    required this.dispositivo,
    this.valoreAttuale,
    required this.colore,
    this.sogliaBassa,
    this.sogliaAlta,
    this.descrizione,
  });

  @override
  State<WearableDettaglioPage> createState() => _WearableDettaglioPageState();
}

class _WearableDettaglioPageState extends State<WearableDettaglioPage> {
  _PeriodoBilancia _periodoB = _PeriodoBilancia.gg30;
  _PeriodoRing     _periodoR = _PeriodoRing.ore24;

  List<WearablePoint> _serie = [];
  bool _loading = true;
  String? _errore;

  @override
  void initState() {
    super.initState();
    _carica();
  }

  bool get _isSonno =>
      widget.tipo == HealthDataType.SLEEP_DEEP ||
      widget.tipo == HealthDataType.SLEEP_REM  ||
      widget.tipo == HealthDataType.SLEEP_LIGHT ||
      widget.tipo == HealthDataType.SLEEP_ASLEEP;

  Future<void> _carica() async {
    setState(() { _loading = true; _errore = null; });
    try {
      final svc      = HealthService();
      final sorgente = SettingsService.instance.stepSource;
      List<WearablePoint> nuova;

      if (widget.dispositivo == TipoDispositivo.bilancia) {
        nuova = await svc.leggiSerieBilancia(
            widget.tipo, giorni: _periodoB.giorni);
      } else {
        if (_isSonno) {
          nuova = await svc.leggiSerieRing30gg(widget.tipo);
        } else if (widget.tipo == HealthDataType.STEPS) {
          nuova = _periodoR == _PeriodoRing.ore24
              ? await svc.leggiPassi24h(stepSource: sorgente)
              : await svc.leggiPassi30gg(stepSource: sorgente);
        } else {
          nuova = _periodoR == _PeriodoRing.ore24
              ? await svc.leggiSerieRing24h(widget.tipo, stepSource: sorgente)
              : await svc.leggiSerieRing30gg(widget.tipo, stepSource: sorgente);
        }
      }
      if (mounted) setState(() { _serie = nuova; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _errore = '$e'; _loading = false; });
    }
  }

  void _setPeriodoB(_PeriodoBilancia p) {
    if (_periodoB == p) return;
    setState(() => _periodoB = p);
    _carica();
  }

  void _setPeriodoR(_PeriodoRing p) {
    if (_periodoR == p) return;
    setState(() => _periodoR = p);
    _carica();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: Text(widget.titolo),
        backgroundColor: AppTheme.backgroundDark,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _carica,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── Valore attuale ────────────────────────────────
          if (widget.valoreAttuale != null)
            _ValoreCard(
              valore: widget.valoreAttuale!,
              unita: widget.unita,
              colore: widget.colore,
              descrizione: widget.descrizione,
              sogliaBassa: widget.sogliaBassa,
              sogliaAlta: widget.sogliaAlta,
            ),

          const SizedBox(height: 20),

          // ── Selettore periodo ─────────────────────────────
          if (widget.dispositivo == TipoDispositivo.bilancia)
            _SelectoreBilancia(
                selected: _periodoB, onChange: _setPeriodoB)
          else if (!_isSonno)
            _SelettoreeRing(
                selected: _periodoR, onChange: _setPeriodoR),

          const SizedBox(height: 16),

          // ── Grafico ───────────────────────────────────────
          if (_loading)
            const SizedBox(
              height: 240,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_errore != null)
            SizedBox(
              height: 100,
              child: Center(child: Text('Errore: $_errore',
                  style: const TextStyle(color: AppTheme.error))),
            )
          else if (_serie.isEmpty)
            const SizedBox(
              height: 120,
              child: Center(child: Text('Nessun dato nel periodo selezionato',
                  style: TextStyle(color: AppTheme.textSecondaryDark))),
            )
          else
            _Grafico(
              serie: _serie,
              colore: widget.colore,
              unita: widget.unita,
              sogliaBassa: widget.sogliaBassa,
              sogliaAlta: widget.sogliaAlta,
              isBilancia: widget.dispositivo == TipoDispositivo.bilancia,
              is24h: !_isSonno &&
                  widget.dispositivo == TipoDispositivo.ring &&
                  _periodoR == _PeriodoRing.ore24,
            ),

          const SizedBox(height: 24),

          // ── Lista letture ─────────────────────────────────
          if (!_loading && _serie.isNotEmpty) ...[
            Text('Letture (${_serie.length})',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            ..._serie.reversed.map((p) => _RigaLettura(
              punto: p,
              unita: widget.unita,
              colore: widget.colore,
              sogliaBassa: widget.sogliaBassa,
              sogliaAlta: widget.sogliaAlta,
              is24h: !_isSonno &&
                  widget.dispositivo == TipoDispositivo.ring &&
                  _periodoR == _PeriodoRing.ore24,
            )),
          ],

          const SizedBox(height: 40),
        ]),
      ),
    );
  }
}

// ─── Valore card ──────────────────────────────────────────────

class _ValoreCard extends StatelessWidget {
  final double valore;
  final String unita;
  final Color colore;
  final String? descrizione;
  final double? sogliaBassa, sogliaAlta;

  const _ValoreCard({required this.valore, required this.unita,
      required this.colore, this.descrizione, this.sogliaBassa, this.sogliaAlta});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colore.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colore.withOpacity(0.3))),
      child: Row(children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Valore attuale',
              style: const TextStyle(fontSize: 12,
                  color: AppTheme.textSecondaryDark)),
          const SizedBox(height: 4),
          Text('${valore.toStringAsFixed(valore < 100 ? 1 : 0)} $unita',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800,
                  color: colore)),
          if (descrizione != null) ...[
            const SizedBox(height: 4),
            Text(descrizione!, style: const TextStyle(
                fontSize: 12, color: AppTheme.textSecondaryDark)),
          ],
        ]),
        const Spacer(),
        if (sogliaBassa != null || sogliaAlta != null)
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            const Text('Norma', style: TextStyle(fontSize: 11,
                color: AppTheme.textSecondaryDark)),
            Text(
                '${sogliaBassa?.toStringAsFixed(1) ?? "?"} – '
                '${sogliaAlta?.toStringAsFixed(1) ?? "?"} $unita',
                style: const TextStyle(fontSize: 13,
                    color: AppTheme.secondary, fontWeight: FontWeight.w600)),
          ]),
      ]),
    );
  }
}

// ─── Selettori periodo ────────────────────────────────────────

class _SelectoreBilancia extends StatelessWidget {
  final _PeriodoBilancia selected;
  final void Function(_PeriodoBilancia) onChange;
  const _SelectoreBilancia({required this.selected, required this.onChange});

  @override
  Widget build(BuildContext context) => Row(
    children: _PeriodoBilancia.values.map((p) {
      final sel = p == selected;
      return Expanded(child: GestureDetector(
        onTap: () => onChange(p),
        child: Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: sel ? AppTheme.primary.withOpacity(0.15) : AppTheme.surfaceDark,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: sel ? AppTheme.primary : AppTheme.borderDark)),
          child: Text(p.label, textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                  color: sel ? AppTheme.primary : AppTheme.textSecondaryDark)),
        ),
      ));
    }).toList(),
  );
}

class _SelettoreeRing extends StatelessWidget {
  final _PeriodoRing selected;
  final void Function(_PeriodoRing) onChange;
  const _SelettoreeRing({required this.selected, required this.onChange});

  @override
  Widget build(BuildContext context) => Row(
    children: _PeriodoRing.values.map((p) {
      final sel = p == selected;
      return Expanded(child: GestureDetector(
        onTap: () => onChange(p),
        child: Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: sel ? AppTheme.secondary.withOpacity(0.15) : AppTheme.surfaceDark,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: sel ? AppTheme.secondary : AppTheme.borderDark)),
          child: Text(p.label, textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                  color: sel ? AppTheme.secondary : AppTheme.textSecondaryDark)),
        ),
      ));
    }).toList(),
  );
}

// ─── Grafico ──────────────────────────────────────────────────

class _Grafico extends StatelessWidget {
  final List<WearablePoint> serie;
  final Color colore;
  final String unita;
  final double? sogliaBassa, sogliaAlta;
  final bool isBilancia;
  final bool is24h;

  const _Grafico({required this.serie, required this.colore,
      required this.unita, this.sogliaBassa, this.sogliaAlta,
      required this.isBilancia, required this.is24h});

  @override
  Widget build(BuildContext context) {
    final valori = serie.map((p) => p.valore).toList();
    double minV  = valori.reduce(min);
    double maxV  = valori.reduce(max);
    if (sogliaBassa != null) minV = min(minV, sogliaBassa!);
    if (sogliaAlta  != null) maxV = max(maxV, sogliaAlta!);
    final padding = (maxV - minV) * 0.1 + 1;
    final minY = minV - padding;
    final maxY = maxV + padding;

    final spots = serie.asMap().entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.valore))
        .toList();

    return SizedBox(
      height: 240,
      child: LineChart(LineChartData(
        minY: minY, maxY: maxY,
        clipData: const FlClipData.all(),
        gridData: FlGridData(
          show: true, drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(
              color: AppTheme.borderDark, strokeWidth: 0.5)),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(sideTitles: SideTitles(
            showTitles: true, reservedSize: 46,
            getTitlesWidget: (v, _) => Text(
                v.toStringAsFixed(maxV > 100 ? 0 : 1),
                style: const TextStyle(fontSize: 9,
                    color: AppTheme.textSecondaryDark)),
          )),
          bottomTitles: AxisTitles(sideTitles: SideTitles(
            showTitles: true, reservedSize: 28,
            interval: _intervalloX(serie.length),
            getTitlesWidget: (v, _) {
              final i = v.toInt();
              if (i < 0 || i >= serie.length) return const SizedBox.shrink();
              final d = serie[i].data;
              String label;
              if (is24h) {
                label = DateFormat('HH:mm').format(d);
              } else if (isBilancia) {
                label = DateFormat('dd/MM').format(d);
              } else {
                label = DateFormat('dd/MM').format(d);
              }
              return Transform.rotate(
                angle: -0.5,
                child: Text(label, style: const TextStyle(
                    fontSize: 8, color: AppTheme.textSecondaryDark)),
              );
            },
          )),
          rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
        ),
        extraLinesData: ExtraLinesData(horizontalLines: [
          if (sogliaBassa != null)
            HorizontalLine(y: sogliaBassa!,
                color: AppTheme.secondary.withOpacity(0.5),
                strokeWidth: 1, dashArray: [4, 4],
                label: HorizontalLineLabel(show: true,
                    labelResolver: (_) => 'min',
                    style: const TextStyle(fontSize: 9,
                        color: AppTheme.secondary))),
          if (sogliaAlta != null)
            HorizontalLine(y: sogliaAlta!,
                color: AppTheme.secondary.withOpacity(0.5),
                strokeWidth: 1, dashArray: [4, 4],
                label: HorizontalLineLabel(show: true,
                    labelResolver: (_) => 'max',
                    style: const TextStyle(fontSize: 9,
                        color: AppTheme.secondary))),
        ]),
        lineBarsData: [LineChartBarData(
          spots: spots, isCurved: !is24h, curveSmoothness: 0.3,
          color: colore, barWidth: 2,
          dotData: FlDotData(
            show: serie.length <= 50,
            getDotPainter: (spot, _, __, i) {
              final fuori = i < serie.length && _fuoriRange(serie[i].valore);
              return FlDotCirclePainter(
                radius: serie.length <= 10 ? 4 : 2.5,
                color: fuori ? AppTheme.error : colore,
                strokeWidth: 1.5,
                strokeColor: AppTheme.backgroundDark);
            }),
          belowBarData: BarAreaData(
              show: true, color: colore.withOpacity(0.06)),
        )],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => AppTheme.surfaceDark,
            getTooltipItems: (spots) => spots.map((s) {
              final i = s.spotIndex;
              if (i >= serie.length) return null;
              final d   = serie[i].data;
              final fmt = is24h
                  ? DateFormat('HH:mm').format(d)
                  : DateFormat('dd/MM/yy').format(d);
              return LineTooltipItem(
                  '$fmt\n${s.y.toStringAsFixed(1)} $unita',
                  TextStyle(color: colore, fontSize: 11,
                      fontWeight: FontWeight.w600));
            }).toList(),
          ),
        ),
      )),
    );
  }

  bool _fuoriRange(double v) {
    if (sogliaBassa != null && v < sogliaBassa!) return true;
    if (sogliaAlta  != null && v > sogliaAlta!)  return true;
    return false;
  }

  double _intervalloX(int n) {
    if (n <= 10) return 1;
    if (n <= 30) return (n / 6).ceilToDouble();
    if (n <= 100) return (n / 8).ceilToDouble();
    return (n / 10).ceilToDouble();
  }
}

// ─── Riga lettura ─────────────────────────────────────────────

class _RigaLettura extends StatelessWidget {
  final WearablePoint punto;
  final String unita;
  final Color colore;
  final double? sogliaBassa, sogliaAlta;
  final bool is24h;

  const _RigaLettura({required this.punto, required this.unita,
      required this.colore, this.sogliaBassa, this.sogliaAlta,
      required this.is24h});

  bool get _fuori {
    if (sogliaBassa != null && punto.valore < sogliaBassa!) return true;
    if (sogliaAlta  != null && punto.valore > sogliaAlta!)  return true;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final c   = _fuori ? AppTheme.error : colore;
    final fmt = is24h
        ? DateFormat('HH:mm  dd/MM/yy').format(punto.data)
        : DateFormat('dd/MM/yyyy').format(punto.data);
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _fuori ? AppTheme.error.withOpacity(0.05) : AppTheme.cardDark,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: _fuori ? AppTheme.error.withOpacity(0.25) : AppTheme.borderDark)),
      child: Row(children: [
        Icon(_fuori ? Icons.warning_amber : Icons.circle,
            size: _fuori ? 14 : 8, color: c),
        const SizedBox(width: 10),
        Expanded(child: Text(fmt,
            style: const TextStyle(fontSize: 12,
                color: AppTheme.textSecondaryDark))),
        Text('${punto.valore.toStringAsFixed(punto.valore > 100 ? 0 : 1)} $unita',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: c)),
      ]),
    );
  }
}
