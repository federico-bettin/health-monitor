import 'dart:convert';
import 'dart:io';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:salute_bettin/data/repositories/local_repository.dart';
import 'package:salute_bettin/data/services/settings_service.dart';

// ─── Slot paziente ────────────────────────────────────────────
class SlotPaziente {
  final String key;
  final String nome;
  final String cognome;
  final DateTime ultimaModifica;
  const SlotPaziente({
    required this.key,
    required this.nome,
    required this.cognome,
    required this.ultimaModifica,
  });
  String get nomeCompleto => '$nome $cognome';
}

// ─── Risultato operazione Drive ───────────────────────────────
class DriveResult {
  final bool ok;
  final String messaggio;
  const DriveResult({required this.ok, this.messaggio = ''});
}

// ─── HTTP client Google Auth ──────────────────────────────────
class _GoogleAuthClient extends http.BaseClient {
  final String _token;
  final http.Client _inner = http.Client();
  _GoogleAuthClient(this._token);
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['Authorization'] = 'Bearer $_token';
    return _inner.send(request);
  }
}

// ─── BackupService ────────────────────────────────────────────
class BackupService {
  BackupService._();
  static final instance = BackupService._();

  static const _driveScope = 'https://www.googleapis.com/auth/drive.file';
  static const _driveFolderName = 'HealthMonitor';
  static const _driveFileName = 'health_monitor_backup.json';

  // ─── Backup completo (tutti i pazienti) ───────────────────

  /// Crea Map con tutti i pazienti + paziente attivo.
  /// Salva prima il corrente nel suo slot.
  Future<Map<String, dynamic>> creaBackupCompleto() async {
    await salvaSlotCorrente();
    final slots  = await elencaSlot();
    final pazienti = <String, dynamic>{};
    final dir    = await _cartellaPazienti();

    for (final slot in slots) {
      try {
        final f = File('${dir.path}/${slot.key}.json');
        if (await f.exists()) {
          pazienti[slot.key] = jsonDecode(await f.readAsString(encoding: utf8));
        }
      } catch (_) {}
    }

    // Assicura che il paziente corrente in Hive sia incluso
    final repo = LocalRepository();
    await repo.init();
    final paz = await repo.getPaziente();
    final curKey = paz != null ? slotKey(paz.nome, paz.cognome) : null;
    if (curKey != null && !pazienti.containsKey(curKey)) {
      pazienti[curKey] = await repo.exportAll();
    }

    return {
      'versione': 2,
      'data': DateTime.now().toIso8601String(),
      'paziente_attivo': SettingsService.instance.slotAttivo ?? curKey,
      'pazienti': pazienti,
    };
  }

