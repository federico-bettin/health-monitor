import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:salute_bettin/data/services/backup_service.dart';
import 'package:salute_bettin/data/services/settings_service.dart';

class DriveSyncResult {
  final bool ok;
  final String messaggio;
  const DriveSyncResult(this.ok, this.messaggio);
}

/// Sync automatico verso Google Drive (telefono = unica fonte dei dati).
///
/// - Ogni modifica locale (LocalRepository) chiama [segnaModifica].
/// - Dopo 20 s senza altre modifiche i dati vengono caricati su Drive
///   (stesso file del backup manuale: Drive/HealthMonitor).
/// - Se non c'è rete o il login scade, la modifica resta "in attesa" e il
///   sync riparte da solo quando torna la connessione (o ogni 15 min).
/// - I PDF dei referti vanno in Drive/HealthMonitor/referti.
/// Solo Android.
class DriveSyncService {
  DriveSyncService._();
  static final DriveSyncService instance = DriveSyncService._();

  static const _cartellaReferti = 'referti';

  Timer? _debounce;
  Timer? _periodico;
  StreamSubscription? _conn;
  bool _inCorso = false;
  /// Ultimo esito, mostrato nelle Impostazioni (solo in memoria).
  String? ultimoEsito;
  bool? ultimoOk;
  int _versione = 0; // incrementata a ogni modifica locale

  bool get supportato =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  SettingsService get _s => SettingsService.instance;

  /// Da chiamare all'avvio dell'app.
  Future<void> init() async {
    if (!supportato) return;
    _conn?.cancel();
    _periodico?.cancel();

    // Quando torna la rete, riprova se c'è qualcosa in attesa.
    _conn = Connectivity().onConnectivityChanged.listen((dynamic r) {
      final reti = r is List ? r : [r];
      final online = reti.any((e) => e.toString() != 'ConnectivityResult.none');
      if (online && _s.driveSyncPending) sincronizza();
    });
    _periodico = Timer.periodic(const Duration(minutes: 15), (_) {
      if (_s.driveSyncPending) sincronizza();
    });

    // All'avvio: sync se ci sono modifiche in attesa o non c'è mai stato.
    if (_s.driveSyncPending || _s.driveSyncUltima == null) {
      unawaited(sincronizza());
    }
  }

