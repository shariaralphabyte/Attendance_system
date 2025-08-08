// services/biometric_service.dart
import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';
import 'dart:io' show Platform;

class BiometricService {
  static final LocalAuthentication _auth = LocalAuthentication();

  /// Check if biometric authentication is available on the device
  static Future<bool> isBiometricAvailable() async {
    try {
      final bool canCheckBiometrics = await _auth.canCheckBiometrics;
      final bool isDeviceSupported = await _auth.isDeviceSupported();
      return canCheckBiometrics && isDeviceSupported;
    } on PlatformException catch (e) {
      print('Biometric availability check failed: $e');
      return false;
    }
  }

  /// Get list of enrolled biometric types
  static Future<List<BiometricType>> getEnrolledBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } on PlatformException catch (e) {
      print('Failed to get enrolled biometrics: $e');
      return [];
    }
  }

  /// Authenticate user with biometrics
  static Future<bool> authenticate({
    String localizedReason = 'Scan your fingerprint or face to authenticate',
    bool useErrorDialogs = true,
    bool stickyAuth = true,
  }) async {
    try {
      // Check if biometric authentication is available
      final bool isAvailable = await isBiometricAvailable();
      if (!isAvailable) {
        return false;
      }

      // Perform authentication
      final bool didAuthenticate = await _auth.authenticate(
        localizedReason: localizedReason,
        options: const AuthenticationOptions(
          useErrorDialogs: useErrorDialogs,
          stickyAuth: stickyAuth,
        ),
      );

      return didAuthenticate;
    } on PlatformException catch (e) {
      print('Biometric authentication failed: $e');
      return false;
    }
  }

  /// Get the biometric type name for display
  static String getBiometricTypeName(BiometricType type) {
    switch (type) {
      case BiometricType.face:
        return 'Face';
      case BiometricType.fingerprint:
        return 'Fingerprint';
      case BiometricType.iris:
        return 'Iris';
      case BiometricType.strong:
        return 'Strong';
      case BiometricType.weak:
        return 'Weak';
      default:
        return 'Biometric';
    }
  }

  /// Get appropriate authentication message based on available biometrics
  static Future<String> getAuthMessage() async {
    final List<BiometricType> availableBiometrics = await getEnrolledBiometrics();
    
    if (availableBiometrics.isEmpty) {
      return 'No biometric authentication available';
    }

    if (availableBiometrics.contains(BiometricType.face) && 
        availableBiometrics.contains(BiometricType.fingerprint)) {
      return 'Scan your fingerprint or use face recognition to authenticate';
    } else if (availableBiometrics.contains(BiometricType.face)) {
      return 'Use face recognition to authenticate';
    } else if (availableBiometrics.contains(BiometricType.fingerprint)) {
      return 'Scan your fingerprint to authenticate';
    } else {
      return 'Use biometric authentication to authenticate';
    }
  }
}