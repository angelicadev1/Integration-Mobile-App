/// Distinct Error Codes for Mobile Banking Operations.
/// Meets requirement TR-M10:
/// "Distinct messages for high-risk decline, insufficient funds, rate limiting, and security-check unavailable (TR-E03)"
enum BankingErrorCode {
  highRiskDecline,
  insufficientFunds,
  rateLimitExceeded,
  securityCheckUnavailable,
  networkTimeout,
  accountFrozen,
  circuitBreakerOpen,
  generalError,
}

class BankingException implements Exception {
  final BankingErrorCode code;
  final String message;
  final int? statusCode;
  final dynamic originalError;

  const BankingException({
    required this.code,
    required this.message,
    this.statusCode,
    this.originalError,
  });

  static const highRiskDeclineCode = BankingErrorCode.highRiskDecline;
  static const insufficientFundsCode = BankingErrorCode.insufficientFunds;
  static const rateLimitExceededCode = BankingErrorCode.rateLimitExceeded;
  static const securityCheckUnavailableCode = BankingErrorCode.securityCheckUnavailable;
  static const circuitBreakerOpenCode = BankingErrorCode.circuitBreakerOpen;

  bool get isHighRiskDecline => code == BankingErrorCode.highRiskDecline;
  bool get isInsufficientFunds => code == BankingErrorCode.insufficientFunds;
  bool get isRateLimited => code == BankingErrorCode.rateLimitExceeded;
  bool get isSecurityUnavailable => code == BankingErrorCode.securityCheckUnavailable;
  bool get isCircuitBreakerOpen => code == BankingErrorCode.circuitBreakerOpen;

  /// Factory helper for high-risk decline (TR-M10)
  factory BankingException.highRiskDecline([String? customDetails]) {
    return BankingException(
      code: BankingErrorCode.highRiskDecline,
      statusCode: 422,
      message: customDetails ??
          'Transaction Declined (High Risk): Automated fraud prevention model flagged this transaction as elevated risk (TR-E03). Please contact bank compliance or adjust transaction parameters.',
    );
  }

  /// Factory helper for insufficient funds (TR-M10)
  factory BankingException.insufficientFunds({
    String? message,
    String? accountId,
    double? requiredAmount,
    double? availableBalance,
    String? currency,
  }) {
    final detail = (requiredAmount != null && availableBalance != null && currency != null)
        ? ' Required: $currency ${requiredAmount.toStringAsFixed(2)}, Available: $currency ${availableBalance.toStringAsFixed(2)}.'
        : '';
    return BankingException(
      code: BankingErrorCode.insufficientFunds,
      statusCode: 400,
      message: message ?? 'Transaction Declined (Insufficient Funds): Source pocket does not have enough balance to complete this transfer.$detail',
    );
  }

  /// Factory helper for circuit breaker open (TR-M02, TR-M10)
  factory BankingException.circuitBreakerOpen([String? details]) {
    return BankingException(
      code: BankingErrorCode.circuitBreakerOpen,
      statusCode: 503,
      message: details ?? 'Gateway Unavailable: Circuit breaker is open due to repeated upstream ledger timeouts.',
    );
  }

  /// Factory helper for rate limiting (TR-M10)
  factory BankingException.rateLimitExceeded([dynamic messageOrSeconds]) {
    if (messageOrSeconds is String) {
      return BankingException(
        code: BankingErrorCode.rateLimitExceeded,
        statusCode: 429,
        message: messageOrSeconds,
      );
    }
    final retryAfterSeconds = messageOrSeconds is int ? messageOrSeconds : null;
    final retryText = retryAfterSeconds != null ? ' Please wait $retryAfterSeconds seconds before retrying.' : ' Please slow down and try again shortly.';
    return BankingException(
      code: BankingErrorCode.rateLimitExceeded,
      statusCode: 429,
      message: 'Too Many Requests (Rate Limit): Transaction velocity threshold reached.$retryText',
    );
  }

  /// Factory helper for security-check unavailable (TR-M10, TR-E03)
  factory BankingException.securityCheckUnavailable([String? details]) {
    return BankingException(
      code: BankingErrorCode.securityCheckUnavailable,
      statusCode: 503,
      message: details ??
          'Security Check Unavailable (TR-E03): The automated fraud scoring & risk analysis engine is temporarily unreachable. To safeguard your account, the transaction was halted without posting.',
    );
  }

  /// Factory helper for network timeout (TR-M04)
  factory BankingException.networkTimeout({String? idempotencyKey}) {
    final keyInfo = idempotencyKey != null ? ' Retrying safely with Idempotency-Key: $idempotencyKey.' : '';
    return BankingException(
      code: BankingErrorCode.networkTimeout,
      statusCode: 504,
      message: 'Network Request Timeout: The server did not respond in time.$keyInfo The transfer has NOT been marked successful.',
    );
  }

  /// Helper to convert HTTP status code and message
  static BankingException fromHttp(int statusCode, [String? errorStr]) {
    return fromErrorString(errorStr ?? '', statusCode: statusCode);
  }

  /// Parse and classify incoming backend error strings or HTTP status codes
  static BankingException fromErrorString(String errorStr, {int? statusCode}) {
    final lower = errorStr.toLowerCase();

    if (statusCode == 429 || lower.contains('rate limit') || lower.contains('too many requests')) {
      return BankingException.rateLimitExceeded(errorStr.isNotEmpty ? errorStr : null);
    }

    if (statusCode == 503) {
      if (lower.contains('circuit') || lower.contains('breaker')) {
        return BankingException.circuitBreakerOpen(errorStr.isNotEmpty ? errorStr : null);
      }
      return BankingException.securityCheckUnavailable(errorStr.isNotEmpty ? errorStr : null);
    }

    if (lower.contains('security check') || lower.contains('security-check') || lower.contains('tr-e03')) {
      return BankingException.securityCheckUnavailable(errorStr.isNotEmpty ? errorStr : null);
    }

    if (statusCode == 403 || lower.contains('high risk') || lower.contains('critical fraud') || lower.contains('compliance hold') || lower.contains('high_risk')) {
      return BankingException.highRiskDecline(errorStr.isNotEmpty ? errorStr : null);
    }

    if (lower.contains('insufficient') || lower.contains('funds') || lower.contains('balance') && lower.contains('low')) {
      return BankingException.insufficientFunds(message: errorStr.isNotEmpty ? errorStr : null);
    }

    if (lower.contains('timeout') || lower.contains('timed out') || lower.contains('connection closed') || statusCode == 504) {
      return BankingException.networkTimeout();
    }

    if (lower.contains('frozen')) {
      return BankingException(
        code: BankingErrorCode.accountFrozen,
        statusCode: 403,
        message: 'Account Frozen: This account is currently restricted by bank governance.',
      );
    }

    if (lower.contains('circuit is open') || lower.contains('circuit breaker')) {
      return BankingException(
        code: BankingErrorCode.circuitBreakerOpen,
        statusCode: 503,
        message: 'Gateway Unavailable: Circuit breaker is tripped to prevent ledger overload. Please retry after cooldown.',
      );
    }

    return BankingException(
      code: BankingErrorCode.generalError,
      statusCode: statusCode,
      message: errorStr.replaceAll('Exception:', '').trim(),
      originalError: errorStr,
    );
  }

  @override
  String toString() => message;
}