  /// Chiamato da LocalRepository a ogni salvataggio/cancellazione.
  void segnaModifica() {
    if (!supportato) return;
    _versione++;
    _s.setDriveSyncPending(true);
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 20), () => sincronizza());
  }

  // ─── Sync ───────────────────────────────────────────────────
  Future<DriveSyncResult> sincronizza(
      {bool forza = false, bool interattivo = false}) async {
    final r = await _sincronizza(forza: forza, interattivo: interattivo);
    ultimoEsito = r.messaggio;
    ultimoOk = r.ok;
    return r;
  }

  Future<DriveSyncResult> _sincronizza(
      {required bool forza, required bool interattivo}) async {
    if (!supportato) {
      return const DriveSyncResult(false, 'Disponibile solo su Android');
    }
    if (_inCorso) return const DriveSyncResult(true, 'Sync già in corso');
    _inCorso = true;
    final versioneInizio = _versione;
    try {
      final api = await BackupService.instance.driveApi(interattivo: interattivo);
      if (api == null) {
        return const DriveSyncResult(false,
            'Accesso a Google necessario: tocca "Accedi e sincronizza"');
      }

      // 1) Dati (tutti i pazienti) — solo se cambiati
      final backup = await BackupService.instance.creaBackupCompleto();
      final hash = _hash(backup);
      if (forza || hash != _s.driveSyncHash) {
        final res = await BackupService.instance.salvaDrive(backup);
        if (!res.ok) return DriveSyncResult(false, res.messaggio);
        await _s.setDriveSyncHash(hash);
      }

      // 2) Referti PDF
      final nReferti = await _caricaReferti(api, backup);

      // Se nel frattempo ci sono state altre modifiche, restano in attesa
      if (_versione == versioneInizio) {
        await _s.setDriveSyncPending(false);
      } else {
        _debounce?.cancel();
        _debounce = Timer(const Duration(seconds: 20), () => sincronizza());
      }
      await _s.setDriveSyncUltima(DateTime.now().toIso8601String());
      return DriveSyncResult(
          true,
          nReferti > 0
              ? 'Sincronizzato ($nReferti referti caricati)'
              : 'Sincronizzato');
    } catch (e) {
      // Resta "in attesa": riproverà da solo
      return DriveSyncResult(false, 'Sync non riuscito (riproverò): $e');
    } finally {
      _inCorso = false;
    }
  }

  /// Hash stabile: ignora i timestamp che cambiano a ogni export.
  String _hash(Map<String, dynamic> backup) {
    final pulito = jsonDecode(jsonEncode(backup['pazienti'] ?? {}));
    void rimuovi(dynamic n) {
      if (n is Map) {
        n.remove('exportedAt');
        n.values.forEach(rimuovi);
      } else if (n is List) {
        n.forEach(rimuovi);
      }
    }

    rimuovi(pulito);
    return sha1.convert(utf8.encode(jsonEncode(pulito))).toString();
  }

  // ─── Referti ────────────────────────────────────────────────
  /// Elenco (idRecord, path) degli allegati di esami e visite di tutti i pazienti.
  List<MapEntry<String, String>> _allegati(Map<String, dynamic> backup) {
    final out = <MapEntry<String, String>>[];
    final pazienti = backup['pazienti'] as Map<String, dynamic>? ?? {};
    for (final dati in pazienti.values) {
      if (dati is! Map) continue;
      for (final chiave in const ['esami', 'visite']) {
        for (final r in (dati[chiave] as List? ?? [])) {
          if (r is! Map) continue;
          final path = r['allegato'] as String?;
          final id = r['id'] as String?;
          if (path != null && path.isNotEmpty && id != null) {
            out.add(MapEntry(id, path));
          }
        }
      }
    }
    return out;
  }

  String _nomeDrive(String id, String path) => '${id}_${p.basename(path)}';

  Future<String> _cartellaRefertiId(drive.DriveApi api) async {
    final root = await BackupService.instance.cartellaDriveId(api);
    final list = await api.files.list(
      q: "name='$_cartellaReferti' and '$root' in parents and "
          "mimeType='application/vnd.google-apps.folder' and trashed=false",
      spaces: 'drive',
      $fields: 'files(id)',
    );
    if (list.files != null && list.files!.isNotEmpty) {
      return list.files!.first.id!;
    }
    final f = drive.File()
      ..name = _cartellaReferti
      ..parents = [root]
      ..mimeType = 'application/vnd.google-apps.folder';
    return (await api.files.create(f, $fields: 'id')).id!;
  }

  Future<int> _caricaReferti(
      drive.DriveApi api, Map<String, dynamic> backup) async {
    final tutti = _allegati(backup);
    if (tutti.isEmpty) return 0;

    final fatti = Map<String, dynamic>.from(
        jsonDecode(_s.driveSyncReferti) as Map<String, dynamic>);
    String? cartellaId;
    var caricati = 0;

    for (final e in tutti) {
      final file = File(e.value);
      if (!await file.exists()) continue;
      final nome = _nomeDrive(e.key, e.value);
      final size = await file.length();
      if (fatti[nome] == size) continue; // già su Drive

      cartellaId ??= await _cartellaRefertiId(api);
      final bytes = await file.readAsBytes();
      final media = drive.Media(Stream.value(bytes), bytes.length);

      final esistente = await api.files.list(
        q: "name='${nome.replaceAll("'", "\\'")}' and "
            "'$cartellaId' in parents and trashed=false",
        spaces: 'drive',
        $fields: 'files(id)',
      );
      if (esistente.files != null && esistente.files!.isNotEmpty) {
        await api.files
            .update(drive.File(), esistente.files!.first.id!, uploadMedia: media);
      } else {
        final meta = drive.File()
          ..name = nome
          ..parents = [cartellaId];
        await api.files.create(meta, uploadMedia: media, $fields: 'id');
      }
      fatti[nome] = size;
      caricati++;
      await _s.setDriveSyncReferti(jsonEncode(fatti)); // progresso salvato
    }
    return caricati;
  }

  /// Per il ripristino su un telefono nuovo: scarica da Drive i referti
  /// mancanti e aggiorna i percorsi nel backup (modifica [backup] in place).
  /// Ritorna il numero di referti scaricati.
  Future<int> scaricaRefertiMancanti(Map<String, dynamic> backup) async {
    var scaricati = 0;
    try {
      final api = await BackupService.instance.driveApi(interattivo: true);
      if (api == null) return 0;
      final docs = await getApplicationDocumentsDirectory();
      final dest = Directory('${docs.path}/allegati');
      if (!await dest.exists()) await dest.create(recursive: true);

      String? cartellaId;
      final pazienti = backup['pazienti'] as Map<String, dynamic>? ?? {};
      for (final dati in pazienti.values) {
        if (dati is! Map) continue;
        for (final chiave in const ['esami', 'visite']) {
          for (final r in (dati[chiave] as List? ?? [])) {
            if (r is! Map) continue;
            final path = r['allegato'] as String?;
            final id = r['id'] as String?;
            if (path == null || path.isEmpty || id == null) continue;
            if (await File(path).exists()) continue;

            cartellaId ??= await _cartellaRefertiId(api);
            final nome = _nomeDrive(id, path);
            final list = await api.files.list(
              q: "name='${nome.replaceAll("'", "\\'")}' and "
                  "'$cartellaId' in parents and trashed=false",
              spaces: 'drive',
              $fields: 'files(id)',
            );
            if (list.files == null || list.files!.isEmpty) continue;
            final media = await api.files.get(
              list.files!.first.id!,
              downloadOptions: drive.DownloadOptions.fullMedia,
            ) as drive.Media;
            final bytes = <int>[];
            await for (final c in media.stream) {
              bytes.addAll(c);
            }
            final nuovo = '${dest.path}/${p.basename(path)}';
            await File(nuovo).writeAsBytes(bytes);
            r['allegato'] = nuovo;
            scaricati++;
          }
        }
      }
    } catch (_) {}
    return scaricati;
  }
}
