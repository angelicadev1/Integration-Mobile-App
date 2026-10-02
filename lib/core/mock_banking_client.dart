import 'dart:async';
import 'dart:math';
import 'banking_exceptions.dart';
import '../models/user_session.dart';
import '../models/account_model.dart';
import '../models/customer_model.dart';
import '../models/transaction_model.dart';
import '../models/notification_model.dart';
import '../models/recon_model.dart';
import '../models/card_model.dart';
import '../models/quote_model.dart';
import '../models/dispute_model.dart';

/// In-Memory Stateful Mock Banking Engine.
/// Provides zero-dependency standalone operation for air-gapped VMs,
/// defense presentations, evaluations, and offline testing.
/// Matches the exact contracts and personas of the Capstone Banking System.
class MockBankingClient {
  static final MockBankingClient _instance = MockBankingClient._internal();
  factory MockBankingClient() => _instance;

  final Map<String, CustomerModel> _customers = {};
  final Map<String, List<AccountModel>> _accountsByCust = {};
  final Map<String, AccountModel> _accountsById = {};
  final List<TransactionModel> _transactions = [];
  final Map<String, List<NotificationModel>> _notificationsByCust = {};
  final List<ReconRunModel> _reconRuns = [];
  final Map<String, List<CardModel>> _cardsByCust = {};
  final List<DisputeModel> _disputes = [];
  final Map<String, QuoteModel> _activeQuotes = {};
  final List<DateTime> _recentRequestTimestamps = [];

  bool _isLedgerDegraded = false;
  bool _simulateSecurityCheckUnavailable = false;

  bool get isLedgerDegraded => _isLedgerDegraded;
  void setLedgerDegraded(bool degraded) {
    _isLedgerDegraded = degraded;
  }

  bool get simulateSecurityCheckUnavailable => _simulateSecurityCheckUnavailable;
  void setSimulateSecurityCheckUnavailable(bool val) {
    _simulateSecurityCheckUnavailable = val;
  }

  MockBankingClient._internal() {
    _seedInitialData();
  }

