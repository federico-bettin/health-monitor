import 'package:health/health.dart';

// ─── RangeStatus ──────────────────────────────────────────────

enum RangeStatus { ok, warning, error }

// ─── WearablePoint ────────────────────────────────────────────

class WearablePoint {
  final DateTime data;
  final double valore;
  const WearablePoint({required this.data, required this.valore});
}

// ─── WearableRange ────────────────────────────────────────────

class WearableRange {
  final double? min;
  final double? max;
  final String label;

  const WearableRange({this.min, this.max, required this.label});

  bool isOk(double v) {
    if (min != null && v < min!) return false;
    if (max != null && v > max!) return false;
    return true;
  }

  RangeStatus status(double v) {
    if (isOk(v)) return RangeStatus.ok;
    double pct = 0;
    if (min != null && v < min!) pct = (min! - v) / min!;
    if (max != null && v > max!) pct = (v - max!) / max!;
    return pct <= 0.20 ? RangeStatus.warning : RangeStatus.error;
  }
}

// ─── WearableNorme ────────────────────────────────────────────

abstract class WearableNorme {
  static const bmi             = WearableRange(min: 18.5, max: 24.9, label: 'BMI normale');
  static const massaGrassa     = WearableRange(min: 10,   max: 30,   label: '% massa grassa');
  static const acqua           = WearableRange(min: 45,   max: 65,   label: '% acqua corporea');
  static const fc              = WearableRange(min: 60,   max: 100,  label: 'FC media bpm');
  static const fcUltima        = WearableRange(min: 60,   max: 100,  label: 'FC bpm');
  static const fcRiposo        = WearableRange(min: 40,   max: 80,   label: 'FC riposo bpm');
  static const hrv             = WearableRange(min: 20,   max: 100,  label: 'HRV ms');
  static const spo2            = WearableRange(min: 95,   max: 100,  label: 'SpO2 %');
  static const respirazione    = WearableRange(min: 12,   max: 20,   label: 'Resp. atti/min');
  static const passi           = WearableRange(min: 6000, max: null, label: 'Passi medi/giorno');
  static const passiOggi       = WearableRange(min: 6000, max: null, label: 'Passi oggi');
  static const calorie         = WearableRange(min: 200,  max: 800,  label: 'Calorie attive kcal');
  static const calorieTot      = WearableRange(min: 1500, max: 3000, label: 'Calorie tot kcal');
  static const calorieTotali   = calorieTot;
  static const sonno           = WearableRange(min: 7,    max: 9,    label: 'Sonno totale h');
  static const sonnoLetto      = WearableRange(min: 7,    max: 10,   label: 'Sonno a letto h');
  static const sonnoLettoOre   = sonnoLetto;
  static const sonnoProfondo   = WearableRange(min: 1.0,  max: 2.5,  label: 'Sonno profondo h');
  static const sonnoProfondoOre = sonnoProfondo;
  static const sonnoLeggeroOre  = WearableRange(min: 3.0, max: 5.0,  label: 'Sonno leggero h');
  static const sonnoSveglioOre  = WearableRange(min: 0,   max: 0.5,  label: 'Sveglio notte h');
}

// ─── WearableData ─────────────────────────────────────────────

class WearableData {
  // Bilancia
  final double? peso;
  final double? bmi;
  final double? grassoCorporeo;
  final double? massaMuscolare;
  final double? acquaCorporea;
  final double? massaOssea;
  final double? metabolismoBasale;

  // Ring — FC
  final double? fcMedia;
  final double? fcMin;
  final double? fcMax;
  final double? fcUltima;
  final double? fcRiposo;
  final double? hrv;

  // Ring — altri vitali
  final double? spo2Media;
  final double? respirazione;

  // Ring — attività
  final double? passiMedi;
  final int? passiOggi;
  final double? calorieBruciate;
  final double? calorieTotali;

  // Sonno
  final double? sonnoOre;        // totale (DEEP + REM + LIGHT)
  final double? sonnoProfontoOre; // typo originale mantenuto per retrocompatibilità
  final double? sonnoRemOre;
  final double? sonnoLeggeroOre;
  final double? sonnoLettoOre;   // SLEEP_IN_BED — non disponibile su Zepp, null
  final double? sonnoSveglioOre; // SLEEP_AWAKE — non disponibile su Zepp, null

  final DateTime? ultimoAggiornamento;

  const WearableData({
    this.peso, this.bmi, this.grassoCorporeo, this.massaMuscolare,
    this.acquaCorporea, this.massaOssea, this.metabolismoBasale,
    this.fcMedia, this.fcMin, this.fcMax, this.fcUltima, this.fcRiposo,
    this.hrv, this.spo2Media, this.respirazione,
    this.passiMedi, this.passiOggi, this.calorieBruciate, this.calorieTotali,
    this.sonnoOre, this.sonnoProfontoOre, this.sonnoRemOre,
    this.sonnoLeggeroOre, this.sonnoLettoOre, this.sonnoSveglioOre,
    this.ultimoAggiornamento,
  });

  // ─── Alias retrocompatibilità ────────────────────────────────
  double? get sonnoProfondoOre  => sonnoProfontoOre;
  double? get massaGrassaPct    => grassoCorporeo;
  double? get spo2              => spo2Media;

