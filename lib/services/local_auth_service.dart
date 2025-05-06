import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';

class LocalAuthService {
  static final LocalAuthentication _auth = LocalAuthentication();
  static final LocalAuthService _instance = LocalAuthService._internal();
  
  // Singleton pattern
  factory LocalAuthService() => _instance;
  
  LocalAuthService._internal();
  
  /// Check if the device supports biometric authentication
  Future<bool> isBiometricAvailable() async {
    try {
      // Check if device supports biometrics
      final bool canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
      // Check if device can use device credentials (PIN/pattern/password)
      final bool canAuthenticate = canAuthenticateWithBiometrics || await _auth.isDeviceSupported();
      
      print('Biometric availability: canAuthWithBiometrics=$canAuthenticateWithBiometrics, canAuthenticate=$canAuthenticate');
      return canAuthenticate;
    } on PlatformException catch (e) {
      print('Error checking biometric availability: ${e.message}, details: ${e.details}, code: ${e.code}');
      return false;
    }
  }
  
  /// Get available biometric types
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      final biometrics = await _auth.getAvailableBiometrics();
      print('Available biometrics: $biometrics');
      return biometrics;
    } on PlatformException catch (e) {
      print('Error getting available biometrics: ${e.message}, details: ${e.details}, code: ${e.code}');
      return [];
    }
  }
  
  /// Authenticate the user with biometrics or device credentials
  Future<bool> authenticate({
    required String reason,
    bool biometricOnly = false,
  }) async {
    try {
      // First check if authentication is available
      final isAvailable = await isBiometricAvailable();
      if (!isAvailable) {
        print('Biometric authentication not available on this device');
        return false;
      }
      
      // Get available biometrics for debugging
      await getAvailableBiometrics();
      
      // Attempt authentication
      print('Attempting authentication with reason: $reason');
      final result = await _auth.authenticate(
        localizedReason: reason,
        options: AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: biometricOnly,
        ),
      );
      
      print('Authentication result: $result');
      return result;
    } on PlatformException catch (e) {
      print('Error authenticating: ${e.message}, details: ${e.details}, code: ${e.code}');
      return false;
    } catch (e) {
      print('Unexpected error during authentication: $e');
      return false;
    }
  }
}