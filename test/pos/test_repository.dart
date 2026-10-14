import 'dart:convert';
import 'package:zivlo/features/pos/domain/pos_engine.dart';
import 'package:zivlo/features/pos/domain/pos_repository.dart';

class TestPosRepository implements PosRepository {
  TestPosRepository({PosState? initial}) : data = initial ?? PosState.demo();
  PosState data;
  final engine = PosEngine();
  Future<void>? barrier;
  bool failWrites = false;
  int writes = 0;
  String? recovery;
  @override
  Future<PosState> load() async => data;
  @override
  Future<PosState> dispatch(Map<String, dynamic> action, {required int expectedRevision}) async {
    writes++;
    if (barrier != null) await barrier;
    if (failWrites) throw Exception('Simulated durable write failure');
    if (data.revision != expectedRevision) throw const PosException('Revisión desactualizada');
    data = engine.dispatch(data, action); return data;
  }
  @override
  Future<String> exportBackup() async => jsonEncode(data.toJson());
  @override
  Future<String?> exportRecoveryBackup() async => recovery;
  @override
  Future<PosState> restoreBackup(String json, {required int expectedRevision}) async {
    if (failWrites) throw Exception('Simulated durable write failure');
    if (data.revision != expectedRevision) throw const PosException('Revisión desactualizada');
    final incoming = PosState.fromJson(jsonDecode(json) as Map<String, dynamic>).toJson();
    recovery = jsonEncode(data.toJson()); incoming['revision'] = data.revision + 1;
    data = PosState.fromJson(incoming); return data;
  }
  @override
  Future<void> close() async {}
}
