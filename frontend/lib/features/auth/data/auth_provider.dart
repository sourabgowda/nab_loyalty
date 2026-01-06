import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final authRepositoryProvider = Provider(
  (ref) => AuthRepository(FirebaseAuth.instance, FirebaseFunctions.instance),
);

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

class AuthRepository {
  final FirebaseAuth _auth;
  final FirebaseFunctions _functions;

  AuthRepository(this._auth, this._functions);

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required PhoneVerificationCompleted verificationCompleted,
    required PhoneVerificationFailed verificationFailed,
    required PhoneCodeSent codeSent,
    required PhoneCodeAutoRetrievalTimeout codeAutoRetrievalTimeout,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: verificationCompleted,
      verificationFailed: verificationFailed,
      codeSent: codeSent,
      codeAutoRetrievalTimeout: codeAutoRetrievalTimeout,
    );
  }

  Future<void> signInWithCredential(PhoneAuthCredential credential) async {
    await _auth.signInWithCredential(credential);
  }

  Future<bool> verifyPin(String pin) async {
    try {
      final result = await _functions.httpsCallable('verifyPin').call({
        'pin': pin,
      });
      return result.data['success'] == true;
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> setPin(String pin) async {
    try {
      await _functions.httpsCallable('setPin').call({'pin': pin});
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> getUserProfile() async {
    // We might need to fetch user doc directly from Firestore for role/metadata if not in token
    // But for now, let's assume we rely on Firestore SDK in other providers.
    // Or we can call a function if needed.
    return {};
  }

  Exception _handleError(dynamic e) {
    if (e is FirebaseFunctionsException) {
      return Exception(e.message);
    }
    return Exception(e.toString());
  }

  Future<void> signOut() => _auth.signOut();
}

// Controller for UI integration
// Controller for UI integration
final authControllerProvider = AsyncNotifierProvider<AuthController, void>(
  AuthController.new,
);

class AuthController extends AsyncNotifier<void> {
  // We can access ref here directly
  AuthRepository get _repo => ref.read(authRepositoryProvider);

  @override
  Future<void> build() async {
    // Initial state is void (null), consistent with AsyncData(null)
    return;
  }

  String? _verificationId;

  void setVerificationId(String id) {
    _verificationId = id;
  }

  Future<void> sendOtp(
    String phoneNumber, {
    required Function() onCodeSent,
  }) async {
    // Since verifyPhoneNumber uses callbacks, we can't easily wrap strictly in AsyncValue.guard
    // without converting callbacks to Future.
    // However, existing logic updates internal state via callbacks.
    // We will mimic the previous logic but update 'state' property directly.

    state = const AsyncLoading();
    try {
      await _repo.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (credential) async {
          await _repo.signInWithCredential(credential);
        },
        verificationFailed: (e) {
          state = AsyncError(
            e.message ?? "Verification failed",
            StackTrace.current,
          );
        },
        codeSent: (verificationId, resendToken) {
          _verificationId = verificationId;
          state = const AsyncData(null);
          onCodeSent();
        },
        codeAutoRetrievalTimeout: (verificationId) {
          _verificationId = verificationId;
        },
      );
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
    }
  }

  Future<void> verifyOtp(String otp) async {
    if (_verificationId == null) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: otp,
      );
      await _repo.signInWithCredential(credential);
      // Mark PIN session as verified since we just did a strong auth
      ref.read(pinSessionProvider.notifier).verified();
    });
  }
}

// Simple state provider to track if PIN has been verified in this session
final pinSessionProvider = NotifierProvider<PinSessionNotifier, bool>(
  PinSessionNotifier.new,
);

class PinSessionNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void verified() {
    state = true;
  }
}
