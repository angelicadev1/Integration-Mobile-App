import 'dart:async';
import 'package:flutter/foundation.dart';

enum CircuitState {
  closed,   // Normal operation: requests pass through
  open,     // Tripped/Failing: requests fail fast to protect services
  halfOpen, // Probing: trial request to test if service has recovered
}

class CircuitBreakerException implements Exception {
  final String message;
  final CircuitState state;
  final Duration? remainingCooldown;

  CircuitBreakerException({
    required this.message,
    required this.state,
    this.remainingCooldown,
  });

  @override
  String toString() => 'CircuitBreakerException: $message ($state)';
}

/// Circuit Breaker Pattern implementation for Mobile Microservices Resilience.
/// As specified in the architecture diagram:
/// "Encrypted Token Storage & Circuit Breakers" -> Loopback Address 127.0.0.1:8080
class CircuitBreaker extends ChangeNotifier {
  static final CircuitBreaker _instance = CircuitBreaker._internal();
  factory CircuitBreaker() => _instance;
  CircuitBreaker._internal();

  CircuitState _state = CircuitState.closed;
  int _failureThreshold = 3;
  Duration _resetTimeout = const Duration(seconds: 10);
  int _consecutiveFailures = 0;
  int _totalSuccesses = 0;
  int _totalFailures = 0;
  DateTime? _lastFailureTime;
  String? _lastFailureReason;

  CircuitState get state => _state;
  int get failureThreshold => _failureThreshold;
  Duration get resetTimeout => _resetTimeout;
  int get consecutiveFailures => _consecutiveFailures;
  int get totalSuccesses => _totalSuccesses;
  int get totalFailures => _totalFailures;
  DateTime? get lastFailureTime => _lastFailureTime;
  String? get lastFailureReason => _lastFailureReason;

  Duration? get remainingCooldown {
    if (_state != CircuitState.open || _lastFailureTime == null) return null;
    final elapsed = DateTime.now().difference(_lastFailureTime!);
    if (elapsed >= _resetTimeout) return Duration.zero;
    return _resetTimeout - elapsed;
  }

  void configure({int? failureThreshold, Duration? resetTimeout}) {
    if (failureThreshold != null) _failureThreshold = failureThreshold;
    if (resetTimeout != null) _resetTimeout = resetTimeout;
    notifyListeners();
  }

  /// Manually force-reset the circuit breaker to CLOSED
  void reset() {
    _state = CircuitState.closed;
    _consecutiveFailures = 0;
    _lastFailureReason = null;
    notifyListeners();
  }

  /// Manually trip the circuit breaker to OPEN (useful for testing/chaos engineering)
  void trip({String reason = 'Manually tripped'}) {
    _state = CircuitState.open;
    _lastFailureTime = DateTime.now();
    _lastFailureReason = reason;
    notifyListeners();
  }

  /// Executes an async action through the circuit breaker guard.
  /// If the circuit is OPEN, throws [CircuitBreakerException] immediately (fail-fast),
  /// unless [fallback] is provided.
  Future<T> execute<T>(
    Future<T> Function() action, {
    FutureOr<T> Function()? fallback,
    String? operationName,
  }) async {
    _checkStateTransition();

    if (_state == CircuitState.open) {
      final cd = remainingCooldown;
      final msg = 'Circuit is OPEN for loopback 127.0.0.1:8080. Cooldown remaining: ${cd?.inSeconds ?? 0}s. Last error: $_lastFailureReason';
      if (fallback != null) {
        return await fallback();
      }
      throw CircuitBreakerException(
        message: msg,
        state: _state,
        remainingCooldown: cd,
      );
    }

    try {
      final result = await action();
      _onSuccess();
      return result;
    } catch (error) {
      _onFailure(error.toString());
      if (fallback != null) {
        return await fallback();
      }
      rethrow;
    }
  }

  void _checkStateTransition() {
    if (_state == CircuitState.open && _lastFailureTime != null) {
      final elapsed = DateTime.now().difference(_lastFailureTime!);
      if (elapsed >= _resetTimeout) {
        _state = CircuitState.halfOpen;
        notifyListeners();
      }
    }
  }

  void _onSuccess() {
    _totalSuccesses++;
    if (_state == CircuitState.halfOpen || _consecutiveFailures > 0) {
      _state = CircuitState.closed;
      _consecutiveFailures = 0;
      _lastFailureReason = null;
      notifyListeners();
    }
  }

  void _onFailure(String errorMsg) {
    _totalFailures++;
    _consecutiveFailures++;
    _lastFailureTime = DateTime.now();
    _lastFailureReason = errorMsg;

    if (_state == CircuitState.halfOpen) {
      // Failed during probe: immediately reopen
      _state = CircuitState.open;
    } else if (_consecutiveFailures >= _failureThreshold) {
      _state = CircuitState.open;
    }
    notifyListeners();
  }
}
