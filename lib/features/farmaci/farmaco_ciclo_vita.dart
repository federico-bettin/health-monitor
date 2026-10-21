import 'package:salute_bettin/data/models/farmaco.dart';
import 'package:salute_bettin/data/repositories/i_data_repository.dart';

/// Elimina un farmaco, oppure lo archivia se ha un registro assunzioni.
///
/// - Con registro assunzioni → `archiviato = true`, promemoria spento: sparisce
///   dalla lista attiva ma lo storico resta consultabile.
/// - Senza registro → cancellazione vera.
///
/// Ritorna `true` se il farmaco è stato archiviato, `false` se cancellato.
/// Dopo la chiamata va ricostruita la pianificazione delle notifiche.
Future<bool> eliminaOArchiviaFarmaco(IDataRepository repo, Farmaco f) async {
  final registro = await repo.getAssunzioniFarmaco(f.id);
  if (registro.isEmpty) {
    await repo.deleteFarmaco(f.id);
    return false;
  }
  f.archiviato = true;
  f.promemoriaAttivo = false;
  f.updatedAt = DateTime.now();
  await repo.saveFarmaco(f);
  return true;
}