  void _seedInitialData() {
    _customers.clear();
    _accountsByCust.clear();
    _accountsById.clear();
    _transactions.clear();
    _notificationsByCust.clear();
    _reconRuns.clear();
    _cardsByCust.clear();
    _disputes.clear();
    _activeQuotes.clear();
    _recentRequestTimestamps.clear();

    // 1. Admin Persona
    final admin = CustomerModel(
      customerId: 'CUST-ADMIN-001',
      firstName: 'System',
      lastName: 'Administrator',
      email: 'admin@ledgerbank.com',
      contactNo: '+63 917 000 0001',
      birthDate: DateTime(1985, 5, 20),
      idType: 'Government Issued Badge',
      idNumber: 'GOV-SEC-9981',
      address: 'Bangko Sentral Complex, Manila',
      kycStatus: KycStatus.verified,
      createdAt: DateTime(2025, 1, 1),
    );
    _customers[admin.customerId] = admin;

    // 2. Juan Dela Cruz Persona
    final juan = CustomerModel(
      customerId: 'CUST-1001',
      firstName: 'Juan',
      lastName: 'Dela Cruz',
      email: 'juan.delacruz@example.com',
      contactNo: '+63 917 123 4567',
      birthDate: DateTime(1992, 4, 15),
      idType: 'Passport',
      idNumber: 'P-98745612A',
      address: '123 Rizal Ave, Makati City, Metro Manila',
      kycStatus: KycStatus.verified,
      createdAt: DateTime(2025, 2, 10),
    );
    _customers[juan.customerId] = juan;

    final juanAcct1 = AccountModel(
      accountId: 'ACCT-1001-PHP',
      customerId: juan.customerId,
      accountType: AccountType.savings,
      accountStatus: AccountStatus.active,
      balanceAmount: 45250.00,
      currencyCode: 'PHP',
      createdAt: DateTime(2025, 2, 10),
    );
    final juanAcct2 = AccountModel(
      accountId: 'ACCT-1002-USD',
      customerId: juan.customerId,
      accountType: AccountType.checking,
      accountStatus: AccountStatus.active,
      balanceAmount: 1500.00,
      currencyCode: 'USD',
      createdAt: DateTime(2025, 3, 1),
    );

    _accountsByCust[juan.customerId] = [juanAcct1, juanAcct2];
    _accountsById[juanAcct1.accountId] = juanAcct1;
    _accountsById[juanAcct2.accountId] = juanAcct2;

    _cardsByCust[juan.customerId] = [
      CardModel(
        cardId: 'CARD-1001',
        accountId: juanAcct1.accountId,
        customerId: juan.customerId,
        cardNumberMasked: '•••• •••• •••• 4829',
        cardHolderName: 'JUAN DELA CRUZ',
        expiryMonth: 9,
        expiryYear: 2029,
        cvv: '739',
        isFrozen: false,
        isOnlineAllowed: true,
        isInternationalAllowed: false,
        isContactlessAllowed: true,
        isAtmAllowed: true,
        dailyLimit: 50000.0,
        dailySpent: 3125.0,
        currencyCode: 'PHP',
      ),
    ];

    // 3. Maria Santos Persona
    final maria = CustomerModel(
      customerId: 'CUST-2001',
      firstName: 'Maria',
      lastName: 'Santos',
      email: 'maria.santos@example.com',
      contactNo: '+63 918 987 6543',
      birthDate: DateTime(1995, 8, 28),
      idType: 'National ID',
      idNumber: 'PH-NID-4567-8910',
      address: '77 Ayala Avenue, Bonifacio Global City, Taguig',
      kycStatus: KycStatus.verified,
      createdAt: DateTime(2025, 2, 15),
    );
    _customers[maria.customerId] = maria;

    final mariaAcct1 = AccountModel(
      accountId: 'ACCT-2001-PHP',
      customerId: maria.customerId,
      accountType: AccountType.savings,
      accountStatus: AccountStatus.active,
      balanceAmount: 128400.00,
      currencyCode: 'PHP',
      createdAt: DateTime(2025, 2, 15),
    );
    final mariaAcct2 = AccountModel(
      accountId: 'ACCT-2002-PHP',
      customerId: maria.customerId,
      accountType: AccountType.digitalWallet,
      accountStatus: AccountStatus.active,
      balanceAmount: 4750.50,
      currencyCode: 'PHP',
      createdAt: DateTime(2025, 3, 5),
    );
    final mariaAcct3 = AccountModel(
      accountId: 'ACCT-2003-EUR',
      customerId: maria.customerId,
      accountType: AccountType.checking,
      accountStatus: AccountStatus.active,
      balanceAmount: 3200.00,
      currencyCode: 'EUR',
      createdAt: DateTime(2025, 3, 10),
    );

    _accountsByCust[maria.customerId] = [mariaAcct1, mariaAcct2, mariaAcct3];
    _accountsById[mariaAcct1.accountId] = mariaAcct1;
    _accountsById[mariaAcct2.accountId] = mariaAcct2;
    _accountsById[mariaAcct3.accountId] = mariaAcct3;

    _cardsByCust[maria.customerId] = [
      CardModel(
        cardId: 'CARD-2001',
        accountId: mariaAcct1.accountId,
        customerId: maria.customerId,
        cardNumberMasked: '•••• •••• •••• 9104',
        cardHolderName: 'MARIA SANTOS',
        expiryMonth: 12,
        expiryYear: 2028,
        cvv: '412',
        isFrozen: false,
        isOnlineAllowed: true,
        isInternationalAllowed: true,
        isContactlessAllowed: true,
        isAtmAllowed: true,
        dailyLimit: 100000.0,
        dailySpent: 12500.0,
        currencyCode: 'PHP',
      ),
    ];

    // Seed Initial Transactions (Audit Ledger)
    _transactions.addAll([
      TransactionModel(
        txnId: 'TXN-9001-01',
        mutationId: 'MUT-900101',
        accountId: 'ACCT-1001-PHP',
        counterpartyAccountId: null,
        txnType: TransactionType.deposit,
        direction: MutationDirection.credit,
        amount: 25000.00,
        currencyCode: 'PHP',
        auditState: AuditState.committed,
        timestamp: DateTime.now().subtract(const Duration(days: 3)),
        status: 'COMPLETED',
        idempotencyKey: 'IDEMP-SEED-01',
        riskScore: 8.5,
        riskDecision: 'APPROVED_LOW_RISK',
      ),
      TransactionModel(
        txnId: 'TXN-9001-02',
        mutationId: 'MUT-900102',
        accountId: 'ACCT-1001-PHP',
        counterpartyAccountId: 'ACCT-2001-PHP',
        txnType: TransactionType.transfer,
        direction: MutationDirection.debit,
        amount: 5000.00,
        currencyCode: 'PHP',
        auditState: AuditState.committed,
        timestamp: DateTime.now().subtract(const Duration(days: 2)),
        status: 'COMPLETED',
        idempotencyKey: 'IDEMP-SEED-02',
        riskScore: 14.2,
        riskDecision: 'APPROVED_LOW_RISK',
      ),
      TransactionModel(
        txnId: 'TXN-9002-01',
        mutationId: 'MUT-900201',
        accountId: 'ACCT-2001-PHP',
        counterpartyAccountId: 'ACCT-1001-PHP',
        txnType: TransactionType.transfer,
        direction: MutationDirection.credit,
        amount: 5000.00,
        currencyCode: 'PHP',
        auditState: AuditState.committed,
        timestamp: DateTime.now().subtract(const Duration(days: 2)),
        status: 'COMPLETED',
        idempotencyKey: 'IDEMP-SEED-02',
        riskScore: 14.2,
        riskDecision: 'APPROVED_LOW_RISK',
      ),
      TransactionModel(
        txnId: 'TXN-9003-01',
        mutationId: 'MUT-900301',
        accountId: 'ACCT-2001-PHP',
        counterpartyAccountId: 'ACCT-2003-EUR',
        txnType: TransactionType.transfer,
        direction: MutationDirection.debit,
        amount: 3125.00,
        currencyCode: 'PHP',
        destAmount: 50.00,
        destCurrencyCode: 'EUR',
        isCrossCurrency: true,
        fxRate: 0.016,
        feeAmount: 15.62,
        auditState: AuditState.committed,
        timestamp: DateTime.now().subtract(const Duration(hours: 12)),
        status: 'COMPLETED',
        idempotencyKey: 'IDEMP-SEED-03',
        riskScore: 19.8,
        riskDecision: 'APPROVED_STANDARD_FOR_EX',
      ),
    ]);

    // Seed Notifications
    _notificationsByCust[juan.customerId] = [
      NotificationModel(
        notifId: 'NOTIF-01',
        customerId: juan.customerId,
        message: 'Deposit of ₱25,000.00 credited to ACCT-1001-PHP. Ledger dual-committed.',
        isRead: true,
        createdAt: DateTime.now().subtract(const Duration(days: 3)),
      ),
      NotificationModel(
        notifId: 'NOTIF-02',
        customerId: juan.customerId,
        message: 'Transfer of ₱5,000.00 to ACCT-2001-PHP completed successfully.',
        isRead: false,
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
      ),
    ];

    _notificationsByCust[maria.customerId] = [
      NotificationModel(
        notifId: 'NOTIF-03',
        customerId: maria.customerId,
        message: 'Inward remittance ₱5,000.00 received from Juan Dela Cruz.',
        isRead: false,
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
      ),
      NotificationModel(
        notifId: 'NOTIF-04',
        customerId: maria.customerId,
        message: 'Cross-currency conversion executed: ₱3,125.00 converted to €50.00 @ 0.0160 rate.',
        isRead: false,
        createdAt: DateTime.now().subtract(const Duration(hours: 12)),
      ),
    ];

    // Seed Reconciliation Runs
    _reconRuns.addAll([
      ReconRunModel(
        runId: 'RECON-RUN-2026-10-01-01',
        status: 'BALANCED',
        totalChecked: 1420,
        totalMatched: 1420,
        totalExceptions: 0,
        startedAt: DateTime.now().subtract(const Duration(hours: 4)),
      ),
      ReconRunModel(
        runId: 'RECON-RUN-2026-09-30-01',
        status: 'FLAGGED_VARIANCE',
        totalChecked: 1105,
        totalMatched: 1103,
        totalExceptions: 2,
        startedAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
    ]);
  }

  // --- Authentication ---
  Future<UserSession?> authenticate(String email, String password) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final normalized = email.trim().toLowerCase();

    if (normalized.contains('admin') || normalized == 'admin@ledgerbank.com') {
      if (password == 'admin123' || password.isNotEmpty) {
        return UserSession(
          customerId: 'CUST-ADMIN-001',
          email: 'admin@ledgerbank.com',
          fullName: 'System Administrator',
          role: UserRole.admin,
          token: 'MOCK-JWT-ADMIN-${DateTime.now().millisecondsSinceEpoch}',
          kycStatus: KycStatus.verified,
        );
      }
    }

    for (var cust in _customers.values) {
      if (cust.email.toLowerCase() == normalized) {
        return UserSession(
          customerId: cust.customerId,
          email: cust.email,
          fullName: cust.fullName,
          role: UserRole.customer,
          token: 'MOCK-JWT-${cust.customerId}-${DateTime.now().millisecondsSinceEpoch}',
          kycStatus: cust.kycStatus,
        );
      }
    }

    return null;
  }