  // ─── Metodi statici ───────────────────────────────────────────
  static String bmiCategoria(double bmi) {
    if (bmi < 18.5) return 'Sottopeso';
    if (bmi < 25.0) return 'Normopeso';
    if (bmi < 30.0) return 'Sovrappeso';
    if (bmi < 35.0) return 'Obesità I';
    return 'Obesità II+';
  }

  bool get hasDati =>
      peso != null || fcMedia != null || spo2Media != null ||
      passiMedi != null || passiOggi != null;

  Map<String, dynamic> toJson() => {
    'peso': peso, 'bmi': bmi,
    'grasso_corporeo_pct': grassoCorporeo,
    'massa_muscolare_kg': massaMuscolare,
    'acqua_corporea_pct': acquaCorporea,
    'massa_ossea_kg': massaOssea,
    'metabolismo_basale_kcal': metabolismoBasale,
    'fc_media_bpm': fcMedia, 'fc_min_bpm': fcMin, 'fc_max_bpm': fcMax,
    'fc_ultima_bpm': fcUltima, 'fc_riposo_bpm': fcRiposo,
    'hrv_ms': hrv, 'respirazione': respirazione,
    'spo2_media_pct': spo2Media,
    'passi_medi_giornalieri': passiMedi, 'passi_oggi': passiOggi,
    'calorie_attive_kcal': calorieBruciate, 'calorie_totali_kcal': calorieTotali,
    'sonno_ore': sonnoOre,
    'sonno_profondo_ore': sonnoProfontoOre,
    'sonno_rem_ore': sonnoRemOre,
    'sonno_leggero_ore': sonnoLeggeroOre,
    'sonno_letto_ore': sonnoLettoOre,
    'sonno_sveglio_ore': sonnoSveglioOre,
    'ultimo_aggiornamento': ultimoAggiornamento?.toIso8601String(),
  };
}

// ─── WearableDiagnostica ──────────────────────────────────────

class WearableDiagnostica {
  final bool ok;
  final bool haDati;
  final String errore;
  final int totaleRecord;
  final Map<String, int> perTipo;
  final Map<String, String> ultimoValPerTipo;

  const WearableDiagnostica({
    required this.ok,
    required this.haDati,
    this.errore = '',
    this.totaleRecord = 0,
    this.perTipo = const {},
    this.ultimoValPerTipo = const {},
  });
}

// ─── WearablePermessiResult ───────────────────────────────────

class WearablePermessiResult {
  final bool ok;
  final String errore;
  const WearablePermessiResult({required this.ok, this.errore = ''});
}

// ─── WearableBundle ───────────────────────────────────────────

typedef WearableBundle = ({
  WearableData data,
  Map<String, List<WearablePoint>> serie,
  double? pesoProfilo,
  double? altezza,
});

// ─── HealthService ────────────────────────────────────────────

class HealthService {
  final Health _health = Health();

  // Tipi base — sempre richiesti
  static const _tipiBase = [
    HealthDataType.WEIGHT,
    HealthDataType.BODY_FAT_PERCENTAGE,
    HealthDataType.LEAN_BODY_MASS,
    HealthDataType.HEART_RATE,
    HealthDataType.STEPS,
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.SLEEP_DEEP,
    HealthDataType.SLEEP_REM,
    HealthDataType.ACTIVE_ENERGY_BURNED,
  ];

  // Tipi opzionali supportati da Health Connect (SLEEP_LIGHT e BODY_MASS_INDEX
  // NON sono supportati: se inclusi nella richiesta, il dialogo permessi non si apre)
  static const _tipiOpzionali = [
    HealthDataType.BODY_WATER_MASS,
    HealthDataType.BLOOD_OXYGEN,
  ];

  static bool _configurato = false;

  /// health >= 11 richiede configure() prima di qualsiasi chiamata.
  Future<void> _configura() async {
    if (_configurato) return;
    await _health.configure();
    _configurato = true;
  }

  /// Legge più tipi insieme; se la lettura cumulativa fallisce (es. un solo
  /// permesso mancante), ripiega su una lettura per tipo, ignorando i tipi
  /// non leggibili. Così un permesso negato non azzera tutti i dati.
  Future<List<HealthDataPoint>> _leggiSicuro(
      List<HealthDataType> tipi, DateTime from, DateTime to) async {
    try {
      return await _health.getHealthDataFromTypes(
          types: tipi, startTime: from, endTime: to);
    } catch (_) {
      final out = <HealthDataPoint>[];
      for (final t in tipi) {
        try {
          out.addAll(await _health.getHealthDataFromTypes(
              types: [t], startTime: from, endTime: to));
        } catch (_) {}
      }
      return out;
    }
  }

  Future<List<HealthDataType>> _tipiDisponibili() async {
    await _configura();
    return [..._tipiBase, ..._tipiOpzionali];
  }

  // ─── Permessi ────────────────────────────────────────────────

  Future<bool> richiediPermessi() async {
    try {
      await _configura();
      final tipi = await _tipiDisponibili();
      return await _health.requestAuthorization(tipi);
    } catch (e) {
      return false;
    }
  }

  Future<WearablePermessiResult> richiediPermessiDettaglio() async {
    try {
      await _configura();
      final stato = await _health.getHealthConnectSdkStatus();
      if (stato != HealthConnectSdkStatus.sdkAvailable) {
        try { await _health.installHealthConnect(); } catch (_) {}
        return WearablePermessiResult(
            ok: false, errore: 'Health Connect non disponibile ($stato)');
      }
      final tipi = await _tipiDisponibili();
      final ok = await _health.requestAuthorization(tipi);
      return WearablePermessiResult(ok: ok);
    } catch (e) {
      return WearablePermessiResult(ok: false, errore: e.toString());
    }
  }

