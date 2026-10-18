import 'package:salute_bettin/core/constants.dart';
import 'package:salute_bettin/data/sync/conflict_detector.dart';
import 'drive_repository.dart';
import 'i_data_repository.dart';
import 'local_repository.dart';
import 'sync_repository.dart';

class RepositoryFactory {
  RepositoryFactory._();

  static IDataRepository create(
    String storageMode, {
    void Function(List<ConflictItem>)? onConflicts,
  }) {
    switch (storageMode) {
      case AppConstants.storageModeDrive:
        return DriveRepository();
      case AppConstants.storageModeSync:
        return SyncRepository(onConflicts: onConflicts);
      case AppConstants.storageModeLocal:
      default:
        return LocalRepository();
    }
  }
}
