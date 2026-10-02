import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_mobile/core/banking_repository.dart';
import 'package:frontend_mobile/core/circuit_breaker.dart';
import 'package:frontend_mobile/core/encrypted_token_storage.dart';
import 'package:frontend_mobile/core/mock_banking_client.dart';
import 'package:frontend_mobile/core/sms_service.dart';
import 'package:frontend_mobile/models/account_model.dart';
import 'package:frontend_mobile/models/transaction_model.dart';

void main() {
  group('Encrypted Token Storage Tests', () {
    test('Encrypts and decrypts JWT token with authenticated cipher', () async {
      final storage = EncryptedTokenStorage();
      await storage.clear();

      const rawToken = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJ1c2VyMTIzIn0';
      await storage.saveToken(
        rawJwtToken: rawToken,
        customerId: 'CUST-1001',
        role: 'CUSTOMER',
      );

      expect(storage.hasToken, isTrue);
      expect(storage.storedCustomerId, equals('CUST-1001'));
      expect(storage.storedRole, equals('CUSTOMER'));
      expect(storage.encryptedCiphertext, isNotNull);
      expect(storage.encryptedCiphertext, isNot(contains(rawToken)));

      final decrypted = await storage.getToken();
      expect(decrypted, equals(rawToken));

      await storage.clear();
      expect(storage.hasToken, isFalse);
      expect(await storage.getToken(), isNull);
    });
  });

  group('Circuit Breaker Resilience Tests', () {
    test('Transitions from CLOSED to OPEN after failure threshold', () async {
      final cb = CircuitBreaker();
      cb.configure(failureThreshold: 2, resetTimeout: const Duration(milliseconds: 100));
      cb.reset();

      expect(cb.state, equals(CircuitState.closed));

      // Attempt 1: failure
      try {
        await cb.execute(() async => throw Exception('Service Down 1'));
      } catch (_) {}
      expect(cb.consecutiveFailures, equals(1));
      expect(cb.state, equals(CircuitState.closed));

      // Attempt 2: trips circuit breaker
      try {
        await cb.execute(() async => throw Exception('Service Down 2'));
      } catch (_) {}
      expect(cb.consecutiveFailures, equals(2));
      expect(cb.state, equals(CircuitState.open));

      // Attempt 3: fails fast with CircuitBreakerException
      expect(
        () => cb.execute(() async => 'should not reach'),
        throwsA(isA<CircuitBreakerException>()),
      );

      // Reset
      cb.reset();
      expect(cb.state, equals(CircuitState.closed));
    });
  });

  group('Remittance Engine & Risk Analysis Tests', () {
    final client = MockBankingClient();

    test('Computes ForEx and executes cross-currency transfer with dual commit', () async {
      final senderAcctBefore = await client.getAccountById('ACCT-2001-PHP');
      final destAcctBefore = await client.getAccountById('ACCT-2003-EUR');
      expect(senderAcctBefore, isNotNull);
      expect(destAcctBefore, isNotNull);

      final initialSenderBal = senderAcctBefore!.balanceAmount;
      final initialDestBal = destAcctBefore!.balanceAmount;

      // Transfer 3,125 PHP to EUR account (at 0.016 rate = 50 EUR, 0.5% fee = 15.62 PHP)
      final txn = await client.executeTransaction(
        sourceAccountId: 'ACCT-2001-PHP',
        counterpartyAccountId: 'ACCT-2003-EUR',
        txnType: TransactionType.transfer,
        amount: 3125.00,
        idempotencyKey: 'TEST-IDEMP-CROSS',
      );

      expect(txn.auditState, equals(AuditState.committed));
      expect(txn.isCrossCurrency, isTrue);
      expect(txn.destAmount, equals(50.00));
      expect(txn.destCurrencyCode, equals('EUR'));

      final senderAcctAfter = await client.getAccountById('ACCT-2001-PHP');
      final destAcctAfter = await client.getAccountById('ACCT-2003-EUR');

      expect(destAcctAfter!.balanceAmount, equals(initialDestBal + 50.00));
      expect(senderAcctAfter!.balanceAmount, lessThan(initialSenderBal));
    });

    test('Rejects transaction when source account is frozen', () async {
      await client.updateAccountStatus('ACCT-1002-USD', AccountStatus.frozen);

      try {
        await client.executeTransaction(
          sourceAccountId: 'ACCT-1002-USD',
          counterpartyAccountId: 'ACCT-1001-PHP',
          txnType: TransactionType.transfer,
          amount: 100.0,
        );
        fail('Should have thrown an exception for frozen account');
      } catch (e) {
        expect(e.toString(), contains('FROZEN'));
      } finally {
        await client.updateAccountStatus('ACCT-1002-USD', AccountStatus.active);
      }
    });

    test('Evaluates Risk Analysis score for standard vs elevated transactions', () {
      final lowRisk = client.evaluateRisk(
        amount: 1000.0,
        currency: 'PHP',
        txnType: TransactionType.transfer,
        isCrossCurrency: false,
      );
      expect(lowRisk['decision'], equals('APPROVED_LOW_RISK'));
      expect(lowRisk['score'], lessThan(30.0));

      final highRisk = client.evaluateRisk(
        amount: 250000.0,
        currency: 'PHP',
        txnType: TransactionType.withdrawal,
        isCrossCurrency: true,
      );
      expect(highRisk['score'], greaterThan(50.0));
    });
  });

  group('Real-Time SMS & 2FA OTP Authentication & Transaction Tests', () {
    final sms = SmsService();
    final repo = BankingRepository();

    test('SmsService dispatches simulated OTP SMS with valid message payload', () async {
      sms.configure(provider: SmsProvider.simulated);
      final result = await sms.sendOtpSms(
        recipientPhone: '+63 917 123 4567',
        otpCode: '582910',
        purpose: 'Deposit ₱5,000.00',
      );

      expect(result.isSuccess, isTrue);
      expect(result.statusMessage, contains('+639171234567'));
      expect(sms.lastResult, isNotNull);
      expect(sms.lastResult!.isSuccess, isTrue);
    });

    test('initiateLoginWithOtp generates 6-digit OTP and masks registered phone', () async {
      final pending = await repo.initiateLoginWithOtp('juan.delacruz@example.com', 'password123');
      expect(pending, isNotNull);
      expect(pending!.otpCode.length, equals(6));
      expect(int.tryParse(pending.otpCode), isNotNull);
      expect(pending.maskedPhone, contains('•••'));
    });

    test('Allows custom phone override so user receives SMS to their actual phone', () async {
      repo.setContactPhoneOverride('+63 999 888 7777');
      expect(await repo.getRegisteredRawPhone(), equals('+63 999 888 7777'));

      final pending = await repo.initiateLoginWithOtp('juan.delacruz@example.com', 'password123');
      expect(pending, isNotNull);
      expect(pending!.maskedPhone, contains('+63 999'));

      // Reset override
      repo.setContactPhoneOverride(null);
    });

    test('sendRealTimeTransactionOtp generates 6-digit OTP for deposits & withdrawals', () async {
      final depositOtp = await repo.sendRealTimeTransactionOtp(purpose: 'Deposit of PHP 10,000.00');
      expect(depositOtp.length, equals(6));
      expect(int.tryParse(depositOtp), isNotNull);
      expect(sms.lastResult, isNotNull);
      expect(sms.lastResult!.isSuccess, isTrue);

      final withdrawalOtp = await repo.sendRealTimeTransactionOtp(purpose: 'Withdrawal of USD 100.00');
      expect(withdrawalOtp.length, equals(6));
      expect(int.tryParse(withdrawalOtp), isNotNull);
    });
  });
}