  Future<bool> hasPermessi() async {
    try {
      // Samsung può restituire null → trattare null come true (tentare comunque)
      await _configura();
      return await _health.hasPermissions(_tipiBase) ?? true;
    } catch (e) {
      return true;
    }
  }

  // ─── leggiDati ────────────────────────────────────────────────

  Future<WearableData> leggiDati({
    int giorni = 30,
    String? stepSource,
  }) async {
    try {
      final sorgente = await _sorgenteEffettiva(stepSource);
      final now = DateTime.now();
      final from = now.subtract(Duration(days: giorni));
      final from7 = now.subtract(const Duration(days: 7));
      final mezzanotte = DateTime(now.year, now.month, now.day);
      final tipi = await _tipiDisponibili();

      final dati = await _leggiSicuro(tipi, from, now);

      // Bilancia
      final peso           = _ultimoValore(dati, HealthDataType.WEIGHT);
      final bmi            = _ultimoValoreOpt(dati, HealthDataType.BODY_MASS_INDEX);
      final grassoCorporeo = _ultimoValore(dati, HealthDataType.BODY_FAT_PERCENTAGE);
      final massaMuscolare = _ultimoValore(dati, HealthDataType.LEAN_BODY_MASS);
      final acquaCorporea  = _ultimoValoreOpt(dati, HealthDataType.BODY_WATER_MASS);

      // FC
      final fcPoints = _valoriRange(dati, HealthDataType.HEART_RATE, from7, now);
      final fcUlt    = _ultimoValore(dati, HealthDataType.HEART_RATE);

      // SpO2
      double? spo2;
      try { spo2 = _ultimoValoreOpt(dati, HealthDataType.BLOOD_OXYGEN); } catch (_) {}

      // Passi medi 7gg — filtro per sorgente
      final passiMed  = _mediaPassiGiornalieri(dati, from7, now, sorgente);
      // Passi oggi — query separata e isolata (evita contaminazione da più sorgenti)
      final passiOggiVal = await leggiPassiOggi(stepSource: sorgente);

      // Calorie
      final caloriePts = _valoriRange(dati, HealthDataType.ACTIVE_ENERGY_BURNED, from7, now);

      // Sonno — totale = DEEP + REM + LIGHT (se disponibile)
      final sonnoProfondo = _sommaOre(dati, HealthDataType.SLEEP_DEEP, from7, now);
      final sonnoRem      = _sommaOre(dati, HealthDataType.SLEEP_REM,  from7, now);
      final sonnoLeggero  = _sommaOreOpt(dati, HealthDataType.SLEEP_LIGHT, from7, now);
      final sonnoTotale   = sonnoProfondo + sonnoRem + (sonnoLeggero ?? 0);

      return WearableData(
        peso: peso, bmi: bmi,
        grassoCorporeo: grassoCorporeo,
        massaMuscolare: massaMuscolare,
        acquaCorporea: acquaCorporea,
        fcMedia:  fcPoints.isNotEmpty ? _media(fcPoints) : null,
        fcMin:    fcPoints.isNotEmpty ? fcPoints.reduce((a, b) => a < b ? a : b) : null,
        fcMax:    fcPoints.isNotEmpty ? fcPoints.reduce((a, b) => a > b ? a : b) : null,
        fcUltima: fcUlt,
        spo2Media: spo2,
        passiMedi:  passiMed,
        passiOggi:  passiOggiVal,
        calorieBruciate: caloriePts.isNotEmpty ? _media(caloriePts) : null,
        sonnoOre:         sonnoTotale > 0 ? sonnoTotale / 7 : null,
        sonnoProfontoOre: sonnoProfondo > 0 ? sonnoProfondo / 7 : null,
        sonnoRemOre:      sonnoRem > 0 ? sonnoRem / 7 : null,
        sonnoLeggeroOre:  sonnoLeggero != null && sonnoLeggero > 0
            ? sonnoLeggero / 7 : null,
        ultimoAggiornamento: now,
      );
    } catch (e) {
      return const WearableData();
    }
  }

