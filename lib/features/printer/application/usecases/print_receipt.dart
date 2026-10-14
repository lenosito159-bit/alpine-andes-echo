import 'package:fpdart/fpdart.dart';
import 'package:zivlo/core/error/failures.dart';
import 'package:zivlo/features/printer/domain/entities/receipt.dart';
import 'package:zivlo/features/printer/domain/ports/printer_port.dart';
/// Use Case: Print Receipt
///
/// Prints a receipt to the connected Bluetooth thermal printer
/// Handles the complete printing process
///
/// This use case handles:
/// - Checking printer connection status
/// - Formatting receipt for thermal printing (ESC/POS)
/// - Sending print data to printer
/// - Handling print errors
class PrintReceipt {
  final IPrinterPort printerPort;

  const PrintReceipt(this.printerPort);

  /// Executes receipt printing
  ///
  /// [receipt] - The receipt entity to print
  ///
  /// Returns [Unit.value] on successful print
  /// Returns [Failure] if printing fails (not connected, printer error, etc.)
  Future<Either<Failure, Unit>> execute(Receipt receipt) async {
    try {
      // Check if printer is connected
      final isConnected = (await printerPort.isConnected()).fold(
        (failure) => false,
        (connected) => connected,
      );

      if (!isConnected) {
        return Left(const PrinterOperationFailure(
          operation: 'print',
          message: 'Printer is not connected',
        ));
      }

      // Print the receipt
      return await printerPort.printReceipt(receipt);
    } catch (e) {
      return Left(PrinterOperationFailure(
        operation: 'print',
        message: 'Failed to print receipt: ${e.toString()}',
        exception: e as Exception?,
      ));
    }
  }
}
