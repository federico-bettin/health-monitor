import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:salute_bettin/data/repositories/i_data_repository.dart';
import 'package:salute_bettin/data/repositories/local_repository.dart';
import 'package:salute_bettin/data/repositories/repository_factory.dart';
import 'package:salute_bettin/data/services/settings_service.dart';

/// Provider globale — usato nelle pagine ConsumerWidget/ConsumerStatefulWidget
final repositoryProvider = FutureProvider<IDataRepository>((ref) async {
  final mode = SettingsService.instance.storageMode;
  try {
    final repo = RepositoryFactory.create(mode);
    await repo.init();
    return repo;
  } catch (_) {
    // Se Drive fallisce (es. login non completato) → usa sempre locale
    final fallback = LocalRepository();
    await fallback.init();
    return fallback;
  }
});

/// Helper per pagine StatefulWidget senza accesso a ref
Future<IDataRepository> getRepo() async {
  final mode = SettingsService.instance.storageMode;
  try {
    final repo = RepositoryFactory.create(mode);
    await repo.init();
    return repo;
  } catch (_) {
    final fallback = LocalRepository();
    await fallback.init();
    return fallback;
  }
}
