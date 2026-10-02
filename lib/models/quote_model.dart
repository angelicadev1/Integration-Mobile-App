/// Model for Foreign Exchange Live Conversion Quote.
/// Meets requirement TR-M11:
/// "Convert screen with live quote countdown"
class QuoteModel {
  final String quoteId;
  final String fromCurrency;
  final String toCurrency;
  final double sourceAmount;
  final double targetAmount;
  final double exchangeRate;
  final double feeAmount;
  final String feeCurrency;
  final DateTime expiresAt;
  final int validitySeconds;

  const QuoteModel({
    required this.quoteId,
    required this.fromCurrency,
    required this.toCurrency,
    required this.sourceAmount,
    required this.targetAmount,
    required this.exchangeRate,
    required this.feeAmount,
    required this.feeCurrency,
    required this.expiresAt,
    this.validitySeconds = 30,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  int get remainingSeconds {
    final diff = expiresAt.difference(DateTime.now()).inSeconds;
    return diff > 0 ? diff : 0;
  }

  factory QuoteModel.fromJson(Map<String, dynamic> json) {
    final expires = json['expiresAt'] != null
        ? DateTime.parse(json['expiresAt'].toString())
        : DateTime.now().add(const Duration(seconds: 30));

    return QuoteModel(
      quoteId: json['quoteId'] ?? 'QUOTE-${DateTime.now().millisecondsSinceEpoch}',
      fromCurrency: json['fromCurrency'] ?? 'PHP',
      toCurrency: json['toCurrency'] ?? 'USD',
      sourceAmount: (json['sourceAmount'] as num?)?.toDouble() ?? 0.0,
      targetAmount: (json['targetAmount'] as num?)?.toDouble() ?? 0.0,
      exchangeRate: (json['exchangeRate'] as num?)?.toDouble() ?? 1.0,
      feeAmount: (json['feeAmount'] as num?)?.toDouble() ?? 0.0,
      feeCurrency: json['feeCurrency'] ?? json['fromCurrency'] ?? 'PHP',
      expiresAt: expires,
      validitySeconds: (json['validitySeconds'] as num?)?.toInt() ?? 30,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'quoteId': quoteId,
      'fromCurrency': fromCurrency,
      'toCurrency': toCurrency,
      'sourceAmount': sourceAmount,
      'targetAmount': targetAmount,
      'exchangeRate': exchangeRate,
      'feeAmount': feeAmount,
      'feeCurrency': feeCurrency,
      'expiresAt': expiresAt.toIso8601String(),
      'validitySeconds': validitySeconds,
    };
  }
}