  /// Ripristina tutti i pazienti da un backup.
  /// Retrocompatibile con il vecchio formato v1.
  Future<bool> ripristinaCompleto(Map<String, dynamic> backup) async {
    try {
      final versione = backup['versione'] as int? ?? 1;
      if (versione < 2) {
        // Vecchio formato singolo paziente
        final repo = LocalRepository();
        await repo.init();
        await repo.importAll(backup);
        return true;
      }

      final pazienti = backup['pazienti'] as Map<String, dynamic>? ?? {};
      final pazienteAttivo = backup['paziente_attivo'] as String?;
      final dir = await _cartellaPazienti();

      // Ripristina tutti gli slot
      for (final entry in pazienti.entries) {
        final f = File('${dir.path}/${entry.key}.json');
        await f.writeAsString(
          const JsonEncoder.withIndent('  ').convert(entry.value),
          encoding: utf8,
        );
      }

      // Carica il paziente attivo in Hive
      final keyToLoad = pazienteAttivo ?? pazienti.keys.firstOrNull;
      if (keyToLoad != null && pazienti.containsKey(keyToLoad)) {
        final repo = LocalRepository();
        await repo.init();
        await repo.importAll(pazienti[keyToLoad] as Map<String, dynamic>);
        await SettingsService.instance.setSlotAttivo(keyToLoad);
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  // ─── Salvataggio locale ───────────────────────────────────

  Future<String?> salvaLocale(Map<String, dynamic> data) async {
    try {
      final json = const JsonEncoder.withIndent('  ').convert(data);
      final ts = DateTime.now();
      final nome = 'health_monitor_backup_'
          '${ts.year}${_p(ts.month)}${_p(ts.day)}_'
          '${_p(ts.hour)}${_p(ts.minute)}.json';
      final dir = await _cartellaDocumenti();
      if (dir == null) return null;
      if (!await dir.exists()) await dir.create(recursive: true);
      final path = '${dir.path}${Platform.pathSeparator}$nome';
      await File(path).writeAsString(json, encoding: utf8);
      return path;
    } catch (_) {
      return null;
    }
  }

  Future<List<File>> elencaBackupLocali() async {
    try {
      final dir = await _cartellaDocumenti();
      if (dir == null || !await dir.exists()) return [];
      return dir
          .listSync()
          .whereType<File>()
          .where((f) =>
              f.path.contains('health_monitor') && f.path.endsWith('.json'))
          .toList()
        ..sort((a, b) => b.path.compareTo(a.path));
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, dynamic>?> caricaLocale(String path) async {
    try {
      final content = await File(path).readAsString(encoding: utf8);
      return jsonDecode(content) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  // ─── Google Drive ─────────────────────────────────────────

  Future<drive.DriveApi?> _getDriveApi() async {
    try {
      final signIn = GoogleSignIn(scopes: [_driveScope]);
      GoogleSignInAccount? account = signIn.currentUser;
      account ??= await signIn.signInSilently();
      account ??= await signIn.signIn();
      if (account == null) return null;
      final auth = await account.authentication;
      if (auth.accessToken == null) return null;
      return drive.DriveApi(_GoogleAuthClient(auth.accessToken!));
    } catch (_) {
      return null;
    }
  }

  Future<String> _trovaOCreaCartellaDrive(drive.DriveApi api) async {
    final list = await api.files.list(
      q: "name='$_driveFolderName' and "
          "mimeType='application/vnd.google-apps.folder' and trashed=false",
      spaces: 'drive',
      $fields: 'files(id,name)',
    );
    if (list.files != null && list.files!.isNotEmpty) {
      return list.files!.first.id!;
    }
    final folder = drive.File()
      ..name = _driveFolderName
      ..mimeType = 'application/vnd.google-apps.folder';
    final created = await api.files.create(folder, $fields: 'id');
    return created.id!;
  }

  Future<DriveResult> salvaDrive(Map<String, dynamic> data) async {
    try {
      final api = await _getDriveApi();
      if (api == null) return const DriveResult(ok: false, messaggio: 'Accesso Google non riuscito.');
      final folderId = await _trovaOCreaCartellaDrive(api);
      final bytes   = utf8.encode(const JsonEncoder.withIndent('  ').convert(data));
      final media   = drive.Media(
          Stream.value(bytes), bytes.length, contentType: 'application/json');

      final list = await api.files.list(
        q: "name='$_driveFileName' and '$folderId' in parents and trashed=false",
        spaces: 'drive',
        $fields: 'files(id)',
      );

      if (list.files != null && list.files!.isNotEmpty) {
        await api.files.update(drive.File(), list.files!.first.id!,
            uploadMedia: media);
      } else {
        final file = drive.File()
          ..name = _driveFileName
          ..parents = [folderId];
        await api.files.create(file, uploadMedia: media, $fields: 'id');
      }
      return const DriveResult(ok: true, messaggio: 'Salvato in Drive/HealthMonitor');
    } catch (e) {
      return DriveResult(ok: false, messaggio: 'Errore Drive: $e');
    }
  }

  Future<Map<String, dynamic>?> caricaDrive() async {
    try {
      final api = await _getDriveApi();
      if (api == null) return null;
      final folderId = await _trovaOCreaCartellaDrive(api);

      final list = await api.files.list(
        q: "name='$_driveFileName' and '$folderId' in parents and trashed=false",
        spaces: 'drive',
        $fields: 'files(id)',
      );
      if (list.files == null || list.files!.isEmpty) return null;

      final media = await api.files.get(
        list.files!.first.id!,
        downloadOptions: drive.DownloadOptions.fullMedia,
        $fields: '',
      ) as drive.Media;

      final bytes = <int>[];
      await for (final chunk in media.stream) {
        bytes.addAll(chunk);
      }
      return jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  // ─── Slot pazienti (cartella interna app) ─────────────────

  Future<Directory> _cartellaPazienti() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir  = Directory('${docs.path}/pazienti');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static String _sanitizza(String s) => s
      .toLowerCase()
      .replaceAll(' ', '_')
      .replaceAll(RegExp(r'[^a-z0-9_]'), '');

  static String slotKey(String nome, String cognome) =>
      '${_sanitizza(nome)}_${_sanitizza(cognome)}';

  Future<bool> salvaSlotCorrente() async {
    try {
      final repo = LocalRepository();
      await repo.init();
      final paz = await repo.getPaziente();
      if (paz == null) return false;
      final key  = slotKey(paz.nome, paz.cognome);
      final dir  = await _cartellaPazienti();
      final dati = await repo.exportAll();
      await File('${dir.path}/$key.json').writeAsString(
          const JsonEncoder.withIndent('  ').convert(dati), encoding: utf8);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> caricaSlot(String key) async {
    try {
      final dir  = await _cartellaPazienti();
      final file = File('${dir.path}/$key.json');
      if (!await file.exists()) return false;
      final dati = jsonDecode(await file.readAsString(encoding: utf8))
          as Map<String, dynamic>;
      final repo = LocalRepository();
      await repo.init();
      await repo.importAll(dati);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<List<SlotPaziente>> elencaSlot() async {
    final result = <SlotPaziente>[];
    try {
      final dir = await _cartellaPazienti();
      final files = dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.json'))
          .toList()
        ..sort((a, b) =>
            b.lastModifiedSync().compareTo(a.lastModifiedSync()));
      for (final f in files.take(5)) {
        try {
          final data = jsonDecode(await f.readAsString(encoding: utf8))
              as Map<String, dynamic>;
          final paz = data['paziente'] as Map<String, dynamic>?;
          if (paz != null) {
            final nome    = paz['nome'] as String? ?? '';
            final cognome = paz['cognome'] as String? ?? '';
            if (nome.isNotEmpty) {
              result.add(SlotPaziente(
                key: f.path.split(Platform.pathSeparator).last
                    .replaceAll('.json', ''),
                nome: nome,
                cognome: cognome,
                ultimaModifica: f.lastModifiedSync(),
              ));
            }
          }
        } catch (_) {}
      }
    } catch (_) {}
    return result;
  }

  Future<void> eliminaSlot(String key) async {
    try {
      final dir  = await _cartellaPazienti();
      final file = File('${dir.path}/$key.json');
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  // ─── Helpers ──────────────────────────────────────────────

  Future<Directory?> _cartellaDocumenti() async {
    try {
      if (Platform.isWindows) {
        final home = Platform.environment['USERPROFILE'] ?? '';
        return Directory('$home\\Documents');
      } else if (Platform.isAndroid) {
        return Directory('/storage/emulated/0/Documents');
      } else {
        return await getApplicationDocumentsDirectory();
      }
    } catch (_) {
      return null;
    }
  }

  String _p(int n) => n.toString().padLeft(2, '0');
}
