/// Model for Reporting Suspicious Transactions and Fraud Disputes.
/// Meets requirement TR-M02: "report suspicious transaction"
class DisputeModel {
  final String disputeId;
  final String txnId;
  final String accountId;
  final String customerId;
  final double amount;
  final String currencyCode;
  final String reason;
  final String description;
  final bool freezeRequested;
  final String status;
  final DateTime reportedAt;

  const DisputeModel({
    required this.disputeId,
    required this.txnId,
    required this.accountId,
    required this.customerId,
    required this.amount,
    required this.currencyCode,
    required this.reason,
    required this.description,
    required this.freezeRequested,
    this.status = 'PENDING_INVESTIGATION',
    required this.reportedAt,
  });

  String get transactionId => txnId;

  factory DisputeModel.fromJson(Map<String, dynamic> json) {
    return DisputeModel(
      disputeId: json['disputeId'] ?? '',
      txnId: json['txnId'] ?? '',
      accountId: json['accountId'] ?? '',
      customerId: json['customerId'] ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      currencyCode: json['currencyCode'] ?? 'PHP',
      reason: json['reason'] ?? '',
      description: json['description'] ?? '',
      freezeRequested: json['freezeRequested'] == true,
      status: json['status'] ?? 'PENDING_INVESTIGATION',
      reportedAt: json['reportedAt'] != null
          ? DateTime.parse(json['reportedAt'].toString())
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'disputeId': disputeId,
      'txnId': txnId,
      'accountId': accountId,
      'customerId': customerId,
      'amount': amount,
      'currencyCode': currencyCode,
      'reason': reason,
      'description': description,
      'freezeRequested': freezeRequested,
      'status': status,
      'reportedAt': reportedAt.toIso8601String(),
    };
  }
}
