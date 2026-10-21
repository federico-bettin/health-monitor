import 'dart:convert';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/auth_io.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:salute_bettin/core/constants.dart';
import 'package:salute_bettin/data/models/appuntamento.dart';
import 'package:salute_bettin/data/models/assunzione_farmaco.dart';
import 'package:salute_bettin/data/models/esame.dart';
import 'package:salute_bettin/data/models/farmaco.dart';
import 'package:salute_bettin/data/models/paziente.dart';
import 'package:salute_bettin/data/models/token_usage.dart';
import 'package:salute_bettin/data/models/visita.dart';
import 'i_data_repository.dart';

class DriveRepository implements IDataRepository {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [drive.DriveApi.driveFileScope],
  );

  drive.DriveApi? _driveApi;
  String? _folderId;
  String? _dataFileId;

  // Cache locale in memoria
  Map<String, dynamic> _cache = {};

  @override
  Future<void> init() async {
    await _signIn();
    await _initFolder();
    await _loadFromDrive();
  }

  @override
  Future<void> dispose() async {
    _driveApi = null;
    _cache = {};
  }

  // ─── Auth ─────────────────────────────────────────────────
  Future<void> _signIn() async {
    final account = await _googleSignIn.signInSilently() ??
        await _googleSignIn.signIn();
    if (account == null) throw Exception('Login Google annullato');

    final auth = await account.authentication;
    final credentials = AccessCredentials(
      AccessToken('Bearer', auth.accessToken!, DateTime.now()
          .toUtc()
          .add(const Duration(hours: 1))),
      auth.idToken,
      [drive.DriveApi.driveFileScope],
    );
    final client = authenticatedClient(http.Client(), credentials);
    _driveApi = drive.DriveApi(client);
  }

  // ─── Cartella SaluteBettin su Drive ───────────────────────
  Future<void> _initFolder() async {
    final api = _driveApi!;

    // Cerca la cartella esistente
    final result = await api.files.list(
      q: "name='${AppConstants.driveFolderName}' and mimeType='application/vnd.google-apps.folder' and trashed=false",
      spaces: 'drive',
    );

    if (result.files != null && result.files!.isNotEmpty) {
      _folderId = result.files!.first.id;
    } else {
      // Crea la cartella
      final folder = drive.File()
        ..name = AppConstants.driveFolderName
        ..mimeType = 'application/vnd.google-apps.folder';
      final created = await api.files.create(folder);
      _folderId = created.id;
    }

    // Cerca il file data.json
    final dataResult = await api.files.list(
      q: "name='${AppConstants.driveDataFile}' and '${_folderId}' in parents and trashed=false",
      spaces: 'drive',
    );

    if (dataResult.files != null && dataResult.files!.isNotEmpty) {
      _dataFileId = dataResult.files!.first.id;
    }
  }

  // ─── Carica dati da Drive ─────────────────────────────────
  Future<void> _loadFromDrive() async {
    if (_dataFileId == null) {
      _cache = _emptyData();
      return;
    }

    final response = await _driveApi!.files.get(
      _dataFileId!,
      downloadOptions: drive.DownloadOptions.fullMedia,
    ) as drive.Media;

    final bytes = <int>[];
    await for (final chunk in response.stream) {
      bytes.addAll(chunk);
    }
    final json = utf8.decode(bytes);
    _cache = jsonDecode(json);
  }

  // ─── Salva dati su Drive ──────────────────────────────────
  Future<void> _saveToDrive() async {
    final json = jsonEncode(_cache);
    final bytes = utf8.encode(json);
    final stream = Stream.fromIterable([bytes]);
    final media = drive.Media(stream, bytes.length);

    if (_dataFileId == null) {
      // Crea il file
      final file = drive.File()
        ..name = AppConstants.driveDataFile
        ..parents = [_folderId!];
      final created = await _driveApi!.files.create(file, uploadMedia: media);
      _dataFileId = created.id;
    } else {
      // Aggiorna il file esistente
      await _driveApi!.files.update(
        drive.File(),
        _dataFileId!,
        uploadMedia: media,
      );
    }
  }

  Map<String, dynamic> _emptyData() => {
        'paziente': null,
        'esami': [],
        'visite': [],
        'farmaci': [],
        'assunzioni': [],
        'appuntamenti': [],
        'updatedAt': DateTime.now().toIso8601String(),
      };

  // ─── Paziente ─────────────────────────────────────────────
  @override
  Future<Paziente?> getPaziente() async {
    final data = _cache['paziente'];
    if (data == null) return null;
    return Paziente.fromJson(data);
  }

  @override
  Future<void> savePaziente(Paziente paziente) async {
    _cache['paziente'] = paziente.toJson();
    _cache['updatedAt'] = DateTime.now().toIso8601String();
    await _saveToDrive();
  }

  // ─── Esami ────────────────────────────────────────────────
  @override
  Future<List<Esame>> getEsami() async {
    return ((_cache['esami'] as List?) ?? [])
        .map((e) => Esame.fromJson(e))
        .toList();
  }

  @override
  Future<Esame?> getEsame(String id) async {
    final list = await getEsami();
    try {
      return list.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveEsame(Esame esame) async {
    final list = List<dynamic>.from(_cache['esami'] ?? []);
    final idx = list.indexWhere((e) => e['id'] == esame.id);
    if (idx >= 0) {
      list[idx] = esame.toJson();
    } else {
      list.add(esame.toJson());
    }
    _cache['esami'] = list;
    _cache['updatedAt'] = DateTime.now().toIso8601String();
    await _saveToDrive();
  }

  @override
  Future<void> deleteEsame(String id) async {
    final list = List<dynamic>.from(_cache['esami'] ?? []);
    list.removeWhere((e) => e['id'] == id);
    _cache['esami'] = list;
    await _saveToDrive();
  }

  // ─── Visite ───────────────────────────────────────────────
  @override
  Future<List<Visita>> getVisite() async {
    return ((_cache['visite'] as List?) ?? [])
        .map((v) => Visita.fromJson(v))
        .toList();
  }

  @override
  Future<Visita?> getVisita(String id) async {
    final list = await getVisite();
    try {
      return list.firstWhere((v) => v.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveVisita(Visita visita) async {
    final list = List<dynamic>.from(_cache['visite'] ?? []);
    final idx = list.indexWhere((v) => v['id'] == visita.id);
    if (idx >= 0) {
      list[idx] = visita.toJson();
    } else {
      list.add(visita.toJson());
    }
    _cache['visite'] = list;
    _cache['updatedAt'] = DateTime.now().toIso8601String();
    await _saveToDrive();
  }

  @override
  Future<void> deleteVisita(String id) async {
    final list = List<dynamic>.from(_cache['visite'] ?? []);
    list.removeWhere((v) => v['id'] == id);
    _cache['visite'] = list;
    await _saveToDrive();
  }

  // ─── Farmaci ──────────────────────────────────────────────
  @override
  Future<List<Farmaco>> getFarmaci() async {
    return ((_cache['farmaci'] as List?) ?? [])
        .map((f) => Farmaco.fromJson(f))
        .toList();
  }

  @override
  Future<Farmaco?> getFarmaco(String id) async {
    final list = await getFarmaci();
    try {
      return list.firstWhere((f) => f.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveFarmaco(Farmaco farmaco) async {
    final list = List<dynamic>.from(_cache['farmaci'] ?? []);
    final idx = list.indexWhere((f) => f['id'] == farmaco.id);
    if (idx >= 0) {
      list[idx] = farmaco.toJson();
    } else {
      list.add(farmaco.toJson());
    }
    _cache['farmaci'] = list;
    _cache['updatedAt'] = DateTime.now().toIso8601String();
    await _saveToDrive();
  }

  @override
  Future<void> deleteFarmaco(String id) async {
    final list = List<dynamic>.from(_cache['farmaci'] ?? []);
    list.removeWhere((f) => f['id'] == id);
    _cache['farmaci'] = list;
    await _saveToDrive();
  }

  // ─── Registro assunzioni ──────────────────────────────────
  List<AssunzioneFarmaco> _tutteAssunzioni() => ((_cache['assunzioni'] as List?) ?? [])
      .map((x) => AssunzioneFarmaco.fromJson(Map<String, dynamic>.from(x)))
      .toList();

  @override
  Future<List<AssunzioneFarmaco>> getAssunzioni(DateTime da, DateTime a) async {
    final list = _tutteAssunzioni().where((x) {
      final r = x.riferimento;
      return r != null && !r.isBefore(da) && r.isBefore(a);
    }).toList();
    list.sort((x, y) => y.riferimento!.compareTo(x.riferimento!));
    return list;
  }

  @override
  Future<List<AssunzioneFarmaco>> getAssunzioniFarmaco(String farmacoId) async {
    final list =
        _tutteAssunzioni().where((x) => x.farmacoId == farmacoId).toList();
    list.sort((x, y) => (y.riferimento ?? DateTime(2000))
        .compareTo(x.riferimento ?? DateTime(2000)));
    return list;
  }

  @override
  Future<void> saveAssunzione(AssunzioneFarmaco assunzione) async {
    final list = List<dynamic>.from(_cache['assunzioni'] ?? []);
    final idx = list.indexWhere((x) => x['id'] == assunzione.id);
    if (idx >= 0) {
      list[idx] = assunzione.toJson();
    } else {
      list.add(assunzione.toJson());
    }
    _cache['assunzioni'] = list;
    _cache['updatedAt'] = DateTime.now().toIso8601String();
    await _saveToDrive();
  }

  @override
  Future<void> deleteAssunzione(String id) async {
    final list = List<dynamic>.from(_cache['assunzioni'] ?? []);
    list.removeWhere((x) => x['id'] == id);
    _cache['assunzioni'] = list;
    await _saveToDrive();
  }

  // ─── Appuntamenti ─────────────────────────────────────────
  @override
  Future<List<Appuntamento>> getAppuntamenti() async {
    return ((_cache['appuntamenti'] as List?) ?? [])
        .map((a) => Appuntamento.fromJson(a))
        .toList();
  }

  @override
  Future<Appuntamento?> getAppuntamento(String id) async {
    final list = await getAppuntamenti();
    try {
      return list.firstWhere((a) => a.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveAppuntamento(Appuntamento appuntamento) async {
    final list = List<dynamic>.from(_cache['appuntamenti'] ?? []);
    final idx = list.indexWhere((a) => a['id'] == appuntamento.id);
    if (idx >= 0) {
      list[idx] = appuntamento.toJson();
    } else {
      list.add(appuntamento.toJson());
    }
    _cache['appuntamenti'] = list;
    _cache['updatedAt'] = DateTime.now().toIso8601String();
    await _saveToDrive();
  }

  @override
  Future<void> deleteAppuntamento(String id) async {
    final list = List<dynamic>.from(_cache['appuntamenti'] ?? []);
    list.removeWhere((a) => a['id'] == id);
    _cache['appuntamenti'] = list;
    await _saveToDrive();
  }

  // ─── Token Usage ──────────────────────────────────────────
  @override
  Future<List<TokenUsage>> getTokenUsage() async {
    return ((_cache['tokenUsage'] as List?) ?? [])
        .map((t) => TokenUsage.fromJson(t))
        .toList();
  }

  @override
  Future<void> saveTokenUsage(TokenUsage usage) async {
    final list = List<dynamic>.from(_cache['tokenUsage'] ?? []);
    list.add(usage.toJson());
    _cache['tokenUsage'] = list;
    await _saveToDrive();
  }

  // ─── Utilità ──────────────────────────────────────────────
  @override
  Future<void> clear() async {
    _cache = _emptyData();
    await _saveToDrive();
  }

  @override
  Future<Map<String, dynamic>> exportAll() async {
    return Map<String, dynamic>.from(_cache);
  }

  @override
  Future<void> importAll(Map<String, dynamic> data) async {
    _cache = data;
    _cache['updatedAt'] = DateTime.now().toIso8601String();
    await _saveToDrive();
  }
}
