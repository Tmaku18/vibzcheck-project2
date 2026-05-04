import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vibzcheck/features/auth/application/auth_controller.dart';

/// Verifies that every FirebaseAuth error code surfaced by sign-in / sign-up
/// flows maps to a single human-readable line and that we never leak raw
/// stack traces back into the UI.
///
/// This is the only branching logic in `auth_controller.dart` (the controller
/// itself is a thin pass-through to `AuthRepository`, which wraps the
/// FirebaseAuth SDK). We test the mapping exhaustively so any future addition
/// to the switch is forced to ship with a paired test.
void main() {
  FirebaseAuthException ex(String code, [String? message]) =>
      FirebaseAuthException(code: code, message: message);

  group('describeFirebaseAuthError - known codes', () {
    test('invalid-email maps to a friendly hint', () {
      expect(
        describeFirebaseAuthError(ex('invalid-email')),
        'That email address is not valid.',
      );
    });

    test('user-disabled maps to a disabled-account hint', () {
      expect(
        describeFirebaseAuthError(ex('user-disabled')),
        'This account has been disabled.',
      );
    });

    // Three different SDK codes all funnel into the same generic
    // "wrong credentials" line so we never reveal which half of the pair was
    // wrong (an account-enumeration safety property).
    test('user-not-found, wrong-password and invalid-credential are unified',
        () {
      const expected = 'Email or password is incorrect.';
      expect(describeFirebaseAuthError(ex('user-not-found')), expected);
      expect(describeFirebaseAuthError(ex('wrong-password')), expected);
      expect(describeFirebaseAuthError(ex('invalid-credential')), expected);
    });

    test('email-already-in-use maps to a duplicate-account hint', () {
      expect(
        describeFirebaseAuthError(ex('email-already-in-use')),
        'An account already exists for that email.',
      );
    });

    test('weak-password tells the user the minimum length', () {
      expect(
        describeFirebaseAuthError(ex('weak-password')),
        'Password is too weak. Use at least 6 characters.',
      );
    });

    test('network-request-failed prompts the user to check connectivity', () {
      expect(
        describeFirebaseAuthError(ex('network-request-failed')),
        'Network error. Check your connection and try again.',
      );
    });

    test('too-many-requests asks the user to back off', () {
      expect(
        describeFirebaseAuthError(ex('too-many-requests')),
        'Too many attempts. Please wait a moment and try again.',
      );
    });
  });

  group('describeFirebaseAuthError - fallthrough', () {
    test('unknown FirebaseAuthException code falls back to its raw message',
        () {
      expect(
        describeFirebaseAuthError(ex('quota-exceeded', 'Quota exhausted.')),
        'Quota exhausted.',
      );
    });

    test(
      'unknown FirebaseAuthException with no message includes the code so '
      'the user can still report it',
      () {
        expect(
          describeFirebaseAuthError(ex('mystery-error')),
          'Authentication failed (mystery-error).',
        );
      },
    );

    test('non-FirebaseAuth errors are wrapped in a safe one-liner', () {
      expect(
        describeFirebaseAuthError(StateError('boom')),
        'Unexpected error: Bad state: boom',
      );
    });

    test('null-shaped errors still produce a printable string', () {
      // We don't pass `null` itself (the parameter is non-nullable), but
      // exotic types like `Object` should still flow through `toString`.
      expect(describeFirebaseAuthError(Object()), startsWith('Unexpected error:'));
    });
  });
}
