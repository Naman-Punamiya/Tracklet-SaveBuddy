import '../models/payment_receipt.dart';

abstract class ReceiptParser {
  bool canParse(String text);

  PaymentReceipt parse(String text);
}