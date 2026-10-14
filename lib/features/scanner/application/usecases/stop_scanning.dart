import 'package:fpdart/fpdart.dart';

import 'package:zivlo/core/error/failures.dart';
import 'package:zivlo/features/scanner/domain/ports/scanner_port.dart';
/// Use Case: Stop Scanning
/// Stops the barcode scanning process
///
/// This use case wraps the scanner port's stopScanning method
/// and returns an Either type for error handling.
class StopScanning {
  final IScannerPort scannerPort;

  const StopScanning(this.scannerPort);

  Future<Either<Failure, Unit>> execute() {
    return scannerPort.stopScanning();
  }
}
