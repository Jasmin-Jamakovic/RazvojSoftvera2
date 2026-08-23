/// Reusable form validators. Each returns null when valid, otherwise an error
/// message that states the expected format/limits. Used with TextFormField so
/// messages render directly below the control.
class Validators {
  static final RegExp _email = RegExp(r'^[\w.\-]+@[\w\-]+\.[\w.\-]+$');
  static final RegExp _phone = RegExp(r'^\+?[0-9 ()\-]{6,20}$');

  static String? required(String? v, String field) {
    if (v == null || v.trim().isEmpty) return '$field je obavezno polje.';
    return null;
  }

  static String? maxLen(String? v, int max, String field) {
    if (v != null && v.trim().length > max) {
      return '$field smije imati najviše $max znakova.';
    }
    return null;
  }

  static String? requiredMax(String? v, int max, String field) =>
      required(v, field) ?? maxLen(v, max, field);

  static String? email(String? v, {bool optional = false}) {
    if (v == null || v.trim().isEmpty) {
      return optional ? null : 'Email je obavezno polje.';
    }
    if (!_email.hasMatch(v.trim())) {
      return 'Unesite ispravnu email adresu (npr. ime@domena.com).';
    }
    return null;
  }

  static String? phone(String? v, {bool optional = false}) {
    if (v == null || v.trim().isEmpty) {
      return optional ? null : 'Broj telefona je obavezno polje.';
    }
    if (!_phone.hasMatch(v.trim())) {
      return 'Unesite ispravan broj telefona (npr. +387 61 123 456).';
    }
    return null;
  }

  static String? password(String? v, {bool optional = false}) {
    if (v == null || v.isEmpty) {
      return optional ? null : 'Lozinka je obavezno polje.';
    }
    if (v.length < 6) return 'Lozinka mora imati najmanje 6 znakova.';
    return null;
  }

  /// Validates a "confirm password" field against the original.
  static String? confirm(String? v, String original) {
    if (v != original) return 'Lozinke se ne podudaraju.';
    return null;
  }
}