  // --- Registration ---
  Future<CustomerModel> registerCustomer({
    required String firstName,
    required String lastName,
    required String email,
    required String contactNo,
    required DateTime birthDate,
    required String password,
    required String idType,
    required String idNumber,
    required String address,
    required AccountType initialAccountType,
    required String initialCurrency,
  }) async {
    await Future.delayed(const Duration(milliseconds: 400));
    final newId = 'CUST-${1000 + _customers.length + 1}';
    final cust = CustomerModel(
      customerId: newId,
      firstName: firstName,
      lastName: lastName,
      email: email,
      contactNo: contactNo,
      birthDate: birthDate,
      idType: idType,
      idNumber: idNumber,
      address: address,
      kycStatus: KycStatus.pendingVerification,
      createdAt: DateTime.now(),
    );
    _customers[newId] = cust;

    // Create initial account
    final acctId = 'ACCT-${2000 + _accountsById.length + 1}-$initialCurrency';
    final acct = AccountModel(
      accountId: acctId,
      customerId: newId,
      accountType: initialAccountType,
      accountStatus: AccountStatus.active,
      balanceAmount: 0.0,
      currencyCode: initialCurrency,
      createdAt: DateTime.now(),
    );
    _accountsByCust[newId] = [acct];
    _accountsById[acctId] = acct;

    return cust;
  }

