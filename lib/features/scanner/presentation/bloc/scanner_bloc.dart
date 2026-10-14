import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fpdart/fpdart.dart';
import 'package:zivlo/core/error/failures.dart';
import 'package:zivlo/features/checkout/domain/repositories/cart_repository.dart';
import 'package:zivlo/features/scanner/domain/entities/scan_result.dart';
import 'package:zivlo/features/scanner/domain/ports/scanner_port.dart';
import 'package:zivlo/features/scanner/application/usecases/start_scanning.dart';
import 'package:zivlo/features/scanner/application/usecases/stop_scanning.dart';
import 'package:zivlo/features/scanner/application/usecases/handle_scan_result.dart';
import 'scanner_event.dart';
import 'scanner_state.dart';

class ScannerBloc extends Bloc<ScannerEvent, ScannerState> {
  final StartScanning startScanning;
  final StopScanning stopScanning;
  final HandleScanResult handleScanResult;
  final IScannerPort scannerPort;
  final ICartRepository cartRepository;
  final Future<void> Function()? disposeScanner;
  StreamSubscription<Either<Failure, ScanResult>>? _scanSubscription;
  bool _acceptScans = false;
  bool _addingToCart = false;

  ScannerBloc({
    required this.startScanning,
    required this.stopScanning,
    required this.handleScanResult,
    required this.scannerPort,
    required this.cartRepository,
    this.disposeScanner,
  }) : super(const ScannerInitial()) {
    on<ScannerStarted>(_onStarted);
    on<ScannerStopped>(_onStopped);
    on<BarcodeScanned>(_onBarcode);
    on<ProductLookupCompleted>((event, emit) => _showResult(event.result, emit));
    on<FlashToggled>(_onFlash);
    on<ScannerError>((event, emit) => emit(ScannerErrorState(event.message)));
    on<AddToCartRequested>(_onAddToCart);
    _scanSubscription = scannerPort.scanResults.listen((result) {
      if (isClosed || !_acceptScans) return;
      result.fold(
        (failure) => add(ScannerError(failure.message)),
        (scan) => add(BarcodeScanned(scan.barcode)),
      );
    });
  }

  Future<void> _onStarted(ScannerStarted event, Emitter<ScannerState> emit) async {
    _acceptScans = false;
    final result = await startScanning.execute();
    if (emit.isDone) return;
    result.fold(
      (failure) => emit(ScannerErrorState(failure.message)),
      (_) {
        _acceptScans = true;
        emit(const ScannerActive());
      },
    );
  }

  Future<void> _onStopped(ScannerStopped event, Emitter<ScannerState> emit) async {
    _acceptScans = false;
    await stopScanning.execute();
    if (!emit.isDone) emit(const ScannerInitial());
  }

  Future<void> _onBarcode(BarcodeScanned event, Emitter<ScannerState> emit) async {
    // One lookup/dialog at a time, including repeated camera detections.
    if (!_acceptScans) return;
    _acceptScans = false;
    await stopScanning.execute();
    final result = await handleScanResult.execute(event.barcode);
    if (emit.isDone) return;
    result.fold(
      (failure) => emit(ScannerErrorState(failure.message)),
      (scan) => _showResult(scan, emit),
    );
  }

  void _showResult(ScanResult result, Emitter<ScannerState> emit) {
    if (result.isProductFound) {
      emit(ScannerProductFound(result));
    } else {
      emit(ScannerProductNotFound(result.barcode));
    }
  }

  Future<void> _onFlash(FlashToggled event, Emitter<ScannerState> emit) async {
    final result = await scannerPort.toggleFlash(event.enabled);
    if (emit.isDone) return;
    result.fold(
      (failure) => emit(ScannerErrorState(failure.message)),
      (_) => emit(event.enabled ? const ScannerFlashEnabled() : const ScannerFlashDisabled()),
    );
  }

  Future<void> _onAddToCart(AddToCartRequested event, Emitter<ScannerState> emit) async {
    if (_addingToCart) return;
    final product = event.result.product;
    if (product == null || event.quantity <= 0) {
      emit(const ScannerErrorState('Selecciona un producto y una cantidad válida'));
      return;
    }
    _addingToCart = true;
    emit(const ScannerAddingToCart());
    try {
      final result = await cartRepository.addProduct(product, quantity: event.quantity);
      if (emit.isDone) return;
      result.fold(
        (failure) => emit(ScannerErrorState(failure.message)),
        (_) => emit(ScannerCartUpdated(product.name, event.quantity)),
      );
    } finally {
      _addingToCart = false;
    }
  }

  @override
  Future<void> close() async {
    _acceptScans = false;
    await _scanSubscription?.cancel();
    await stopScanning.execute();
    await super.close();
    await disposeScanner?.call();
  }
}
