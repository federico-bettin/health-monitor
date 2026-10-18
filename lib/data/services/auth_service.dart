import 'package:local_auth/local_auth.dart';

class AuthService {
  final LocalAuthentication _auth = LocalAuthentication();

  /// Controlla se il dispositivo supporta la biometria
  Future<bool> isBiometricAvailable() async {
    try {
      final isAvailable = await _auth.canCheckBiometrics;
      final isDeviceSupported = await _auth.isDeviceSupported();
      return isAvailable && isDeviceSupported;
    } catch (_) {
      return false;
    }
  }

  /// Restituisce i tipi di biometria disponibili
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } catch (_) {
      return [];
    }
  }

  /// Autentica con biometria
  /// Restituisce true se autenticato, false altrimenti
  Future<bool> authenticate({String reason = 'Accedi a SaluteBettin'}) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: false, // permette anche PIN/pattern
          stickyAuth: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }

  /// Cancella l'autenticazione in corso
  Future<void> stopAuthentication() async {
    await _auth.stopAuthentication();
  }
}
