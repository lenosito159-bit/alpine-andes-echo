import 'package:flutter_bloc/flutter_bloc.dart';
import '../domain/pos_engine.dart';
import '../domain/pos_repository.dart';

class PosViewState {
  const PosViewState({this.data, this.busy = false, this.error});
  final PosState? data;
  final bool busy;
  final String? error;
}

/// Screen state coordinates the durable repository; it never edits balances.
class PosCubit extends Cubit<PosViewState> {
  PosCubit(this.repository) : super(const PosViewState());
  final PosRepository repository;

  Future<void> load() async {
    if (state.busy || isClosed) return;
    emit(PosViewState(data: state.data, busy: true));
    try {
      final data = await repository.load();
      if (!isClosed) emit(PosViewState(data: data));
    } catch (error) {
      if (!isClosed) emit(PosViewState(data: state.data, error: _message(error)));
    }
  }

  Future<bool> run(Map<String, dynamic> action) async {
    if (state.busy || state.data == null || isClosed) return false;
    final current = state.data!;
    emit(PosViewState(data: current, busy: true));
    try {
      final next = await repository.dispatch(action, expectedRevision: current.revision);
      if (!isClosed) emit(PosViewState(data: next));
      return true;
    } catch (error) {
      PosState data = current;
      try { data = await repository.load(); } catch (_) { /* Retain the last known state. */ }
      if (!isClosed) emit(PosViewState(data: data, error: _message(error)));
      return false;
    }
  }

  Future<String> exportBackup() => repository.exportBackup();
  Future<String?> exportRecoveryBackup() => repository.exportRecoveryBackup();

  Future<bool> restoreBackup(String json) async {
    if (state.busy || state.data == null || isClosed) return false;
    final current = state.data!;
    emit(PosViewState(data: current, busy: true));
    try {
      final next = await repository.restoreBackup(json, expectedRevision: current.revision);
      if (!isClosed) emit(PosViewState(data: next));
      return true;
    } catch (error) {
      PosState data = current;
      try { data = await repository.load(); } catch (_) { /* Keep the previous snapshot. */ }
      if (!isClosed) emit(PosViewState(data: data, error: _message(error)));
      return false;
    }
  }

  String _message(Object error) => error is PosException
      ? error.message
      : 'No se guardó la operación. Revisa el almacenamiento del dispositivo y vuelve a intentar.';
}
