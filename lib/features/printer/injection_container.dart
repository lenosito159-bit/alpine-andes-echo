import 'package:zivlo/injection_container.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

// Domain - Port
import 'package:zivlo/features/printer/domain/ports/printer_port.dart';

// Infrastructure - Adapters
import 'package:zivlo/features/printer/infrastructure/adapters/bluetooth_printer_adapter.dart';

// Infrastructure - Repositories
import 'package:zivlo/features/printer/infrastructure/repositories/hive_printer_repository.dart';

// Application - Use Cases
import 'package:zivlo/features/printer/application/usecases/discover_printers.dart';
import 'package:zivlo/features/printer/application/usecases/connect_printer.dart';
import 'package:zivlo/features/printer/application/usecases/disconnect_printer.dart';
import 'package:zivlo/features/printer/application/usecases/print_receipt.dart';
import 'package:zivlo/features/printer/application/usecases/generate_receipt.dart';

// Presentation - BLoC
import 'package:zivlo/features/printer/presentation/bloc/printer_bloc.dart';

/// Initialize printer feature dependencies
/// Uses the global service locator from lib/injection_container.dart
void initializeDependencies() {
  // Register Printer Repository (LazySingleton - single instance)
  sl.registerLazySingleton<HivePrinterRepository>(
    () => HivePrinterRepository()..initialize(),
  );

  // Register Printer Port (LazySingleton - single instance)
  // Using mock adapter for now - replace with real Bluetooth adapter later
  sl.registerLazySingleton<IPrinterPort>(
    () => MockBluetoothPrinterAdapter(),
  );

  // Register Use Cases (LazySingleton - stateless)
  sl.registerLazySingleton(() => DiscoverPrinters(sl()));
  sl.registerLazySingleton(() => ConnectPrinter(sl()));
  sl.registerLazySingleton(() => DisconnectPrinter(sl()));
  sl.registerLazySingleton(() => PrintReceipt(sl()));
  sl.registerLazySingleton(() => GenerateReceipt());

  // Register BLoC (Factory - new instance per widget)
  sl.registerFactory(() => PrinterBloc(
        discoverPrinters: sl(),
        connectPrinter: sl(),
        disconnectPrinter: sl(),
        printReceipt: sl(),
        printerRepository: sl(),
        printerPort: sl(),
      ));
}

/// Get BLoC providers for this feature
List<BlocProvider> getBlocProviders() {
  return [
    BlocProvider<PrinterBloc>(create: (_) => sl<PrinterBloc>()),
  ];
}
