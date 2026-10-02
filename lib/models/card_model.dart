/// Model for Retail Debit and Virtual Cards.
/// Supports TR-M02: "card controls"
class CardModel {
  final String cardId;
  final String accountId;
  final String customerId;
  final String cardNumberMasked;
  final String cardHolderName;
  final int expiryMonth;
  final int expiryYear;
  final String cvv;
  final bool isFrozen;
  final bool isOnlineAllowed;
  final bool isInternationalAllowed;
  final bool isContactlessAllowed;
  final bool isAtmAllowed;
  final double dailyLimit;
  final double dailySpent;
  final String currencyCode;

  const CardModel({
    required this.cardId,
    required this.accountId,
    required this.customerId,
    required this.cardNumberMasked,
    required this.cardHolderName,
    required this.expiryMonth,
    required this.expiryYear,
    required this.cvv,
    required this.isFrozen,
    required this.isOnlineAllowed,
    required this.isInternationalAllowed,
    required this.isContactlessAllowed,
    required this.isAtmAllowed,
    required this.dailyLimit,
    required this.dailySpent,
    required this.currencyCode,
  });

  String get expiryFormatted =>
      '${expiryMonth.toString().padLeft(2, '0')}/${expiryYear.toString().substring(2)}';

  CardModel copyWith({
    String? cardId,
    String? accountId,
    String? customerId,
    String? cardNumberMasked,
    String? cardHolderName,
    int? expiryMonth,
    int? expiryYear,
    String? cvv,
    bool? isFrozen,
    bool? isOnlineAllowed,
    bool? isInternationalAllowed,
    bool? isContactlessAllowed,
    bool? isAtmAllowed,
    double? dailyLimit,
    double? dailySpent,
    String? currencyCode,
  }) {
    return CardModel(
      cardId: cardId ?? this.cardId,
      accountId: accountId ?? this.accountId,
      customerId: customerId ?? this.customerId,
      cardNumberMasked: cardNumberMasked ?? this.cardNumberMasked,
      cardHolderName: cardHolderName ?? this.cardHolderName,
      expiryMonth: expiryMonth ?? this.expiryMonth,
      expiryYear: expiryYear ?? this.expiryYear,
      cvv: cvv ?? this.cvv,
      isFrozen: isFrozen ?? this.isFrozen,
      isOnlineAllowed: isOnlineAllowed ?? this.isOnlineAllowed,
      isInternationalAllowed: isInternationalAllowed ?? this.isInternationalAllowed,
      isContactlessAllowed: isContactlessAllowed ?? this.isContactlessAllowed,
      isAtmAllowed: isAtmAllowed ?? this.isAtmAllowed,
      dailyLimit: dailyLimit ?? this.dailyLimit,
      dailySpent: dailySpent ?? this.dailySpent,
      currencyCode: currencyCode ?? this.currencyCode,
    );
  }

  factory CardModel.fromJson(Map<String, dynamic> json) {
    return CardModel(
      cardId: json['cardId'] ?? '',
      accountId: json['accountId'] ?? '',
      customerId: json['customerId'] ?? '',
      cardNumberMasked: json['cardNumberMasked'] ?? '•••• •••• •••• 1234',
      cardHolderName: json['cardHolderName'] ?? 'RETAIL CARDHOLDER',
      expiryMonth: json['expiryMonth'] is int ? json['expiryMonth'] : 12,
      expiryYear: json['expiryYear'] is int ? json['expiryYear'] : 2028,
      cvv: json['cvv'] ?? '•••',
      isFrozen: json['isFrozen'] == true,
      isOnlineAllowed: json['isOnlineAllowed'] != false,
      isInternationalAllowed: json['isInternationalAllowed'] == true,
      isContactlessAllowed: json['isContactlessAllowed'] != false,
      isAtmAllowed: json['isAtmAllowed'] != false,
      dailyLimit: (json['dailyLimit'] as num?)?.toDouble() ?? 50000.0,
      dailySpent: (json['dailySpent'] as num?)?.toDouble() ?? 0.0,
      currencyCode: json['currencyCode'] ?? 'PHP',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'cardId': cardId,
      'accountId': accountId,
      'customerId': customerId,
      'cardNumberMasked': cardNumberMasked,
      'cardHolderName': cardHolderName,
      'expiryMonth': expiryMonth,
      'expiryYear': expiryYear,
      'cvv': cvv,
      'isFrozen': isFrozen,
      'isOnlineAllowed': isOnlineAllowed,
      'isInternationalAllowed': isInternationalAllowed,
      'isContactlessAllowed': isContactlessAllowed,
      'isAtmAllowed': isAtmAllowed,
      'dailyLimit': dailyLimit,
      'dailySpent': dailySpent,
      'currencyCode': currencyCode,
    };
  }
}
