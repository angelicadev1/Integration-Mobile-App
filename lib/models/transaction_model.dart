import '../core/constants.dart';

enum TransactionType {
  deposit,
  withdrawal,
  transfer,
}

enum MutationDirection {
  credit,
  debit,
}

enum AuditState {
  committed,
  pending,
  failed,
}

class TransactionModel {
  final String txnId;
  final String mutationId;
  final String accountId;
  final String? counterpartyAccountId;
  final TransactionType txnType;
  final MutationDirection direction;
  final double amount;
  final String currencyCode;
  final double? destAmount;
  final String? destCurrencyCode;
  final bool isCrossCurrency;
  final double? fxRate;
  final double feeAmount;
  final AuditState auditState;
  final DateTime timestamp;
  final String status;
  final String idempotencyKey;
  final double riskScore;
  final String riskDecision;

  TransactionModel({
    required this.txnId,
    required this.mutationId,
    required this.accountId,
    this.counterpartyAccountId,
    required this.txnType,
    required this.direction,
    required this.amount,
    required this.currencyCode,
    this.destAmount,
    this.destCurrencyCode,
    this.isCrossCurrency = false,
    this.fxRate,
    this.feeAmount = 0.0,
    this.auditState = AuditState.committed,
    required this.timestamp,
    required this.status,
    required this.idempotencyKey,
    this.riskScore = 12.5,
    this.riskDecision = 'APPROVED_LOW_RISK',
  });

  bool get isCredit => direction == MutationDirection.credit;
  bool get isDebit => direction == MutationDirection.debit;
  bool get isDualCommitted => auditState == AuditState.committed;
  String get sourceAccountId => accountId;
  DateTime get createdAt => timestamp;

  String get formattedAmount {
    final prefix = isCredit ? '+' : '-';
    return '$prefix${AppConstants.formatCurrency(amount, currencyCode)}';
  }

  String get typeLabel {
    switch (txnType) {
      case TransactionType.deposit:
        return 'Deposit';
      case TransactionType.withdrawal:
        return 'Withdrawal';
      case TransactionType.transfer:
        return isCrossCurrency ? 'Cross-Border Remittance' : 'Internal Fund Transfer';
    }
  }

  factory TransactionModel.fromJson(Map<String, dynamic> json, {String defaultCurrency = 'PHP'}) {
    final tid = json['txnId']?.toString() ?? 'TXN-${DateTime.now().millisecondsSinceEpoch}';
    final mutId = json['mutationUuid']?.toString() ?? 'MUT-${tid.length >= 8 ? tid.substring(0, 8) : tid}';

    TransactionType type = TransactionType.transfer;
    final tStr = (json['txnType'] ?? 'TRANSFER').toString().toUpperCase();
    if (tStr.contains('DEP')) {
      type = TransactionType.deposit;
    } else if (tStr.contains('WITH')) {
      type = TransactionType.withdrawal;
    }

    MutationDirection dir = MutationDirection.debit;
    final dStr = (json['mutationType'] ?? (type == TransactionType.deposit ? 'CREDIT' : 'DEBIT')).toString().toUpperCase();
    if (dStr.contains('CREDIT')) {
      dir = MutationDirection.credit;
    }

    AuditState audit = AuditState.committed;
    final aStr = (json['auditState'] ?? json['txnStatus'] ?? 'COMMITTED').toString().toUpperCase();
    if (aStr.contains('PEND')) {
      audit = AuditState.pending;
    } else if (aStr.contains('FAIL')) {
      audit = AuditState.failed;
    }

    DateTime dt;
    try {
      final tsStr = json['timestamp'] ?? json['createdAt'] ?? json['ledgerPostedAt'];
      dt = tsStr != null ? DateTime.parse(tsStr.toString()) : DateTime.now();
    } catch (_) {
      dt = DateTime.now();
    }

    double amt = 0.0;
    if (json['amount'] != null || json['mutationAmount'] != null) {
      amt = double.tryParse((json['amount'] ?? json['mutationAmount']).toString()) ?? 0.0;
    }

    double? destAmt;
    if (json['targetAmount'] != null) {
      destAmt = double.tryParse(json['targetAmount'].toString());
    }

    double? fx;
    if (json['exchangeRate'] != null) {
      fx = double.tryParse(json['exchangeRate'].toString());
    }

    double fee = 0.0;
    if (json['feeAmount'] != null) {
      fee = double.tryParse(json['feeAmount'].toString()) ?? 0.0;
    }

    final isCross = json['isCrossCurrency'] == true || (fx != null && fx != 1.0);

    return TransactionModel(
      txnId: tid,
      mutationId: mutId,
      accountId: json['accountId']?.toString() ?? '',
      counterpartyAccountId: json['counterpartyAccountId']?.toString(),
      txnType: type,
      direction: dir,
      amount: amt,
      currencyCode: json['currencyCode']?.toString() ?? defaultCurrency,
      destAmount: destAmt,
      destCurrencyCode: json['targetCurrency']?.toString(),
      isCrossCurrency: isCross,
      fxRate: fx,
      feeAmount: fee,
      auditState: audit,
      timestamp: dt,
      status: json['txnStatus']?.toString() ?? 'COMPLETED',
      idempotencyKey: json['idempotencyKey']?.toString() ?? 'IDEM-$tid',
      riskScore: double.tryParse(json['riskScore']?.toString() ?? '15.0') ?? 15.0,
      riskDecision: json['riskDecision']?.toString() ?? 'APPROVED',
    );
  }
}