  // Versione interna che riusa dati già caricati
  WearableData _leggiDatiDa(List<HealthDataPoint> dati, String sorgente,
      {int? passiOggi}) {
    final now        = DateTime.now();
    final from7      = now.subtract(const Duration(days: 7));
    final from       = dati.isNotEmpty
        ? dati.map((d) => d.dateFrom).reduce((a, b) => a.isBefore(b) ? a : b)
        : now.subtract(const Duration(days: 30));

    final peso           = _ultimoValore(dati, HealthDataType.WEIGHT);
    final bmi            = _ultimoValoreOpt(dati, HealthDataType.BODY_MASS_INDEX);
    final grassoCorporeo = _ultimoValore(dati, HealthDataType.BODY_FAT_PERCENTAGE);
    final massaMuscolare = _ultimoValore(dati, HealthDataType.LEAN_BODY_MASS);
    final acquaCorporea  = _ultimoValoreOpt(dati, HealthDataType.BODY_WATER_MASS);

    final fcPoints = _valoriRange(dati, HealthDataType.HEART_RATE, from7, now);
    final fcUlt    = _ultimoValore(dati, HealthDataType.HEART_RATE);

    double? spo2;
    try { spo2 = _ultimoValoreOpt(dati, HealthDataType.BLOOD_OXYGEN); } catch (_) {}

    final passiMed = _mediaPassiGiornalieri(dati, from7, now, sorgente);

    final caloriePts = _valoriRange(dati, HealthDataType.ACTIVE_ENERGY_BURNED, from7, now);

    final sonnoProfondo = _sommaOre(dati, HealthDataType.SLEEP_DEEP, from7, now);
    final sonnoRem      = _sommaOre(dati, HealthDataType.SLEEP_REM,  from7, now);
    final sonnoLeggero  = _sommaOreOpt(dati, HealthDataType.SLEEP_LIGHT, from7, now);
    final sonnoTotale   = sonnoProfondo + sonnoRem + (sonnoLeggero ?? 0);

    return WearableData(
      peso: peso, bmi: bmi,
      grassoCorporeo: grassoCorporeo,
      massaMuscolare: massaMuscolare,
      acquaCorporea: acquaCorporea,
      fcMedia:  fcPoints.isNotEmpty ? _media(fcPoints) : null,
      fcMin:    fcPoints.isNotEmpty ? fcPoints.reduce((a, b) => a < b ? a : b) : null,
      fcMax:    fcPoints.isNotEmpty ? fcPoints.reduce((a, b) => a > b ? a : b) : null,
      fcUltima: fcUlt,
      spo2Media: spo2,
      passiMedi:  passiMed,
      passiOggi:  passiOggi,  // pre-calcolato con query isolata
      calorieBruciate: caloriePts.isNotEmpty ? _media(caloriePts) : null,
      sonnoOre:         sonnoTotale > 0 ? sonnoTotale / 7 : null,
      sonnoProfontoOre: sonnoProfondo > 0 ? sonnoProfondo / 7 : null,
      sonnoRemOre:      sonnoRem > 0 ? sonnoRem / 7 : null,
      sonnoLeggeroOre:  sonnoLeggero != null && sonnoLeggero > 0
          ? sonnoLeggero / 7 : null,
      ultimoAggiornamento: now,
    );
  }

  // ─── leggiBundle ─────────────────────────────────────────────

  Future<WearableBundle> leggiBundle({
    int giorni = 30,
    double? altezzaCm,
    String? stepSource,
  }) async {
    try {
      final sorgente = await _sorgenteEffettiva(stepSource);
      final now  = DateTime.now();
      final from = now.subtract(Duration(days: giorni));
      final tipi = await _tipiDisponibili();

      // UNA SOLA query per tutto
      final dati = await _leggiSicuro(tipi, from, now);

      // Passi oggi — query separata e isolata (evita contaminazione)
      final passiOggiVal = await leggiPassiOggi(stepSource: sorgente);

      // Riusa i dati già caricati senza rileggere
      final wData = _leggiDatiDa(dati, sorgente, passiOggi: passiOggiVal);

      final serie = <String, List<WearablePoint>>{
        'peso':           _buildSeriePuntuali(dati, HealthDataType.WEIGHT, from, now),
        'bmi':            _buildSeriePuntuali(dati, HealthDataType.BODY_MASS_INDEX, from, now),
        'grasso':         _buildSeriePuntuali(dati, HealthDataType.BODY_FAT_PERCENTAGE, from, now),
        'muscoli':        _buildSeriePuntuali(dati, HealthDataType.LEAN_BODY_MASS, from, now),
        'acqua':          _buildSeriePuntuali(dati, HealthDataType.BODY_WATER_MASS, from, now),
        'fc':             _buildSerieMediaGiornaliera(dati, HealthDataType.HEART_RATE, from, now),
        'spo2':           _buildSeriePuntuali(dati, HealthDataType.BLOOD_OXYGEN, from, now),
        'passi':          _buildSeriePassiGiornalieri(dati, from, now, sorgente),
        'calorie':        _buildSerieMediaGiornaliera(dati, HealthDataType.ACTIVE_ENERGY_BURNED, from, now),
        'sonno':          _buildSerieSonnoGiornaliero(dati, from, now),
        'sonno_profondo': _buildSerieSonnoTipoGiornaliero(dati, HealthDataType.SLEEP_DEEP, from, now),
        'sonno_rem':      _buildSerieSonnoTipoGiornaliero(dati, HealthDataType.SLEEP_REM, from, now),
        'sonno_leggero':  _buildSerieSonnoTipoGiornaliero(dati, HealthDataType.SLEEP_LIGHT, from, now),
      };

      return (
        data: wData,
        serie: serie,
        pesoProfilo: wData.peso,
        altezza: altezzaCm,
      );
    } catch (e) {
      return (
        data: const WearableData(),
        serie: <String, List<WearablePoint>>{},
        pesoProfilo: null,
        altezza: altezzaCm,
      );
    }
  }

  // ─── leggiPassiOggi ───────────────────────────────────────────
  // Usa la STESSA logica di leggiSorgentiPassi (che mostra valori corretti).
  // Costruisce totale per sorgente, poi restituisce solo quello della sorgente scelta.

