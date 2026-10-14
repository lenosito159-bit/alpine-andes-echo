import 'package:flutter_bloc/flutter_bloc.dart';

// Global service locator
import 'package:zivlo/injection_container.dart';

// Domain - Port
import 'package:zivlo/features/scanner/domain/ports/scanner_port.dart';

// Infrastructure - Adapters
import 'package:zivlo/features/scanner/infrastructure/adapters/mobile_scanner_adapter.dart';

// Application - Use Cases
import 'package:zivlo/features/scanner/application/usecases/start_scanning.dart';
import 'package:zivlo/features/scanner/application/usecases/stop_scanning.dart';
import 'package:zivlo/features/scanner/application/usecases/lookup_product_by_barcode.dart';
import 'package:zivlo/features/scanner/application/usecases/handle_scan_result.dart';

// Catalog - Repository (needed for product lookup)


// Presentation - BLoC
import 'package:zivlo/features/scanner/presentation/bloc/scanner_bloc.dart';

/// Initialize scanner feature dependencies
/// Uses the global service locator from lib/injection_container.dart
void initializeDependencies() {
  // Each scanner BLoC owns one port. Start, stop and results must share it.
  sl.registerFactory<IScannerPort>(() => MobileScannerAdapter());

  // Register Use Cases (LazySingleton - stateless)
  sl.registerLazySingleton(() => LookupProductByBarcode(sl()));
  sl.registerLazySingleton(() => HandleScanResult(sl()));

  // Register BLoC (Factory - new instance per widget)
  sl.registerFactory(() {
    final port = sl<IScannerPort>();
    return ScannerBloc(
      startScanning: StartScanning(port),
      stopScanning: StopScanning(port),
      handleScanResult: sl(),
      scannerPort: port,
      cartRepository: sl(),
      disposeScanner: (port as MobileScannerAdapter).dispose,
    );
  });
}

/// Get BLoC providers for this feature
List<BlocProvider> getBlocProviders() {
  return [
    BlocProvider<ScannerBloc>(create: (_) => sl<ScannerBloc>()),
  ];
}
