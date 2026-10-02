import '../core/constants.dart';

enum AccountType {
  savings,
  checking,
  digitalWallet,
}

enum AccountStatus {
  active,
  frozen,
  closed,
}

class AccountModel {
  final String accountId;
  final String customerId;
  final AccountType accountType;
  final AccountStatus accountStatus;
  final double balanceAmount;
  final String currencyCode;
  final DateTime createdAt;

  AccountModel({
    required this.accountId,
    required this.customerId,
    required this.accountType,
    required this.accountStatus,
    required this.balanceAmount,
    required this.currencyCode,
    required this.createdAt,
  });

  bool get isActive => accountStatus == AccountStatus.active;
  bool get isFrozen => accountStatus == AccountStatus.frozen;
  bool get isClosed => accountStatus == AccountStatus.closed;

  String get formattedBalance => AppConstants.formatCurrency(balanceAmount, currencyCode);

  String get typeLabel {
    switch (accountType) {
      case AccountType.savings:
        return 'Savings Account';
      case AccountType.checking:
        return 'Checking Account';
      case AccountType.digitalWallet:
        return 'Digital Wallet';
    }
  }

  String get statusLabel {
    switch (accountStatus) {
      case AccountStatus.active:
        return 'ACTIVE';
      case AccountStatus.frozen:
        return 'FROZEN';
      case AccountStatus.closed:
        return 'CLOSED';
    }
  }

  AccountModel copyWith({
    String? accountId,
    String? customerId,
    AccountType? accountType,
    AccountStatus? accountStatus,
    double? balanceAmount,
    String? currencyCode,
    DateTime? createdAt,
  }) {
    return AccountModel(
      accountId: accountId ?? this.accountId,
      customerId: customerId ?? this.customerId,
      accountType: accountType ?? this.accountType,
      accountStatus: accountStatus ?? this.accountStatus,
      balanceAmount: balanceAmount ?? this.balanceAmount,
      currencyCode: currencyCode ?? this.currencyCode,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory AccountModel.fromJson(Map<String, dynamic> json) {
    AccountType type = AccountType.savings;
    final tStr = (json['accountType'] ?? 'SAVINGS').toString().toUpperCase();
    if (tStr.contains('CHECK')) {
      type = AccountType.checking;
    } else if (tStr.contains('WALLET')) {
      type = AccountType.digitalWallet;
    }

    AccountStatus status = AccountStatus.active;
    final sStr = (json['accountStatus'] ?? 'ACTIVE').toString().toUpperCase();
    if (sStr.contains('FROZ')) {
      status = AccountStatus.frozen;
    } else if (sStr.contains('CLOSE')) {
      status = AccountStatus.closed;
    }

    DateTime dt;
    try {
      dt = json['createdAt'] != null
          ? DateTime.parse(json['createdAt'].toString())
          : DateTime.now();
    } catch (_) {
      dt = DateTime.now();
    }

    double bal = 0.0;
    if (json['balanceAmount'] != null) {
      bal = double.tryParse(json['balanceAmount'].toString()) ?? 0.0;
    }

    return AccountModel(
      accountId: json['accountId'] ?? '',
      customerId: json['customerId'] ?? '',
      accountType: type,
      accountStatus: status,
      balanceAmount: bal,
      currencyCode: json['currencyCode'] ?? 'PHP',
      createdAt: dt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'accountId': accountId,
      'customerId': customerId,
      'accountType': accountType.name.toUpperCase(),
      'accountStatus': accountStatus.name.toUpperCase(),
      'balanceAmount': balanceAmount,
      'currencyCode': currencyCode,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
