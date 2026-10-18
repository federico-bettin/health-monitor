import 'package:hive_flutter/hive_flutter.dart';
import 'package:salute_bettin/core/constants.dart';
import 'package:salute_bettin/data/models/appuntamento.dart';
import 'package:salute_bettin/data/models/esame.dart';
import 'package:salute_bettin/data/models/farmaco.dart';
import 'package:salute_bettin/data/models/paziente.dart';
import 'package:salute_bettin/data/models/token_usage.dart';
import 'package:salute_bettin/data/models/visita.dart';
import 'package:salute_bettin/data/repositories/i_data_repository.dart';

class LocalRepository implements IDataRepository {
  Box<Paziente>? _pazienteBox;
  Box<Esame>? _esamiBox;
  Box<Visita>? _visiteBox;
  Box<Farmaco>? _farmaciBox;
  Box<Appuntamento>? _appuntamentiBox;
  Box<TokenUsage>? _tokenBox;

  @override
  Future<void> init() async {
    _pazienteBox = await Hive.openBox<Paziente>(AppConstants.boxPaziente);
    _esamiBox = await Hive.openBox<Esame>(AppConstants.boxEsami);
    _visiteBox = await Hive.openBox<Visita>(AppConstants.boxVisite);
    _farmaciBox = await Hive.openBox<Farmaco>(AppConstants.boxFarmaci);
    _appuntamentiBox =
        await Hive.openBox<Appuntamento>(AppConstants.boxAppuntamenti);
    _tokenBox = await Hive.openBox<TokenUsage>(AppConstants.boxTokenUsage);
  }

  @override
  Future<void> dispose() async {
    await _pazienteBox?.close();
    await _esamiBox?.close();
    await _visiteBox?.close();
    await _farmaciBox?.close();
    await _appuntamentiBox?.close();
    await _tokenBox?.close();
  }

  @override
  Future<Paziente?> getPaziente() async => _pazienteBox?.get('paziente');

  @override
  Future<void> savePaziente(Paziente paziente) async =>
      _pazienteBox?.put('paziente', paziente);

  @override
  Future<List<Esame>> getEsami() async => _esamiBox?.values.toList() ?? [];

  @override
  Future<Esame?> getEsame(String id) async => _esamiBox?.get(id);

  @override
  Future<void> saveEsame(Esame esame) async => _esamiBox?.put(esame.id, esame);

  @override
  Future<void> deleteEsame(String id) async => _esamiBox?.delete(id);

  @override
  Future<List<Visita>> getVisite() async => _visiteBox?.values.toList() ?? [];

  @override
  Future<Visita?> getVisita(String id) async => _visiteBox?.get(id);

  @override
  Future<void> saveVisita(Visita visita) async =>
      _visiteBox?.put(visita.id, visita);

  @override
  Future<void> deleteVisita(String id) async => _visiteBox?.delete(id);

  @override
  Future<List<Farmaco>> getFarmaci() async =>
      _farmaciBox?.values.toList() ?? [];

  @override
  Future<Farmaco?> getFarmaco(String id) async => _farmaciBox?.get(id);

  @override
  Future<void> saveFarmaco(Farmaco farmaco) async =>
      _farmaciBox?.put(farmaco.id, farmaco);

  @override
  Future<void> deleteFarmaco(String id) async => _farmaciBox?.delete(id);

  @override
  Future<List<Appuntamento>> getAppuntamenti() async =>
      _appuntamentiBox?.values.toList() ?? [];

  @override
  Future<Appuntamento?> getAppuntamento(String id) async =>
      _appuntamentiBox?.get(id);

  @override
  Future<void> saveAppuntamento(Appuntamento appuntamento) async =>
      _appuntamentiBox?.put(appuntamento.id, appuntamento);

  @override
  Future<void> deleteAppuntamento(String id) async =>
      _appuntamentiBox?.delete(id);

  @override
  Future<List<TokenUsage>> getTokenUsage() async =>
      _tokenBox?.values.toList() ?? [];

  @override
  Future<void> saveTokenUsage(TokenUsage usage) async => _tokenBox?.add(usage);

  @override
  Future<void> clear() async {
    await _pazienteBox?.clear();
    await _esamiBox?.clear();
    await _visiteBox?.clear();
    await _farmaciBox?.clear();
    await _appuntamentiBox?.clear();
    await _tokenBox?.clear();
  }

  @override
  Future<Map<String, dynamic>> exportAll() async {
    final paziente = await getPaziente();
    return {
      'paziente': paziente?.toJson(),
      'esami': (await getEsami()).map((e) => e.toJson()).toList(),
      'visite': (await getVisite()).map((v) => v.toJson()).toList(),
      'farmaci': (await getFarmaci()).map((f) => f.toJson()).toList(),
      'appuntamenti': (await getAppuntamenti()).map((a) => a.toJson()).toList(),
      'exportedAt': DateTime.now().toIso8601String(),
    };
  }

  @override
  Future<void> importAll(Map<String, dynamic> data) async {
    await clear();
    if (data['paziente'] != null) {
      await savePaziente(Paziente.fromJson(data['paziente']));
    }
    for (final e in (data['esami'] as List? ?? [])) {
      await saveEsame(Esame.fromJson(e));
    }
    for (final v in (data['visite'] as List? ?? [])) {
      await saveVisita(Visita.fromJson(v));
    }
    for (final f in (data['farmaci'] as List? ?? [])) {
      await saveFarmaco(Farmaco.fromJson(f));
    }
    for (final a in (data['appuntamenti'] as List? ?? [])) {
      await saveAppuntamento(Appuntamento.fromJson(a));
    }
  }
}
