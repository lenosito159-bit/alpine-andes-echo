import 'package:fpdart/fpdart.dart';
import 'package:zivlo/core/error/failures.dart';
import 'package:zivlo/features/scanner/domain/entities/scan_result.dart';

/// Scanner Port (Interface)
/// Defines what the domain layer needs from the infrastructure layer
/// Implementation is done in infrastructure layer (e.g., CameraScannerAdapter)
/// 
/// This port abstracts the camera/scanner hardware operations,
/// allowing the domain layer to remain platform-agnostic.
abstract class IScannerPort {
  /// Starts the barcode scanning process
  /// Returns [Unit.value] on success, or a [Failure] if scanning cannot be started
  /// (e.g., camera permission denied, camera unavailable)
  Future<Either<Failure, Unit>> startScanning();

  /// Stops the barcode scanning process
  /// Returns [Unit.value] on success, or a [Failure] if stopping fails
  Future<Either<Failure, Unit>> stopScanning();

  /// Stream of scan results
  /// Emits a new [ScanResult] each time a barcode is successfully scanned
  /// Emits a [Failure] if a scan error occurs
  Stream<Either<Failure, ScanResult>> get scanResults;

  /// Toggles the camera flash on or off
  /// [enabled] - true to turn on flash, false to turn off
  /// Returns [Unit.value] on success, or a [Failure] if flash control fails
  /// (e.g., device has no flash, flash hardware error)
  Future<Either<Failure, Unit>> toggleFlash(bool enabled);

  /// Checks if the device has a flash available
  /// Returns [true] if flash is available, [false] otherwise
  /// Returns a [Failure] if the check cannot be performed
  Either<Failure, bool> isFlashAvailable();
}
