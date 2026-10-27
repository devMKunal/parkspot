import 'package:parkspot/core/constants/app_constants.dart';

/// Form validators that plug straight into `validator:`, e.g.
/// `validator: (v) => v.validateEmail()`. Each returns an error message, or
/// null when the value is fine. They mirror the API rules; the server still
/// has the final say.
extension ValidatorsX on String? {
  String get _trimmed => (this ?? '').trim();

  String? validateName() {
    final name = _trimmed;
    if (name.isEmpty) return 'Enter your name';
    if (name.length > AppConstants.nameMaxLength) {
      return 'Keep it under ${AppConstants.nameMaxLength} characters';
    }
    return null;
  }

  // ponytail: loose shape check, the server's z.email() is the real gate.
  static final _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  String? validateEmail() {
    final email = _trimmed;
    if (email.isEmpty) return 'Enter your email';
    if (!_email.hasMatch(email)) return 'Enter a valid email';
    return null;
  }

  /// New password at sign-up. Not trimmed: spaces are valid characters.
  String? validateNewPassword() {
    final password = this ?? '';
    if (password.isEmpty) return 'Enter a password';
    if (password.length < AppConstants.passwordMinLength) {
      return 'Use at least ${AppConstants.passwordMinLength} characters';
    }
    if (password.length > AppConstants.passwordMaxLength) {
      return 'Keep it under ${AppConstants.passwordMaxLength} characters';
    }
    return null;
  }

  /// Password at login: only required, so old accounts aren't locked out by
  /// a rule change.
  String? validatePassword() =>
      (this ?? '').isEmpty ? 'Enter your password' : null;

  String? validateConfirmPassword(String password) {
    if ((this ?? '').isEmpty) return 'Confirm your password';
    if (this != password) return "Passwords don't match";
    return null;
  }

  String? validateRequired([String field = 'This field']) =>
      _trimmed.isEmpty ? '$field is required' : null;
}
