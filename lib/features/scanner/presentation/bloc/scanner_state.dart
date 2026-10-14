import 'package:equatable/equatable.dart';
import 'package:zivlo/features/scanner/domain/entities/scan_result.dart';
/// Scanner State - Base class
/// All scanner states extend this class
abstract class ScannerState extends Equatable {
  const ScannerState();

  @override
  List<Object?> get props => [];
}

/// Initial state
/// Before scanning starts
class ScannerInitial extends ScannerState {
  const ScannerInitial();

  @override
  List<Object?> get props => [];
}

/// Scanner active state
/// Camera is running and ready to scan
class ScannerActive extends ScannerState {
  const ScannerActive();

  @override
  List<Object?> get props => [];
}

/// Product found state
/// A product was found in the catalog for the scanned barcode
/// Contains the scan result with product information
class ScannerProductFound extends ScannerState {
  final ScanResult result;

  const ScannerProductFound(this.result);

  @override
  List<Object?> get props => [result];
}

/// Product not found state
/// No product was found in the catalog for the scanned barcode
/// Contains the barcode value
class ScannerProductNotFound extends ScannerState {
  final String barcode;

  const ScannerProductNotFound(this.barcode);

  @override
  List<Object?> get props => [barcode];
}

/// Scanner error state
/// An error occurred during scanning
/// Contains the error message
class ScannerErrorState extends ScannerState {
  final String message;

  const ScannerErrorState(this.message);

  @override
  List<Object?> get props => [message];
}

/// Flash enabled state
/// Flash/torch is turned on
class ScannerFlashEnabled extends ScannerState {
  const ScannerFlashEnabled();

  @override
  List<Object?> get props => [];
}

/// Flash disabled state
/// Flash/torch is turned off
class ScannerFlashDisabled extends ScannerState {
  const ScannerFlashDisabled();

  @override
  List<Object?> get props => [];
}

class ScannerAddingToCart extends ScannerState {
  const ScannerAddingToCart();
}

class ScannerCartUpdated extends ScannerState {
  final String productName;
  final int quantity;

  const ScannerCartUpdated(this.productName, this.quantity);

  @override
  List<Object?> get props => [productName, quantity];
}
