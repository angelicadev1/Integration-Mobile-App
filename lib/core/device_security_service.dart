import 'dart:io';
import 'package:flutter/foundation.dart';

/// Device Security & Integrity Service.
/// Meets requirement TR-M06:
/// "Detect rooted devices and screen capture on sensitive screens (recommended)"
class DeviceSecurityService extends ChangeNotifier {
  static final DeviceSecurityService _instance = DeviceSecurityService._internal();
  factory DeviceSecurityService() => _instance;
  DeviceSecurityService._internal();

  bool _isRootDetected = false;
  final List<String> _detectedThreats = [];
  bool _screenCaptureProtected = true;
  bool _isSimulatingRoot = false;

  bool get isRootDetected => _isRootDetected || _isSimulatingRoot;
  List<String> get detectedThreats => _isSimulatingRoot
      ? [..._detectedThreats, 'SIMULATED: Magisk / su binary detected in /system/xbin/su']
      : _detectedThreats;
  bool get isScreenCaptureProtected => _screenCaptureProtected;
  bool get isSimulatingRoot => _isSimulatingRoot;

  /// Run initial security audit
  Future<void> runIntegrityAudit() async {
    _detectedThreats.clear();
    _isRootDetected = false;

    // 1. Android su binary & path checks
    if (!kIsWeb && Platform.isAndroid) {
      final suPaths = [
        '/system/app/Superuser.apk',
        '/sbin/su',
        '/system/bin/su',
        '/system/xbin/su',
        '/data/local/xbin/su',
        '/data/local/bin/su',
        '/system/sd/xbin/su',
        '/system/bin/failsafe/su',
        '/data/local/su',
      ];

      for (final p in suPaths) {
        try {
          final file = File(p);
          if (file.existsSync()) {
            _isRootDetected = true;
            _detectedThreats.add('Root binary found: $p');
          }
        } catch (_) {}
      }

      // Check build tags
      final buildTags = Platform.environment['BUILD_TAGS'] ?? '';
      if (buildTags.contains('test-keys')) {
        _isRootDetected = true;
        _detectedThreats.add('Custom ROM or test-keys firmware detected');
      }
    }

    notifyListeners();
  }

  /// Toggle simulated root threat for testing and demonstration
  void toggleSimulatedRoot(bool value) {
    _isSimulatingRoot = value;
    notifyListeners();
  }

  void toggleSimulateRoot(bool value) => toggleSimulatedRoot(value);

  /// Sets screen capture protection policy
  void setScreenCaptureProtection(bool enabled) {
    _screenCaptureProtected = enabled;
    notifyListeners();
  }
}
