import 'dart:async';

import 'package:fpdart/fpdart.dart';
import 'package:mobile_scanner/mobile_scanner.dart' as ms;
import 'package:zivlo/core/error/failures.dart';
import 'package:zivlo/core/domain/value_objects/barcode_format.dart';
import 'package:zivlo/features/scanner/domain/entities/scan_result.dart';
import 'package:zivlo/features/scanner/domain/ports/scanner_port.dart';

/// Owns the same controller used by the camera preview. Stopping the camera
/// pauses detection; only dispose closes the results stream permanently.
class MobileScannerAdapter implements IScannerPort {
  final ms.MobileScannerController controller;
  final _results = StreamController<Either<Failure, ScanResult>>.broadcast();
  StreamSubscription<ms.BarcodeCapture>? _subscription;

  MobileScannerAdapter({ms.MobileScannerController? controller})
      : controller = controller ?? ms.MobileScannerController(autoStart: false);

  @override
  Future<Either<Failure, Unit>> startScanning() async {
    try {
      _subscription ??= controller.barcodes.listen((capture) {
        for (final barcode in capture.barcodes) {
          final value = barcode.rawValue;
          if (value == null || value.trim().isEmpty || _results.isClosed) continue;
          _results.add(right(ScanResult(
            barcode: value,
            format: _mapBarcodeFormat(barcode.format),
            product: null,
            scannedAt: DateTime.now(),
          )));
          break;
        }
      }, onError: (Object error) {
        if (!_results.isClosed) _results.add(left(_failure(error)));
      });
      await controller.start();
      final error = controller.value.error;
      if (error != null) return left(_failure(error));
      return right(unit);
    } catch (error) {
      return left(_failure(error));
    }
  }

  @override
  Future<Either<Failure, Unit>> stopScanning() async {
    try {
      await _subscription?.cancel();
      _subscription = null;
      await controller.stop();
      return right(unit);
    } catch (error) {
      return left(_failure(error));
    }
  }

  @override
  Stream<Either<Failure, ScanResult>> get scanResults => _results.stream;

  @override
  Future<Either<Failure, Unit>> toggleFlash(bool enabled) async {
    try {
      final state = controller.value.torchState;
      if (state == ms.TorchState.unavailable) {
        return left(const ScannerFailure(message: 'La cámara no dispone de flash'));
      }
      if ((state == ms.TorchState.on) != enabled) await controller.toggleTorch();
      return right(unit);
    } catch (error) {
      return left(_failure(error));
    }
  }

  @override
  Either<Failure, bool> isFlashAvailable() =>
      right(controller.value.torchState != ms.TorchState.unavailable);

  Future<void> dispose() async {
    await stopScanning();
    await _results.close();
    await controller.dispose();
  }

  ScannerFailure _failure(Object error) => ScannerFailure(
        message: 'No se pudo usar la cámara: $error',
        exception: error is Exception ? error : Exception(error.toString()),
      );

  BarcodeFormat _mapBarcodeFormat(ms.BarcodeFormat format) {
    switch (format) {
      case ms.BarcodeFormat.ean13: return BarcodeFormat.ean13;
      case ms.BarcodeFormat.ean8: return BarcodeFormat.ean8;
      case ms.BarcodeFormat.qrCode: return BarcodeFormat.qrCode;
      case ms.BarcodeFormat.code128: return BarcodeFormat.code128;
      case ms.BarcodeFormat.code39: return BarcodeFormat.code39;
      case ms.BarcodeFormat.upcA: return BarcodeFormat.upcA;
      default: return BarcodeFormat.unknown;
    }
  }
}