  // --- Accounts ---
  Future<List<AccountModel>> getAccountsByCustomerId(String customerId) async {
    if (_isLedgerDegraded) {
      throw const BankingException(
        code: BankingErrorCode.generalError,
        statusCode: 503,
        message: 'Database ledger degraded: Connection pool exhausted (DB-degradation fallback)',
      );
    }
    await Future.delayed(const Duration(milliseconds: 150));
    return _accountsByCust[customerId] ?? [];
  }

  Future<List<AccountModel>> getAllAccounts() async {
    await Future.delayed(const Duration(milliseconds: 200));
    return _accountsById.values.toList();
  }

  Future<AccountModel?> getAccountById(String accountId) async {
    await Future.delayed(const Duration(milliseconds: 100));
    return _accountsById[accountId];
  }

  Future<AccountModel> openAccount({
    required String customerId,
    required AccountType accountType,
    required String currencyCode,
    required double initialDeposit,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final acctId = 'ACCT-${1000 + _accountsById.length + 1}-$currencyCode';
    final acct = AccountModel(
      accountId: acctId,
      customerId: customerId,
      accountType: accountType,
      accountStatus: AccountStatus.active,
      balanceAmount: initialDeposit,
      currencyCode: currencyCode,
      createdAt: DateTime.now(),
    );

    _accountsById[acctId] = acct;
    _accountsByCust.putIfAbsent(customerId, () => []).add(acct);

    if (initialDeposit > 0) {
      _transactions.add(TransactionModel(
        txnId: 'TXN-${DateTime.now().millisecondsSinceEpoch}',
        mutationId: 'MUT-${Random().nextInt(999999).toString().padLeft(6, '0')}',
        accountId: acctId,
        txnType: TransactionType.deposit,
        direction: MutationDirection.credit,
        amount: initialDeposit,
        currencyCode: currencyCode,
        auditState: AuditState.committed,
        timestamp: DateTime.now(),
        status: 'COMPLETED',
        idempotencyKey: 'IDEMP-OPEN-$acctId',
        riskScore: 5.0,
        riskDecision: 'INITIAL_DEPOSIT_CLEARED',
      ));
    }

    return acct;
  }

  Future<void> updateAccountStatus(String accountId, AccountStatus status) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final existing = _accountsById[accountId];
    if (existing != null) {
      final updated = existing.copyWith(accountStatus: status);
      _accountsById[accountId] = updated;

      // Update in customer list
      final list = _accountsByCust[existing.customerId];
      if (list != null) {
        final idx = list.indexWhere((a) => a.accountId == accountId);
        if (idx != -1) {
          list[idx] = updated;
        }
      }
    }
  }

