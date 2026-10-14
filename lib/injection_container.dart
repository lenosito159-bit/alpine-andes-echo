import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'features/pos/application/pos_cubit.dart';
import 'features/pos/domain/pos_repository.dart';
import 'features/pos/infrastructure/legacy_hive_importer.dart';
import 'features/pos/infrastructure/sqlite_pos_repository.dart';

final GetIt sl = GetIt.instance;
Future<void>? _initializing;

/// Register once, after SQLite and the first-run migration have succeeded.
Future<void> initializeDependencies() {
  if (sl.isRegistered<PosRepository>()) {
    if (!sl.isRegistered<PosCubit>()) sl.registerFactory<PosCubit>(() => PosCubit(sl<PosRepository>()));
    return Future<void>.value();
  }
  return _initializing ??= _prepare().whenComplete(() => _initializing = null);
}

Future<void> _prepare() async {
  final repository = await SqlitePosRepository.open(legacyLoader: LegacyHiveImporter.read);
  sl.registerSingleton<PosRepository>(repository);
  sl.registerFactory<PosCubit>(() => PosCubit(sl<PosRepository>()));
}

List<BlocProvider> getBlocProviders() => [
  BlocProvider<PosCubit>(create: (_) => sl<PosCubit>()..load()),
];
