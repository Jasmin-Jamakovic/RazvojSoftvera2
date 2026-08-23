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

  /// Whole number within [min, max].
  static String? intRange(String? v, {required int min, int? max, required String field}) {
    final r = required(v, field);
    if (r != null) return r;
    final n = int.tryParse(v!.trim());
    if (n == null) return '$field mora biti cijeli broj.';
    if (n < min) return '$field ne smije biti manje od $min.';
    if (max != null && n > max) return '$field ne smije biti veće od $max.';
    return null;
  }

  /// Decimal greater than 0 (optionally capped).
  static String? positiveDecimal(String? v, {required String field, double? max}) {
    final r = required(v, field);
    if (r != null) return r;
    final n = double.tryParse(v!.trim().replaceAll(',', '.'));
    if (n == null) return '$field mora biti broj (npr. 50 ili 49.99).';
    if (n <= 0) return '$field mora biti veće od 0.';
    if (max != null && n > max) return '$field ne smije biti veće od $max.';
    return null;
  }

  static String? password(String? v, {bool optional = false}) {
    if (v == null || v.isEmpty) {
      return optional ? null : 'Lozinka je obavezno polje.';
    }
    if (v.length < 6) return 'Lozinka mora imati najmanje 6 znakova.';
    return null;
  }
}