  // --- ForEx Rates ---
  double getExchangeRate(String from, String to) {
    if (from.toUpperCase() == to.toUpperCase()) return 1.0;
    final pair = '${from.toUpperCase()}/${to.toUpperCase()}';
    switch (pair) {
      case 'PHP/USD':
        return 0.0175;
      case 'USD/PHP':
        return 57.1428;
      case 'PHP/EUR':
        return 0.0160;
      case 'EUR/PHP':
        return 62.5000;
      case 'USD/EUR':
        return 0.9140;
      case 'EUR/USD':
        return 1.0941;
      default:
        return 1.0;
    }
  }

  // --- Risk Analysis Scoring (JSON Score Model Output) ---
  Map<String, dynamic> evaluateRisk({
    required double amount,
    required String currency,
    required TransactionType txnType,
    required bool isCrossCurrency,
  }) {
    // Normalization to PHP baseline
    final rateToPhp = getExchangeRate(currency, 'PHP');
    final amountInPhp = amount * rateToPhp;

    double score = 10.0;
    if (amountInPhp > 100000) {
      score += 35.0;
    } else if (amountInPhp > 30000) {
      score += 15.0;
    }

    if (isCrossCurrency) score += 12.5;
    if (txnType == TransactionType.withdrawal) score += 8.0;

    score = min(99.0, max(5.0, score));

    String decision = 'APPROVED_LOW_RISK';
    if (score >= 75.0) {
      decision = 'MANUAL_COMPLIANCE_HOLD';
    } else if (score >= 40.0) {
      decision = 'APPROVED_STANDARD_RISK';
    }

    return {
      'score': score,
      'decision': decision,
      'model': 'CAPSTONE-FRAUD-RISK-v3.2',
      'evaluatedAt': DateTime.now().toIso8601String(),
    };
  }

  // --- Balance Mutation / Remittance Engine (Dual Commit) ---
  Future<TransactionModel> executeTransaction({
    required String sourceAccountId,
    String? counterpartyAccountId,
    required TransactionType txnType,
    required double amount,
    String? idempotencyKey,
  }) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final src = _accountsById[sourceAccountId];
    if (src == null) throw Exception('Source account not found: $sourceAccountId');
    if (src.isFrozen) throw Exception('Account $sourceAccountId is FROZEN by Bank Administration');
    if (src.isClosed) throw Exception('Account $sourceAccountId is CLOSED');

    final key = (idempotencyKey != null && idempotencyKey.isNotEmpty)
        ? idempotencyKey
        : 'IDEMP-${DateTime.now().millisecondsSinceEpoch}';

    if (_simulateSecurityCheckUnavailable) {
      throw BankingException.securityCheckUnavailable();
    }

    final now = DateTime.now();
    _recentRequestTimestamps.removeWhere((t) => now.difference(t).inSeconds > 3);
    if (_recentRequestTimestamps.length >= 5) {
      throw BankingException.rateLimitExceeded(15);
    }
    _recentRequestTimestamps.add(now);

    // Risk Analysis computation
    final isCross = (counterpartyAccountId != null && _accountsById[counterpartyAccountId] != null) &&
        (_accountsById[counterpartyAccountId]!.currencyCode != src.currencyCode);
    final risk = evaluateRisk(
      amount: amount,
      currency: src.currencyCode,
      txnType: txnType,
      isCrossCurrency: isCross,
    );

    if (risk['score'] >= 90.0 || amount > 500000) {
      throw BankingException.highRiskDecline();
    }

