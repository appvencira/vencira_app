import 'native_api_transport.dart';

/// Immutable, intentionally minimal projection of a renewal returned by the
/// test-only mobile workspace contract. No customer PII is retained here.
class NativeWorkspaceRenewal {
  const NativeWorkspaceRenewal({
    required this.id,
    required this.expiresOn,
    required this.status,
  });

  final String id;
  final String expiresOn;
  final String status;
}

/// Typed mobile workspace reader. The Django server MUST enforce membership
/// and per-renewal assignment: UUID validation here is NOT authorization.
/// This port is neither instantiated in main.dart nor approved for production.
class NativeWorkspaceReadPort {
  const NativeWorkspaceReadPort(this.transport);
  final NativeApiTransport transport;

  static final RegExp _uuid = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  );
  static final RegExp _day = RegExp(r'^\d{4}-\d{2}-\d{2}$');

  static bool _validDay(String date) {
    if (!_day.hasMatch(date)) return false;
    final value = DateTime.tryParse(date);
    return value != null &&
        value.toIso8601String().substring(0, 10) == date;
  }

  Future<List<NativeWorkspaceRenewal>> load(String workspaceId) async {
    if (!_uuid.hasMatch(workspaceId)) {
      throw const NativeWorkspacePayloadInvalid();
    }
    final data = await transport.getJson(
      '/api/v1/mobile/workspaces/$workspaceId/renewals/',
    );
    if (data is! Map<String, dynamic> ||
        data.length != 2 ||
        data['workspace_id'] != workspaceId ||
        data['results'] is! List<dynamic>) {
      throw const NativeWorkspacePayloadInvalid();
    }
    final items = data['results'] as List<dynamic>;
    if (items.length > 50) throw const NativeWorkspacePayloadInvalid();
    final results = <NativeWorkspaceRenewal>[];
    for (final item in items) {
      if (item is! Map<String, dynamic> || item.length != 3 ||
          item['id'] is! String || item['expires_on'] is! String ||
          item['status'] is! String) {
        throw const NativeWorkspacePayloadInvalid();
      }
      final id = item['id'] as String;
      final expires = item['expires_on'] as String;
      final status = item['status'] as String;
      if (!_uuid.hasMatch(id) || !_validDay(expires) ||
          !const {'pending', 'contacted', 'closed'}.contains(status)) {
        throw const NativeWorkspacePayloadInvalid();
      }
      results.add(NativeWorkspaceRenewal(
        id: id, expiresOn: expires, status: status,
      ));
    }
    return List<NativeWorkspaceRenewal>.unmodifiable(results);
  }
}

class NativeWorkspacePayloadInvalid implements Exception {
  const NativeWorkspacePayloadInvalid();
}
