/// Immutable native API endpoint policy; does not authenticate any request.
/// Production use remains blocked until N1 credentials and backend gates pass.
class NativeApiEndpoint {
  NativeApiEndpoint._(this.origin);

  final Uri origin;

  static NativeApiEndpoint parse(String input) {
    final uri = Uri.tryParse(input);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        uri.path.isNotEmpty && uri.path != '/' ||
        uri.port != 443) {
      throw const FormatException('A canonical HTTPS origin is required');
    }
    final host = uri.host.toLowerCase();
    if (host != 'dev.vencira.es' && host != 'vencira.es') {
      throw const FormatException('Unapproved API host');
    }
    return NativeApiEndpoint._(Uri(scheme: 'https', host: host));
  }

  Uri resolveApiPath(String path) {
    if (!path.startsWith('/api/v1/') ||
        path.contains('\\') ||
        path.startsWith('//') ||
        path.split('/').any((part) => part == '..' || part == '.')) {
      throw const FormatException('Invalid API path');
    }
    final parsed = Uri.tryParse(path);
    if (parsed == null || parsed.hasAuthority || parsed.hasFragment ||
        parsed.pathSegments.any((segment) => segment == '..' || segment == '.')) {
      throw const FormatException('Invalid API path');
    }
    return origin.resolveUri(parsed);
  }
}
