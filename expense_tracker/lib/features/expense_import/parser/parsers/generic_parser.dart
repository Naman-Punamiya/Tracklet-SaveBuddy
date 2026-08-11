import '../../models/payment_receipt.dart';
import '../receipt_parser.dart';

class GenericParser implements ReceiptParser {
  @override
  bool canParse(String text) => true;

  @override
  PaymentReceipt parse(String text) {
    return PaymentReceipt(rawText: text, source: "Unknown");
  }
}
