import 'package:fpdart/fpdart.dart';

import 'package:zivlo/core/error/failures.dart';
import 'package:zivlo/features/scanner/domain/ports/scanner_port.dart';
/// Use Case: Start Scanning
/// Starts the barcode scanning process
///
/// This use case wraps the scanner port's startScanning method
/// and returns an Either type for error handling.
class StartScanning {
  final IScannerPort scannerPort;

  const StartScanning(this.scannerPort);

  Future<Either<Failure, Unit>> execute() {
    return scannerPort.startScanning();
  }
}
