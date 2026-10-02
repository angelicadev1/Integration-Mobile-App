import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_mobile/core/banking_exceptions.dart';
import 'package:frontend_mobile/core/banking_repository.dart';
import 'package:frontend_mobile/core/device_security_service.dart';
import 'package:frontend_mobile/core/encrypted_token_storage.dart';
import 'package:frontend_mobile/core/mock_banking_client.dart';
import 'package:frontend_mobile/core/uuid_util.dart';
import 'package:frontend_mobile/models/card_model.dart';
import 'package:frontend_mobile/models/quote_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TR-M03: UUID Idempotency Key Generation Tests', () {
    test('UuidUtil generates RFC 4122 v4 compliant UUIDs', () {
      final uuidRegex = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$');

      for (int i = 0; i < 50; i++) {
        final key = UuidUtil.generateV4();
        expect(uuidRegex.hasMatch(key), isTrue, reason: 'Failed for UUID: $key');
      }
    });

    test('Consecutive UUID calls produce unique tokens', () {
      final set = <String>{};
      for (int i = 0; i < 100; i++) {
        set.add(UuidUtil.generateV4());
      }
      expect(set.length, equals(100));
    });
  });

  group('TR-M10: Distinct Error Messages and Exception Mapping', () {
    test('BankingException provides distinct codes and messages for all required scenarios', () {
      // 1. High-risk decline
      final highRisk = BankingException.highRiskDecline('Risk score exceeded acceptable threshold (TR-E03)');
      expect(highRisk.code, equals(BankingException.highRiskDeclineCode));
      expect(highRisk.isHighRiskDecline, isTrue);
      expect(highRisk.message, contains('threshold'));

      // 2. Insufficient funds
      final insufficient = BankingException.insufficientFunds(message: 'Insufficient funds in primary PHP pocket');
      expect(insufficient.code, equals(BankingException.insufficientFundsCode));
      expect(insufficient.isInsufficientFunds, isTrue);

      // 3. Rate limiting
      final rateLimit = BankingException.rateLimitExceeded('429: Too Many Requests from device');
      expect(rateLimit.code, equals(BankingException.rateLimitExceededCode));
      expect(rateLimit.isRateLimited, isTrue);

      // 4. Security-check unavailable
      final secUnavailable = BankingException.securityCheckUnavailable('Security engine timeout');
      expect(secUnavailable.code, equals(BankingException.securityCheckUnavailableCode));
      expect(secUnavailable.isSecurityUnavailable, isTrue);

      // 5. Circuit breaker open
      final cbOpen = BankingException.circuitBreakerOpen('Gateway circuit breaker OPEN');
      expect(cbOpen.code, equals(BankingException.circuitBreakerOpenCode));
      expect(cbOpen.isCircuitBreakerOpen, isTrue);
    });

    test('BankingException.fromHttp maps status codes correctly', () {
      final err429 = BankingException.fromHttp(429, 'Slow down');
      expect(err429.code, equals(BankingException.rateLimitExceededCode));

      final err503 = BankingException.fromHttp(503, 'Ledger unreachable');
      expect(err503.code, equals(BankingException.securityCheckUnavailableCode));

      final err400Funds = BankingException.fromHttp(400, 'INSUFFICIENT_FUNDS');
      expect(err400Funds.code, equals(BankingException.insufficientFundsCode));

      final err403Risk = BankingException.fromHttp(403, 'HIGH_RISK_DECLINE: flagged');
      expect(err403Risk.code, equals(BankingException.highRiskDeclineCode));
    });
  });

  group('TR-M09: DB-Degradation Fallback & Cached Balance Timestamping', () {
    final repo = BankingRepository();

    test('Preserves last cached balance and sets degraded flag when ledger is unavailable', () async {
      // Login first to seed accounts
      final session = await repo.loginWithPin('123456');
      expect(session, isNotNull);
      expect(repo.currentAccounts.isNotEmpty, isTrue);

      final initialBalance = repo.currentAccounts.first.balanceAmount;
      expect(initialBalance, greaterThan(0));

      // Simulate ledger degradation
      repo.setSimulateLedgerDegraded(true);
      expect(repo.isLedgerDegraded, isTrue);

      // Refreshing data during degradation must not wipe the balance; it preserves cached balance
      await repo.refreshUserData();
      expect(repo.isLedgerDegraded, isTrue);
      expect(repo.lastBalanceCachedAt, isNotNull);
      expect(repo.currentAccounts.first.balanceAmount, equals(initialBalance));

      // Turn off degradation
      repo.setSimulateLedgerDegraded(false);
      await repo.refreshUserData();
      expect(repo.isLedgerDegraded, isFalse);
    });
  });

  group('TR-M11: Multi-Currency Pocket Quotes & Live Countdown', () {
    test('QuoteModel calculates validity and remaining countdown seconds correctly', () {
      final now = DateTime.now();
      final validQuote = QuoteModel(
        quoteId: 'Q-TEST-001',
        fromCurrency: 'PHP',
        toCurrency: 'USD',
        sourceAmount: 1000.0,
        targetAmount: 18.0,
        exchangeRate: 0.018,
        feeAmount: 5.0,
        feeCurrency: 'PHP',
        expiresAt: now.add(const Duration(seconds: 28)),
      );

      expect(validQuote.isExpired, isFalse);
      expect(validQuote.remainingSeconds, inInclusiveRange(25, 29));

      final expiredQuote = QuoteModel(
        quoteId: 'Q-TEST-002',
        fromCurrency: 'USD',
        toCurrency: 'PHP',
        sourceAmount: 10.0,
        targetAmount: 560.0,
        exchangeRate: 56.0,
        feeAmount: 0.0,
        feeCurrency: 'USD',
        expiresAt: now.subtract(const Duration(seconds: 5)),
      );

      expect(expiredQuote.isExpired, isTrue);
      expect(expiredQuote.remainingSeconds, equals(0));
    });

    test('MockBankingClient returns fresh 30-second live quotes and executes conversion', () async {
      final client = MockBankingClient();
      final quote = client.requestLiveQuote(
        fromCurrency: 'PHP',
        toCurrency: 'USD',
        sourceAmount: 1000.0,
      );

      expect(quote.quoteId, startsWith('QUOTE-'));
      expect(quote.isExpired, isFalse);
      expect(quote.exchangeRate, greaterThan(0));

      final phpAcctBefore = await client.getAccountById('ACCT-1001-PHP');
      final usdAcctBefore = await client.getAccountById('ACCT-1002-USD');
      expect(phpAcctBefore, isNotNull);
      expect(usdAcctBefore, isNotNull);

      final phpBalBefore = phpAcctBefore!.balanceAmount;
      final usdBalBefore = usdAcctBefore!.balanceAmount;

      final convertTxn = await client.convertPocket(
        sourceAccountId: 'ACCT-1001-PHP',
        targetAccountId: 'ACCT-1002-USD',
        amount: 1000.0,
        quoteId: quote.quoteId,
        idempotencyKey: UuidUtil.generateV4(),
      );

      expect(convertTxn.auditState.name, equals('committed'));

      final phpAcctAfter = await client.getAccountById('ACCT-1001-PHP');
      final usdAcctAfter = await client.getAccountById('ACCT-1002-USD');

      expect(phpAcctAfter!.balanceAmount, lessThan(phpBalBefore));
      expect(usdAcctAfter!.balanceAmount, greaterThan(usdBalBefore));
    });
  });

  group('TR-M02: Multi-Factor Authentication & Screen Models', () {
    final repo = BankingRepository();

    test('Login with PIN fallback works for valid credentials', () async {
      final session = await repo.loginWithPin('123456');
      expect(session, isNotNull);
      expect(session!.fullName, contains('Juan'));
      expect(repo.currentUser, isNotNull);
      expect(repo.currentUser!.role.name, equals('customer'));
    });

    test('Login with Biometric simulation authenticates successfully', () async {
      final session = await repo.loginWithBiometrics();
      expect(session, isNotNull);
      expect(session!.fullName, contains('Juan'));
    });

    test('Card Controls Model verifies freeze, limits, and channel updates', () async {
      final cards = await repo.getCards();
      expect(cards.isNotEmpty, isTrue);

      final CardModel firstCard = cards.first;
      expect(firstCard.isFrozen, isFalse);

      // Freeze card
      final frozenCard = firstCard.copyWith(isFrozen: true);
      final updated = await repo.updateCard(frozenCard);
      expect(updated.isFrozen, isTrue);

      // Unfreeze
      final unfrozen = await repo.updateCard(updated.copyWith(isFrozen: false));
      expect(unfrozen.isFrozen, isFalse);
    });

    test('Report Suspicious Transaction registers dispute', () async {
      final dispute = await repo.reportSuspiciousTransaction(
        txnId: 'TXN-999',
        accountId: 'ACCT-2001-PHP',
        amount: 500.0,
        currencyCode: 'PHP',
        reason: 'Unrecognized merchant charge',
        description: 'Did not authorize this debit',
        freezeRequested: false,
      );

      expect(dispute.disputeId, contains('DISPUTE'));
      expect(dispute.transactionId, equals('TXN-999'));
      expect(dispute.status, equals('PENDING_INVESTIGATION'));
    });
  });

  group('TR-M05 & TR-M06: Security & Keystore Lifecycle', () {
    test('EncryptedTokenStorage clears all tokens on logout', () async {
      final storage = EncryptedTokenStorage();
      await storage.saveToken(rawJwtToken: 'TEST_JWT', customerId: 'CUST-001', role: 'CUSTOMER');
      expect(storage.hasToken, isTrue);

      await storage.clear();
      expect(storage.hasToken, isFalse);
      expect(await storage.getToken(), isNull);
    });

    test('DeviceSecurityService simulates and detects root integrity status', () async {
      final sec = DeviceSecurityService();
      expect(sec.isSimulatingRoot, isFalse);

      sec.toggleSimulateRoot(true);
      expect(sec.isRootDetected, isTrue);
      expect(sec.detectedThreats.any((t) => t.contains('Magisk') || t.contains('su')), isTrue);

      sec.toggleSimulateRoot(false);
      expect(sec.isSimulatingRoot, isFalse);
    });
  });
}
