/// Integration boundary only. Commercial receipts never call this gateway.
/// A real implementation needs merchant enrollment, tax configuration and
/// authenticated responses from SUNAT or an authorized provider.
enum FiscalReceiptStatus { pending, accepted, rejected }

class FiscalReceiptResult {
  const FiscalReceiptResult({required this.status, required this.externalId,
    this.message, this.acceptanceDocument});
  final FiscalReceiptStatus status;
  final String externalId;
  final String? message;
  final List<int>? acceptanceDocument;
}

abstract class FiscalReceiptGateway {
  /// The caller must validate the full fiscal payload and use a stable sale ID
  /// as the idempotency key. Transport success is not fiscal acceptance.
  Future<FiscalReceiptResult> submit({required String idempotencyKey,
    required Map<String, dynamic> validatedFiscalPayload});
  Future<FiscalReceiptResult> status(String externalId);
}