    if (txnType == TransactionType.deposit) {
      // Credit source account
      final newBal = src.balanceAmount + amount;
      _updateAccountBalance(src.accountId, newBal);

      final txn = TransactionModel(
        txnId: 'TXN-${DateTime.now().millisecondsSinceEpoch}',
        mutationId: 'MUT-${Random().nextInt(999999).toString().padLeft(6, '0')}',
        accountId: src.accountId,
        counterpartyAccountId: null,
        txnType: TransactionType.deposit,
        direction: MutationDirection.credit,
        amount: amount,
        currencyCode: src.currencyCode,
        auditState: AuditState.committed,
        timestamp: DateTime.now(),
        status: 'COMPLETED',
        idempotencyKey: key,
        riskScore: risk['score'],
        riskDecision: risk['decision'],
      );
      _transactions.insert(0, txn);
      _addNotification(
        src.customerId,
        'Deposit credited: +${src.currencyCode} ${amount.toStringAsFixed(2)} to ${src.accountId}',
      );
      return txn;
    } else if (txnType == TransactionType.withdrawal) {
      if (src.balanceAmount < amount) {
        throw BankingException.insufficientFunds(
          accountId: src.accountId,
          requiredAmount: amount,
          availableBalance: src.balanceAmount,
          currency: src.currencyCode,
        );
      }
      final newBal = src.balanceAmount - amount;
      _updateAccountBalance(src.accountId, newBal);

      final txn = TransactionModel(
        txnId: 'TXN-${DateTime.now().millisecondsSinceEpoch}',
        mutationId: 'MUT-${Random().nextInt(999999).toString().padLeft(6, '0')}',
        accountId: src.accountId,
        counterpartyAccountId: null,
        txnType: TransactionType.withdrawal,
        direction: MutationDirection.debit,
        amount: amount,
        currencyCode: src.currencyCode,
        auditState: AuditState.committed,
        timestamp: DateTime.now(),
        status: 'COMPLETED',
        idempotencyKey: key,
        riskScore: risk['score'],
        riskDecision: risk['decision'],
      );
      _transactions.insert(0, txn);
      _addNotification(
        src.customerId,
        'Withdrawal debited: -${src.currencyCode} ${amount.toStringAsFixed(2)} from ${src.accountId}',
      );
      return txn;
    } else {
      // TRANSFER / REMITTANCE
      if (counterpartyAccountId == null || counterpartyAccountId.isEmpty) {
        throw Exception('Destination counterparty account is required for transfer');
      }
      final dest = _accountsById[counterpartyAccountId];
      if (dest == null) throw Exception('Recipient counterparty account not found: $counterpartyAccountId');
      if (dest.isFrozen) throw Exception('Recipient account $counterpartyAccountId is FROZEN');

      // Check ForEx conversion
      double fee = 0.0;
      double destAmount = amount;
      double fxRate = 1.0;
      if (isCross) {
        fxRate = getExchangeRate(src.currencyCode, dest.currencyCode);
        destAmount = (amount * fxRate * 100).roundToDouble() / 100;
        fee = (amount * 0.005 * 100).roundToDouble() / 100; // 0.5% fee
      }

      final totalDeduction = amount + fee;
      if (src.balanceAmount < totalDeduction) {
        throw BankingException.insufficientFunds(
          accountId: src.accountId,
          requiredAmount: totalDeduction,
          availableBalance: src.balanceAmount,
          currency: src.currencyCode,
        );
      }

      // DUAL COMMIT: Atomic mutation of both accounts
      _updateAccountBalance(src.accountId, src.balanceAmount - totalDeduction);
      _updateAccountBalance(dest.accountId, dest.balanceAmount + destAmount);

      final tid = 'TXN-${DateTime.now().millisecondsSinceEpoch}';
      final mutId = 'MUT-${Random().nextInt(999999).toString().padLeft(6, '0')}';

      // Debit record for sender
      final senderTxn = TransactionModel(
        txnId: tid,
        mutationId: mutId,
        accountId: src.accountId,
        counterpartyAccountId: dest.accountId,
        txnType: TransactionType.transfer,
        direction: MutationDirection.debit,
        amount: amount,
        currencyCode: src.currencyCode,
        destAmount: destAmount,
        destCurrencyCode: dest.currencyCode,
        isCrossCurrency: isCross,
        fxRate: isCross ? fxRate : null,
        feeAmount: fee,
        auditState: AuditState.committed,
        timestamp: DateTime.now(),
        status: 'COMPLETED',
        idempotencyKey: key,
        riskScore: risk['score'],
        riskDecision: risk['decision'],
      );
      _transactions.insert(0, senderTxn);

      // Credit record for recipient
      final recipientTxn = TransactionModel(
        txnId: '$tid-R',
        mutationId: '$mutId-R',
        accountId: dest.accountId,
        counterpartyAccountId: src.accountId,
        txnType: TransactionType.transfer,
        direction: MutationDirection.credit,
        amount: destAmount,
        currencyCode: dest.currencyCode,
        destAmount: amount,
        destCurrencyCode: src.currencyCode,
        isCrossCurrency: isCross,
        fxRate: isCross ? (1.0 / fxRate) : null,
        feeAmount: 0.0,
        auditState: AuditState.committed,
        timestamp: DateTime.now(),
        status: 'COMPLETED',
        idempotencyKey: '$key-RECV',
        riskScore: risk['score'],
        riskDecision: risk['decision'],
      );
      _transactions.insert(0, recipientTxn);

      _addNotification(
        src.customerId,
        'Transferred ${src.currencyCode} ${amount.toStringAsFixed(2)} to ${dest.accountId}. ${isCross ? "(ForEx rate $fxRate)" : ""}',
      );
      _addNotification(
        dest.customerId,
        'Received remittance: ${dest.currencyCode} ${destAmount.toStringAsFixed(2)} from ${src.accountId}',
      );

      return senderTxn;
    }
  }

  void _updateAccountBalance(String accountId, double newBalance) {
    final a = _accountsById[accountId];
    if (a != null) {
      final updated = a.copyWith(balanceAmount: newBalance);
      _accountsById[accountId] = updated;

      final list = _accountsByCust[a.customerId];
      if (list != null) {
        final idx = list.indexWhere((item) => item.accountId == accountId);
        if (idx != -1) {
          list[idx] = updated;
        }
      }
    }
  }

  void _addNotification(String customerId, String message) {
    final notif = NotificationModel(
      notifId: 'NOTIF-${DateTime.now().millisecondsSinceEpoch}',
      customerId: customerId,
      message: message,
      isRead: false,
      createdAt: DateTime.now(),
    );
    _notificationsByCust.putIfAbsent(customerId, () => []).insert(0, notif);
  }

  // --- Transactions & Ledger Audits ---
  Future<List<TransactionModel>> getTransactionsByAccountId(String accountId) async {
    await Future.delayed(const Duration(milliseconds: 150));
    return _transactions.where((t) => t.accountId == accountId).toList();
  }

  Future<List<TransactionModel>> getAllTransactions() async {
    await Future.delayed(const Duration(milliseconds: 200));
    return List.unmodifiable(_transactions);
  }

  // --- Customers & KYC Admin ---
  Future<CustomerModel?> getCustomerById(String customerId) async {
    await Future.delayed(const Duration(milliseconds: 100));
    return _customers[customerId];
  }

  Future<List<CustomerModel>> getAllCustomers() async {
    await Future.delayed(const Duration(milliseconds: 150));
    return _customers.values.toList();
  }

  Future<void> updateKycStatus(String customerId, KycStatus status) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final c = _customers[customerId];
    if (c != null) {
      _customers[customerId] = CustomerModel(
        customerId: c.customerId,
        firstName: c.firstName,
        lastName: c.lastName,
        email: c.email,
        contactNo: c.contactNo,
        birthDate: c.birthDate,
        idType: c.idType,
        idNumber: c.idNumber,
        address: c.address,
        kycStatus: status,
        createdAt: c.createdAt,
      );
    }
  }

  void updateCustomerContact(String customerId, String newContactNo) {
    final c = _customers[customerId];
    if (c != null) {
      _customers[customerId] = CustomerModel(
        customerId: c.customerId,
        firstName: c.firstName,
        lastName: c.lastName,
        email: c.email,
        contactNo: newContactNo,
        birthDate: c.birthDate,
        idType: c.idType,
        idNumber: c.idNumber,
        address: c.address,
        kycStatus: c.kycStatus,
        createdAt: c.createdAt,
      );
    }
  }

  // --- Notifications ---
  Future<List<NotificationModel>> getNotificationsByCustomerId(String customerId) async {
    await Future.delayed(const Duration(milliseconds: 100));
    return _notificationsByCust[customerId] ?? [];
  }

  Future<void> markNotificationAsRead(String customerId, String notifId) async {
    final list = _notificationsByCust[customerId];
    if (list != null) {
      final idx = list.indexWhere((n) => n.notifId == notifId);
      if (idx != -1) {
        list[idx] = list[idx].copyWith(isRead: true);
      }
    }
  }

  // --- Reconciliation & Audits ---
  Future<List<ReconRunModel>> getReconciliationRuns() async {
    await Future.delayed(const Duration(milliseconds: 200));
    return List.unmodifiable(_reconRuns);
  }

  Future<ReconRunModel> triggerReconciliationRun() async {
    await Future.delayed(const Duration(milliseconds: 600));
    final run = ReconRunModel(
      runId: 'RECON-RUN-${DateTime.now().millisecondsSinceEpoch}',
      status: 'BALANCED',
      totalChecked: _transactions.length,
      totalMatched: _transactions.length,
      totalExceptions: 0,
      startedAt: DateTime.now(),
    );
    _reconRuns.insert(0, run);
    return run;
  }

  // --- Cards & Controls (TR-M02) ---
  Future<List<CardModel>> getCardsByCustomerId(String customerId) async {
    await Future.delayed(const Duration(milliseconds: 100));
    return _cardsByCust[customerId] ?? [];
  }

  Future<CardModel> updateCard(CardModel card) async {
    await Future.delayed(const Duration(milliseconds: 150));
    final list = _cardsByCust[card.customerId];
    if (list != null) {
      final idx = list.indexWhere((c) => c.cardId == card.cardId);
      if (idx != -1) {
        list[idx] = card;
        return card;
      }
    }
    return card;
  }

  Future<CardModel> toggleCardFreeze(String cardId) async {
    for (final list in _cardsByCust.values) {
      final idx = list.indexWhere((c) => c.cardId == cardId);
      if (idx != -1) {
        final current = list[idx];
        final updated = current.copyWith(isFrozen: !current.isFrozen);
        list[idx] = updated;
        _addNotification(
          current.customerId,
          'Card security update: Card ${current.cardNumberMasked} has been ${updated.isFrozen ? "FROZEN" : "UNFROZEN"}.',
        );
        return updated;
      }
    }
    throw Exception('Card not found: $cardId');
  }

  // --- Live Quote & Pocket Conversion (TR-M11) ---
  QuoteModel requestLiveQuote({
    required String fromCurrency,
    required String toCurrency,
    required double sourceAmount,
    int validitySeconds = 30,
  }) {
    final fxRate = getExchangeRate(fromCurrency, toCurrency);
    final targetAmount = (sourceAmount * fxRate * 100).roundToDouble() / 100;
    final fee = fromCurrency != toCurrency ? (sourceAmount * 0.005 * 100).roundToDouble() / 100 : 0.0;
    final quoteId = 'QUOTE-${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(9999)}';
    final quote = QuoteModel(
      quoteId: quoteId,
      fromCurrency: fromCurrency,
      toCurrency: toCurrency,
      sourceAmount: sourceAmount,
      targetAmount: targetAmount,
      exchangeRate: fxRate,
      feeAmount: fee,
      feeCurrency: fromCurrency,
      expiresAt: DateTime.now().add(Duration(seconds: validitySeconds)),
      validitySeconds: validitySeconds,
    );
    _activeQuotes[quoteId] = quote;
    return quote;
  }

  Future<TransactionModel> convertPocket({
    required String sourceAccountId,
    required String targetAccountId,
    required String quoteId,
    required double amount,
    required String idempotencyKey,
  }) async {
    final quote = _activeQuotes[quoteId];
    if (quote == null || quote.isExpired) {
      throw const BankingException(
        code: BankingErrorCode.generalError,
        statusCode: 400,
        message: 'Conversion Quote Expired: The live quote has expired. Please fetch a refreshed rate.',
      );
    }
    return await executeTransaction(
      sourceAccountId: sourceAccountId,
      counterpartyAccountId: targetAccountId,
      txnType: TransactionType.transfer,
      amount: amount,
      idempotencyKey: idempotencyKey,
    );
  }

  // --- Report Suspicious Transaction (TR-M02) ---
  Future<DisputeModel> reportSuspiciousTransaction({
    required String txnId,
    required String accountId,
    required String customerId,
    required double amount,
    required String currencyCode,
    required String reason,
    required String description,
    required bool freezeRequested,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final disputeId = 'FRAUD-DISPUTE-${Random().nextInt(89999) + 10000}';
    final dispute = DisputeModel(
      disputeId: disputeId,
      txnId: txnId,
      accountId: accountId,
      customerId: customerId,
      amount: amount,
      currencyCode: currencyCode,
      reason: reason,
      description: description,
      freezeRequested: freezeRequested,
      status: 'PENDING_INVESTIGATION',
      reportedAt: DateTime.now(),
    );
    _disputes.insert(0, dispute);

    if (freezeRequested) {
      await updateAccountStatus(accountId, AccountStatus.frozen);
    }

    _addNotification(
      customerId,
      '⚠️ Security Alert: Fraud dispute $disputeId filed for transaction $txnId. Reason: $reason.${freezeRequested ? " Account $accountId has been temporarily frozen." : ""}',
    );

    return dispute;
  }

  List<DisputeModel> getDisputesByCustomerId(String customerId) {
    return _disputes.where((d) => d.customerId == customerId).toList();
  }
}
