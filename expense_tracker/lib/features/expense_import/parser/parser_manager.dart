import '../models/payment_receipt.dart';
import 'receipt_parser.dart';
import 'parsers/generic_parser.dart';

class ParserManager {
  final List<ReceiptParser> _parsers = [
    // GooglePayParser(),
    // PhonePeParser(),
    // PaytmParser(),
    GenericParser(),
  ];

  PaymentReceipt parse(String text) {
    for (final parser in _parsers) {
      if (parser.canParse(text)) {
        return parser.parse(text);
      }
    }

    return GenericParser().parse(text);
  }
}