import 'package:shared_preferences/shared_preferences.dart';
import 'package:salute_bettin/core/constants.dart';

class SettingsService {
  static SettingsService? _instance;
  static SettingsService get instance => _instance!;
  late SharedPreferences _prefs;
  SettingsService._();

  static Future<SettingsService> init() async {
    _instance = SettingsService._();
    _instance!._prefs = await SharedPreferences.getInstance();
    return _instance!;
  }

  // ─── Storage Mode ─────────────────────────────────────────
  String get storageMode =>
      _prefs.getString(AppConstants.prefStorageMode) ?? AppConstants.storageModeLocal;
  Future<void> setStorageMode(String mode) =>
      _prefs.setString(AppConstants.prefStorageMode, mode);

  // ─── Lingua ───────────────────────────────────────────────
  String get languageCode =>
      _prefs.getString(AppConstants.prefLanguageCode) ?? AppConstants.langDefault;
  Future<void> setLanguageCode(String code) =>
      _prefs.setString(AppConstants.prefLanguageCode, code);

  // ─── Biometrico ───────────────────────────────────────────
  bool get biometricEnabled =>
      _prefs.getBool(AppConstants.prefBiometricEnabled) ?? false;
  Future<void> setBiometricEnabled(bool value) =>
      _prefs.setBool(AppConstants.prefBiometricEnabled, value);

  // ─── Onboarding ───────────────────────────────────────────
  bool get onboardingDone =>
      _prefs.getBool(AppConstants.prefOnboardingDone) ?? false;
  Future<void> setOnboardingDone(bool value) =>
      _prefs.setBool(AppConstants.prefOnboardingDone, value);

  // ─── Ultima sync ──────────────────────────────────────────
  DateTime? get lastSync {
    final s = _prefs.getString(AppConstants.prefLastSync);
    return s != null ? DateTime.tryParse(s) : null;
  }
  Future<void> setLastSync(DateTime dt) =>
      _prefs.setString(AppConstants.prefLastSync, dt.toIso8601String());

  // ─── Drive folder ID ──────────────────────────────────────
  String? get driveFolderId => _prefs.getString(AppConstants.prefDriveFolderId);
  Future<void> setDriveFolderId(String id) =>
      _prefs.setString(AppConstants.prefDriveFolderId, id);

  // ─── Health Score cache (per paziente) ───────────────────
  /// Chiave = slotKey del paziente attivo
  int? cachedScore(String pazKey) =>
      _prefs.getInt('score_$pazKey') ??
      _prefs.getInt(AppConstants.prefHealthScore); // retrocompat

  String? cachedScoreData(String pazKey) =>
      _prefs.getString('score_data_$pazKey') ??
      _prefs.getString(AppConstants.prefHealthScoreData);

  String? cachedScoreHash(String pazKey) =>
      _prefs.getString('score_hash_$pazKey') ??
      _prefs.getString(AppConstants.prefHealthScoreHash);

  Future<void> saveScoreCache(
      int score, String jsonData, String hash, String pazKey) async {
    await _prefs.setInt('score_$pazKey', score);
    await _prefs.setString('score_data_$pazKey', jsonData);
    await _prefs.setString('score_hash_$pazKey', hash);
  }

  Future<void> clearScoreCache(String pazKey) async {
    await _prefs.remove('score_$pazKey');
    await _prefs.remove('score_data_$pazKey');
    await _prefs.remove('score_hash_$pazKey');
  }

  Future<void> clearAllScoreCache() async {
    await _prefs.remove(AppConstants.prefHealthScore);
    await _prefs.remove(AppConstants.prefHealthScoreData);
    await _prefs.remove(AppConstants.prefHealthScoreHash);
  }

  // ─── Slot paziente attivo ────────────────────────────────
  String? get slotAttivo => _prefs.getString('slot_attivo');
  Future<void> setSlotAttivo(String? key) async {
    if (key == null) {
      await _prefs.remove('slot_attivo');
    } else {
      await _prefs.setString('slot_attivo', key);
    }
  }

  // ─── Wearable config per paziente ────────────────────────
  /// Chiave = BackupService.slotKey(nome, cognome)
  bool usaBilancia(String pazKey) =>
      _prefs.getBool('wearable_bilancia_$pazKey') ?? false;
  bool usaRing(String pazKey) =>
      _prefs.getBool('wearable_ring_$pazKey') ?? false;
  Future<void> setUsaBilancia(String pazKey, bool v) =>
      _prefs.setBool('wearable_bilancia_$pazKey', v);
  Future<void> setUsaRing(String pazKey, bool v) =>
      _prefs.setBool('wearable_ring_$pazKey', v);

  // ─── Step source (filtro sorgente passi wearable) ────────
  /// Nome sorgente Zepp/Huami selezionata, null = autodetect
  String? get stepSource => _prefs.getString('step_source');
  Future<void> setStepSource(String? source) async {
    if (source == null) {
      await _prefs.remove('step_source');
    } else {
      await _prefs.setString('step_source', source);
    }
  }

  // ─── Foto profilo ─────────────────────────────────────────
  String? get fotoProfilo => _prefs.getString(AppConstants.prefFotoProfilo);
  Future<void> setFotoProfilo(String? path) async {
    if (path == null) {
      await _prefs.remove(AppConstants.prefFotoProfilo);
    } else {
      await _prefs.setString(AppConstants.prefFotoProfilo, path);
    }
  }

  // ─── Modello AI ───────────────────────────────────────────
  // Selezionabile in Impostazioni: Haiku 4.5 / Sonnet 4.6 / Opus 4.6
  // Letto dinamicamente da ClaudeService ad ogni chiamata
  static const _defaultAiModel = 'claude-haiku-4-5-20251001';

  String get aiModel =>
      _prefs.getString('ai_model') ?? _defaultAiModel;

  Future<void> setAiModel(String model) =>
      _prefs.setString('ai_model', model);

  // ─── Promemoria appuntamenti (visite/esami) ───────────────
  // Comportamento unico per tutti: N giorni prima, a una certa ora.
  bool get notifAttive => _prefs.getBool('notif_attive') ?? true;
  Future<void> setNotifAttive(bool v) => _prefs.setBool('notif_attive', v);

  /// Giorni di anticipo (default 3)
  int get notifGiorniPrima => _prefs.getInt('notif_giorni_prima') ?? 3;
  Future<void> setNotifGiorniPrima(int v) =>
      _prefs.setInt('notif_giorni_prima', v);

  /// Ora della notifica, in minuti da mezzanotte (default 9:00 = 540)
  int get notifOraMinuti => _prefs.getInt('notif_ora_minuti') ?? 540;
  Future<void> setNotifOraMinuti(int v) =>
      _prefs.setInt('notif_ora_minuti', v);

  // ─── Reset ────────────────────────────────────────────────
  Future<void> reset() => _prefs.clear();
}
