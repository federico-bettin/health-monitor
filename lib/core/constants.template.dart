// âš ï¸  SETUP REQUIRED
//
// 1. Copy this file to lib/core/constants.dart
// 2. Add your Anthropic API key below
// 3. Never commit constants.dart (it's in .gitignore)
//
// Get your API key at: https://console.anthropic.com

class AppConstants {
  AppConstants._();

  // â”€â”€â”€ Anthropic â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  // ðŸ‘‡ Replace with your actual API key
  static const String anthropicApiKey = 'YOUR_ANTHROPIC_API_KEY_HERE';

  static const String anthropicModelDefault = 'claude-sonnet-4-6';
  static const int anthropicMaxTokens = 1024;

  static const Map<String, String> aiModelli = {
    'claude-haiku-4-5-20251001': 'Haiku 4.5  (veloce, economico)',
    'claude-sonnet-4-6':         'Sonnet 4.6 (bilanciato)',
    'claude-opus-4-6':           'Opus 4.6   (piÃ¹ capace)',
  };

  // â”€â”€â”€ App â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  static const String appName = 'Health Monitor';
  static const String appVersion = '1.0.0';

  // â”€â”€â”€ Google Drive â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  static const String driveFolderName    = 'HealthMonitor';
  static const String driveDataFile      = 'data.json';
  static const String driveMetaFile      = 'sync_metadata.json';
  static const String driveRefertiFolder = 'referti';

  // â”€â”€â”€ SharedPreferences keys â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  static const String prefStorageMode      = 'storage_mode';
  static const String prefLanguageCode     = 'language_code';
  static const String prefBiometricEnabled = 'biometric_enabled';
  static const String prefLastSync         = 'last_sync';
  static const String prefDriveFolderId    = 'drive_folder_id';
  static const String prefOnboardingDone   = 'onboarding_done';
  static const String prefDriveFileId      = 'drive_file_id';
  static const String prefHealthScore      = 'health_score_cache';
  static const String prefHealthScoreData  = 'health_score_data';
  static const String prefHealthScoreHash  = 'health_score_hash';
  static const String prefAiModel          = 'ai_model';
  static const String prefFotoProfilo      = 'foto_profilo';
  static const String prefStepSource       = 'step_source';

  // â”€â”€â”€ Storage modes â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  static const String storageModeLocal = 'local';
  static const String storageModeDrive = 'drive';
  static const String storageModeSync  = 'sync';

  // â”€â”€â”€ Hive box names â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  static const String boxPaziente     = 'paziente';
  static const String boxEsami        = 'esami';
  static const String boxVisite       = 'visite';
  static const String boxFarmaci      = 'farmaci';
  static const String boxAppuntamenti = 'appuntamenti';
  static const String boxConflitti    = 'conflitti';
  static const String boxTokenUsage   = 'token_usage';

  // â”€â”€â”€ Hive type IDs â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  static const int hiveTypePaziente     = 0;
  static const int hiveTypeEsame        = 1;
  static const int hiveTypeVisita       = 2;
  static const int hiveTypeFarmaco      = 3;
  static const int hiveTypeAppuntamento = 4;
  static const int hiveTypeConflitto    = 5;
  static const int hiveTypeTokenUsage   = 6;

  // â”€â”€â”€ UI â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  static const double borderRadius  = 12.0;
  static const double cardElevation = 2.0;
  static const double pagePadding   = 16.0;

  static const String langItaliano = 'it';
  static const String langEnglish = 'en';
  static const String langDefault = 'it';
  static const Duration syncInterval = Duration(minutes: 15);
  static const Duration syncTimeout = Duration(seconds: 30);
}
