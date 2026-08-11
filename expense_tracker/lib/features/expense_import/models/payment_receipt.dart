class PaymentReceipt {
  final String rawText;
  final String? source;
  final String? merchant;
  final double? amount;
  final DateTime? transactionDate;
  final String? transactionId;
  final String? payer;
  final String? payee;
  final bool isSuccessful;

  const PaymentReceipt({
    required this.rawText,
    this.source,
    this.merchant,
    this.amount,
    this.transactionDate,
    this.transactionId,
    this.payer,
    this.payee,
    this.isSuccessful = true,
  });

  @override
  String toString() {
    return '''
PaymentReceipt(
  source: $source,
  merchant: $merchant,
  amount: $amount,
  transactionDate: $transactionDate,
  transactionId: $transactionId,
  payer: $payer,
  payee: $payee,
  isSuccessful: $isSuccessful
)
''';
  }
}