  Future<int?> leggiPassiOggi({String? stepSource}) async {
    try {
      final sorgente   = await _sorgenteEffettiva(stepSource);
      final now        = DateTime.now();
      final mezzanotte = DateTime(now.year, now.month, now.day);

      final dati = await _health.getHealthDataFromTypes(
        types:     [HealthDataType.STEPS],
        startTime: mezzanotte,
        endTime:   now,
      );

      // Stessa logica di leggiSorgentiPassi — somma per chiave "nome  |  pkg"
      final totali = <String, double>{};
      for (final d in dati) {
        final key = '${d.sourceName}  |  ${d.sourceId}';
        final v   = d.value;
        if (v is NumericHealthValue) {
          totali[key] = (totali[key] ?? 0) + v.numericValue.toDouble();
        }
      }

      // Trova la chiave che contiene la sorgente (in nome O in pkg)
      for (final entry in totali.entries) {
        final parts = entry.key.split('  |  ');
        final nome  = parts[0];
        final pkg   = parts.length > 1 ? parts[1] : parts[0];
        if (nome == sorgente || pkg == sorgente) {
          final val = entry.value.round();
          return val > 0 ? val : null;
        }
      }
      return null; // sorgente non trovata → niente (mai spazzatura)
    } catch (_) {
      return null;
    }
  }

  // ─── leggiDatiRecenti ─────────────────────────────────────────
  // Per la pagina Wearable: solo ultima misurazione, niente medie 7gg.
  // Bilancia: finestra 30gg. Ring + sonno: ultime 36h. Passi: query isolata.

  Future<WearableData> leggiDatiRecenti({String? stepSource}) async {
    try {
      final sorgente = await _sorgenteEffettiva(stepSource);
      final now      = DateTime.now();
      final ieri     = now.subtract(const Duration(hours: 36));
      final giorni30 = now.subtract(const Duration(days: 30));
      final tipi     = await _tipiDisponibili();

      final tipiBilancia = [
        HealthDataType.WEIGHT,
        HealthDataType.BODY_FAT_PERCENTAGE,
        HealthDataType.LEAN_BODY_MASS,
        HealthDataType.BODY_WATER_MASS,
        HealthDataType.BODY_MASS_INDEX,
      ];

      final datiBilancia = await _leggiSicuro(
        tipiBilancia.where((t) => tipi.contains(t)).toList(), giorni30, now);

      final tipiRing = tipi.where((t) => !tipiBilancia.contains(t) &&
          t != HealthDataType.STEPS).toList();
      final datiRing = tipiRing.isNotEmpty
          ? await _leggiSicuro(tipiRing, ieri, now)
          : <HealthDataPoint>[];

      final datiTutti = [...datiBilancia, ...datiRing];

      final peso           = _ultimoValore(datiTutti, HealthDataType.WEIGHT);
      final bmi            = _ultimoValoreOpt(datiTutti, HealthDataType.BODY_MASS_INDEX);
      final grassoCorporeo = _ultimoValore(datiTutti, HealthDataType.BODY_FAT_PERCENTAGE);
      final massaMuscolare = _ultimoValore(datiTutti, HealthDataType.LEAN_BODY_MASS);
      final acquaCorporea  = _ultimoValoreOpt(datiTutti, HealthDataType.BODY_WATER_MASS);

      final fcUlt = _ultimoValore(datiTutti, HealthDataType.HEART_RATE);
      double? spo2;
      try { spo2 = _ultimoValoreOpt(datiTutti, HealthDataType.BLOOD_OXYGEN); } catch (_) {}

      final sonnoProfondo = _sommaOre(datiTutti, HealthDataType.SLEEP_DEEP, ieri, now);
      final sonnoRem      = _sommaOre(datiTutti, HealthDataType.SLEEP_REM,  ieri, now);
      final sonnoLeggero  = _sommaOreOpt(datiTutti, HealthDataType.SLEEP_LIGHT, ieri, now);
      final sonnoTotale   = sonnoProfondo + sonnoRem + (sonnoLeggero ?? 0);

      final passiOggiVal = await leggiPassiOggi(stepSource: sorgente);

      return WearableData(
        peso: peso, bmi: bmi,
        grassoCorporeo: grassoCorporeo,
        massaMuscolare: massaMuscolare,
        acquaCorporea: acquaCorporea,
        fcUltima: fcUlt,
        spo2Media: spo2,
        passiOggi: passiOggiVal,
        sonnoOre:         sonnoTotale > 0 ? sonnoTotale : null,
        sonnoProfontoOre: sonnoProfondo > 0 ? sonnoProfondo : null,
        sonnoRemOre:      sonnoRem > 0 ? sonnoRem : null,
        sonnoLeggeroOre:  sonnoLeggero != null && sonnoLeggero > 0
            ? sonnoLeggero : null,
        ultimoAggiornamento: now,
      );
    } catch (_) {
      return const WearableData();
    }
  }

  Future<List<WearablePoint>> leggiSerieBilancia(HealthDataType tipo, {int giorni = 30}) async {
    try {
      final now  = DateTime.now();
      final from = now.subtract(Duration(days: giorni));
      final dati = await _health.getHealthDataFromTypes(
        types: [tipo], startTime: from, endTime: now,
      );
      return _buildSeriePuntuali(dati, tipo, from, now);
    } catch (_) {
      return [];
    }
  }

  // ─── leggiPassi24h ────────────────────────────────────────────

