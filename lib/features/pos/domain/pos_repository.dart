import 'pos_engine.dart';

/// A mutation returns only after its entire transaction has been committed.
abstract class PosRepository {
  Future<PosState> load();
  Future<PosState> dispatch(Map<String, dynamic> action, {required int expectedRevision});
  Future<String> exportBackup();
  Future<PosState> restoreBackup(String json, {required int expectedRevision});
  Future<String?> exportRecoveryBackup();
  Future<void> close();
}
