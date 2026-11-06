import 'dart:convert';

/// Pure, local contract check. A correctly shaped token is NOT authenticated:
/// only Django can check its HMAC digest and the current device-session row.
class NativeMobileTokenShape {
  NativeMobileTokenShape._();

  static final RegExp _canonical = RegExp(
    r'^v1\.(a|r)\.([0-9a-f]{32})\.([A-Za-z0-9_-]{43})$',
  );

  static bool accepts(String? token, {required String kind}) {
    if (token == null || (kind != 'a' && kind != 'r')) return false;
    final match = _canonical.firstMatch(token);
    if (match == null || match.group(1) != kind) return false;
    final value = match.group(3)!;
    try {
      final bytes = base64Url.decode('$value=');
      return bytes.length == 32 &&
          base64UrlEncode(bytes).replaceAll('=', '') == value;
    } on FormatException {
      return false;
    }
  }
}