  Future<List<WearablePoint>> leggiPassi24h({String? stepSource}) async {
    try {
      final sorgente   = await _sorgenteEffettiva(stepSource);
      final now        = DateTime.now();
      final mezzanotte = DateTime(now.year, now.month, now.day);

      final dati = await _health.getHealthDataFromTypes(
        types: [HealthDataType.STEPS],
        startTime: mezzanotte, endTime: now,
      );

      final records = _filtraPassi(dati, sorgente)
        ..sort((a, b) => a.dateFrom.compareTo(b.dateFrom));

      if (records.isEmpty) return [];

      double cumulato = 0;
      final punti = <WearablePoint>[];
      for (final r in records) {
        final v = r.value;
        if (v is NumericHealthValue) {
          cumulato += v.numericValue.toDouble();
          punti.add(WearablePoint(data: r.dateTo, valore: cumulato));
        }
      }
      return punti;
    } catch (_) {
      return [];
    }
  }

  // ─── leggiPassi30gg ───────────────────────────────────────────

  Future<List<WearablePoint>> leggiPassi30gg({String? stepSource}) async {
    try {
      final sorgente = await _sorgenteEffettiva(stepSource);
      final now  = DateTime.now();
      final from = now.subtract(const Duration(days: 30));

      final dati = await _health.getHealthDataFromTypes(
        types: [HealthDataType.STEPS],
        startTime: from, endTime: now,
      );
      return _buildSeriePassiGiornalieri(dati, from, now, sorgente);
    } catch (_) {
      return [];
    }
  }

  // ─── leggiSerieRing24h ────────────────────────────────────────

  Future<List<WearablePoint>> leggiSerieRing24h(HealthDataType tipo,
      {String? stepSource}) async {
    if (tipo == HealthDataType.STEPS) {
      return leggiPassi24h(stepSource: stepSource);
    }
    // Il sonno è notturno — non ha senso come serie intraday
    if (tipo == HealthDataType.SLEEP_DEEP ||
        tipo == HealthDataType.SLEEP_REM  ||
        tipo == HealthDataType.SLEEP_LIGHT ||
        tipo == HealthDataType.SLEEP_ASLEEP) return [];
    try {
      final now        = DateTime.now();
      final mezzanotte = DateTime(now.year, now.month, now.day);
      final dati = await _health.getHealthDataFromTypes(
        types: [tipo], startTime: mezzanotte, endTime: now,
      );
      return _buildSeriePuntuali(dati, tipo, mezzanotte, now);
    } catch (_) {
      return [];
    }
  }

  // ─── leggiSerieRing30gg ───────────────────────────────────────

  Future<List<WearablePoint>> leggiSerieRing30gg(HealthDataType tipo,
      {String? stepSource}) async {
    if (tipo == HealthDataType.STEPS) {
      return leggiPassi30gg(stepSource: stepSource);
    }
    if (tipo == HealthDataType.SLEEP_DEEP ||
        tipo == HealthDataType.SLEEP_REM  ||
        tipo == HealthDataType.SLEEP_LIGHT ||
        tipo == HealthDataType.SLEEP_ASLEEP) {
      try {
        final now  = DateTime.now();
        final from = now.subtract(const Duration(days: 30));
        final tipi = await _tipiDisponibili();
        final dati = await _leggiSicuro(tipi, from, now);
        return _buildSerieSonnoGiornaliero(dati, from, now);
      } catch (_) {
        return [];
      }
    }
    try {
      final now  = DateTime.now();
      final from = now.subtract(const Duration(days: 30));
      final dati = await _health.getHealthDataFromTypes(
        types: [tipo], startTime: from, endTime: now,
      );
      return _buildSerieMediaGiornaliera(dati, tipo, from, now);
    } catch (_) {
      return [];
    }
  }

  // ─── leggiSorgentiPassi ───────────────────────────────────────
  // Ritorna Map<"sourceName  |  sourceId", "totalePassi"> per mostrare
  // le sorgenti STEPS disponibili con i relativi totali giornalieri.

  Future<Map<String, String>> leggiSorgentiPassi() async {
    try {
      final now        = DateTime.now();
      final mezzanotte = DateTime(now.year, now.month, now.day);
      final dati = await _health.getHealthDataFromTypes(
        types: [HealthDataType.STEPS],
        startTime: mezzanotte, endTime: now,
      );
      // Somma passi per sorgente
      final totali = <String, double>{}; // chiave = "nome  |  pkg"
      for (final d in dati) {
        final key = '${d.sourceName}  |  ${d.sourceId}';
        final v   = d.value;
        if (v is NumericHealthValue) {
          totali[key] = (totali[key] ?? 0) + v.numericValue.toDouble();
        }
      }
      // Converti i valori in stringa intera
      return totali.map((k, v) => MapEntry(k, v.round().toString()));
    } catch (_) {
      return {};
    }
  }

  // ─── diagnostica ─────────────────────────────────────────────

  Future<WearableDiagnostica> diagnostica() async {
    try {
      final now  = DateTime.now();
      final from = now.subtract(const Duration(days: 7));
      final tipi = await _tipiDisponibili();

      final dati = await _leggiSicuro(tipi, from, now);

      final perTipo    = <String, int>{};
      final ultimoVal  = <String, String>{};

      for (final d in dati) {
        final key = d.type.name;
        perTipo[key] = (perTipo[key] ?? 0) + 1;
        final v = d.value;
        if (v is NumericHealthValue && !ultimoVal.containsKey(key)) {
          final num = v.numericValue.toDouble();
          // Formatta con 1 decimale se non è un intero, altrimenti intero
          ultimoVal[key] = num == num.roundToDouble()
              ? num.round().toString()
              : num.toStringAsFixed(1);
        }
      }

      return WearableDiagnostica(
        ok: true,
        haDati: dati.isNotEmpty,
        totaleRecord: dati.length,
        perTipo: perTipo,
        ultimoValPerTipo: ultimoVal,
      );
    } catch (e) {
      return WearableDiagnostica(
        ok: false,
        haDati: false,
        errore: e.toString(),
      );
    }
  }

  // ─── Helper: costruzione serie ────────────────────────────────

  List<WearablePoint> _buildSeriePuntuali(
      List<HealthDataPoint> dati, HealthDataType tipo,
      DateTime from, DateTime to) {
    return dati
        .where((d) => d.type == tipo &&
            d.dateTo.isAfter(from) && d.dateTo.isBefore(to))
        .map((d) {
          final v = d.value;
          if (v is NumericHealthValue) {
            return WearablePoint(
                data: d.dateTo, valore: v.numericValue.toDouble());
          }
          return null;
        })
        .whereType<WearablePoint>()
        .toList()
      ..sort((a, b) => a.data.compareTo(b.data));
  }

  List<WearablePoint> _buildSerieMediaGiornaliera(
      List<HealthDataPoint> dati, HealthDataType tipo,
      DateTime from, DateTime to) {
    final byDay = <DateTime, List<double>>{};
    for (final d in dati.where((d) => d.type == tipo &&
        d.dateTo.isAfter(from) && d.dateTo.isBefore(to))) {
      final v = d.value;
      if (v is NumericHealthValue) {
        final g = DateTime(d.dateTo.year, d.dateTo.month, d.dateTo.day);
        byDay.putIfAbsent(g, () => []).add(v.numericValue.toDouble());
      }
    }
    return byDay.entries
        .map((e) => WearablePoint(data: e.key, valore: _media(e.value)))
        .toList()
      ..sort((a, b) => a.data.compareTo(b.data));
  }

  List<WearablePoint> _buildSeriePassiGiornalieri(
      List<HealthDataPoint> dati, DateTime from, DateTime to, String sorgente) {
    final byDay = <DateTime, double>{};
    for (final d in _filtraPassi(dati, sorgente).where((d) =>
        d.dateTo.isAfter(from) && d.dateTo.isBefore(to))) {
      final v = d.value;
      if (v is NumericHealthValue) {
        final g = DateTime(d.dateTo.year, d.dateTo.month, d.dateTo.day);
        byDay[g] = (byDay[g] ?? 0) + v.numericValue.toDouble();
      }
    }
    return byDay.entries
        .map((e) => WearablePoint(data: e.key, valore: e.value))
        .toList()
      ..sort((a, b) => a.data.compareTo(b.data));
  }

  List<WearablePoint> _buildSerieSonnoGiornaliero(
      List<HealthDataPoint> dati, DateTime from, DateTime to) {
    final tipiSonno = [
      HealthDataType.SLEEP_DEEP,
      HealthDataType.SLEEP_REM,
      HealthDataType.SLEEP_LIGHT,
    ];
    final byDay = <DateTime, double>{};
    for (final d in dati.where((d) =>
        tipiSonno.contains(d.type) &&
        d.dateTo.isAfter(from) && d.dateTo.isBefore(to))) {
      final g   = DateTime(d.dateTo.year, d.dateTo.month, d.dateTo.day);
      final ore = d.dateTo.difference(d.dateFrom).inMinutes / 60.0;
      byDay[g]  = (byDay[g] ?? 0) + ore;
    }
    return byDay.entries
        .map((e) => WearablePoint(data: e.key, valore: e.value))
        .toList()
      ..sort((a, b) => a.data.compareTo(b.data));
  }

  List<WearablePoint> _buildSerieSonnoTipoGiornaliero(
      List<HealthDataPoint> dati, HealthDataType tipo,
      DateTime from, DateTime to) {
    final byDay = <DateTime, double>{};
    for (final d in dati.where((d) => d.type == tipo &&
        d.dateTo.isAfter(from) && d.dateTo.isBefore(to))) {
      final g   = DateTime(d.dateTo.year, d.dateTo.month, d.dateTo.day);
      final ore = d.dateTo.difference(d.dateFrom).inMinutes / 60.0;
      byDay[g]  = (byDay[g] ?? 0) + ore;
    }
    return byDay.entries
        .map((e) => WearablePoint(data: e.key, valore: e.value))
        .toList()
      ..sort((a, b) => a.data.compareTo(b.data));
  }

  // ─── Helper: calcoli ─────────────────────────────────────────

  double? _ultimoValore(List<HealthDataPoint> dati, HealthDataType tipo) {
    final f = dati.where((d) => d.type == tipo).toList();
    if (f.isEmpty) return null;
    f.sort((a, b) => b.dateTo.compareTo(a.dateTo));
    final v = f.first.value;
    if (v is NumericHealthValue) return v.numericValue.toDouble();
    return null;
  }

  double? _ultimoValoreOpt(List<HealthDataPoint> dati, HealthDataType tipo) {
    try { return _ultimoValore(dati, tipo); } catch (_) { return null; }
  }

  List<double> _valoriRange(List<HealthDataPoint> dati,
      HealthDataType tipo, DateTime from, DateTime to) {
    return dati
        .where((d) => d.type == tipo &&
            d.dateTo.isAfter(from) && d.dateTo.isBefore(to))
        .map((d) {
          final v = d.value;
          if (v is NumericHealthValue) return v.numericValue.toDouble();
          return null;
        })
        .whereType<double>()
        .toList();
  }

  double _media(List<double> v) =>
      v.isEmpty ? 0 : v.reduce((a, b) => a + b) / v.length;

  // ─── Filtro passi per sorgente ───────────────────────────────
  // sorgente: sourceId esatto da usare. null = com.huami.watch.hmwatchmanager

  static const defaultStepSource = 'com.huami.watch.hmwatchmanager';

  // ─── Sorgente passi automatica ───────────────────────────────
  // Se l'utente non ha scelto una sorgente, ne sceglie UNA sola (mai somme
  // tra sorgenti diverse, che raddoppierebbero i passi):
  //  1. l'anello Zepp/Amazfit, se presente
  //  2. altrimenti la sorgente con più passi negli ultimi 7 giorni
  //     (Google Fit, Samsung Health, contapassi del telefono, ecc.)
  static String? _cacheSorgente;
  static DateTime? _cacheSorgenteQuando;

  static Set<String> _sorgentiPassi = {};

  /// La sorgente scelta dall'utente (o quella di default) vale solo se ha
  /// davvero passi negli ultimi 7 giorni; altrimenti si usa quella rilevata
  /// automaticamente (es. Samsung Health / telefono invece di Zepp).
  Future<String> _sorgenteEffettiva(String? scelta) async {
    final auto = await _sorgentePassiAuto();
    if (scelta != null && _sorgentiPassi.contains(scelta)) return scelta;
    return auto;
  }

  Future<String> _sorgentePassiAuto() async {
    final ora = DateTime.now();
    if (_cacheSorgente != null &&
        _cacheSorgenteQuando != null &&
        ora.difference(_cacheSorgenteQuando!).inMinutes < 5) {
      return _cacheSorgente!;
    }
    var scelta = defaultStepSource;
    _sorgentiPassi = {};
    try {
      final dati = await _health.getHealthDataFromTypes(
        types: [HealthDataType.STEPS],
        startTime: ora.subtract(const Duration(days: 7)),
        endTime: ora,
      );
      final totali = <String, double>{};
      final zepp = <String>{};
      for (final d in dati) {
        final v = d.value;
        if (v is! NumericHealthValue) continue;
        final id = d.sourceId.isNotEmpty ? d.sourceId : d.sourceName;
        totali[id] = (totali[id] ?? 0) + v.numericValue.toDouble();
        final t = '${d.sourceId} ${d.sourceName}'.toLowerCase();
        if (t.contains('huami') || t.contains('zepp') || t.contains('amazfit')) {
          zepp.add(id);
        }
      }
      _sorgentiPassi = totali.keys.toSet();
      if (totali.isNotEmpty) {
        final candidati = zepp.isNotEmpty
            ? totali.entries.where((e) => zepp.contains(e.key))
            : totali.entries;
        scelta = candidati.reduce((a, b) => a.value >= b.value ? a : b).key;
      }
    } catch (_) {}
    _cacheSorgente = scelta;
    _cacheSorgenteQuando = ora;
    return scelta;
  }

  List<HealthDataPoint> _filtraPassi(
      List<HealthDataPoint> dati, String sorgente) {
    return dati
        .where((d) =>
            d.type == HealthDataType.STEPS &&
            (d.sourceId == sorgente || d.sourceName == sorgente))
        .toList();
  }

  double? _mediaPassiGiornalieri(
      List<HealthDataPoint> dati, DateTime from, DateTime to, String sorgente) {
    final byDay = <DateTime, double>{};
    for (final d in _filtraPassi(dati, sorgente).where((d) =>
        d.dateTo.isAfter(from) && d.dateTo.isBefore(to))) {
      final v = d.value;
      if (v is NumericHealthValue) {
        final g = DateTime(d.dateTo.year, d.dateTo.month, d.dateTo.day);
        byDay[g] = (byDay[g] ?? 0) + v.numericValue.toDouble();
      }
    }
    if (byDay.isEmpty) return null;
    return _media(byDay.values.toList());
  }

  double _sommaPassiDa(List<HealthDataPoint> dati,
      DateTime from, DateTime to, String sorgente) {
    double tot = 0;
    for (final d in _filtraPassi(dati, sorgente).where((d) =>
        d.dateTo.isAfter(from) && d.dateTo.isBefore(to))) {
      final v = d.value;
      if (v is NumericHealthValue) tot += v.numericValue.toDouble();
    }
    return tot;
  }

  double _sommaOre(List<HealthDataPoint> dati,
      HealthDataType tipo, DateTime from, DateTime to) {
    double tot = 0;
    for (final d in dati.where((d) =>
        d.type == tipo && d.dateTo.isAfter(from) && d.dateTo.isBefore(to))) {
      tot += d.dateTo.difference(d.dateFrom).inMinutes;
    }
    return tot / 60;
  }

  double? _sommaOreOpt(List<HealthDataPoint> dati,
      HealthDataType tipo, DateTime from, DateTime to) {
    try {
      final tot = _sommaOre(dati, tipo, from, to);
      return tot > 0 ? tot : null;
    } catch (_) {
      return null;
    }
  }
}
