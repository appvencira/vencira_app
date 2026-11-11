import 'native_api_transport.dart';

/// Minimal renewal projection. No customer PII is retained on the client.
class NativeWorkspaceRenewal {
  const NativeWorkspaceRenewal({
    required this.id, required this.expiresOn, required this.status,
  });

  final String id;
  final String expiresOn;
  final String status;
}

class NativeWorkspacePage {
  const NativeWorkspacePage({required this.results, required this.nextOffset});

  final List<NativeWorkspaceRenewal> results;
  final int? nextOffset;
}

/// Candidate-only mobile workspace reader; the server rechecks authorization
/// on every page. This is NOT wired into the operational Flutter entrypoint.
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

  /// Compatibility: first page only. Call [loadPage] for subsequent pages.
  Future<List<NativeWorkspaceRenewal>> load(String workspaceId) async =>
      (await loadPage(workspaceId)).results;

  Future<NativeWorkspacePage> loadPage(String workspaceId, {int offset = 0}) async {
    if (!_uuid.hasMatch(workspaceId) || offset < 0 || offset > 10000 ||
        offset % 50 != 0) {
      throw const NativeWorkspacePayloadInvalid();
    }
    final data = await transport.getJson(
      '/api/v1/mobile/workspaces/$workspaceId/renewals/',
      query: offset == 0 ? const {} : {'offset': '$offset'},
    );
    if (data is! Map<String, dynamic> ||
        data.length != 3 ||
        data['workspace_id'] != workspaceId ||
        data['results'] is! List<dynamic>) {
      throw const NativeWorkspacePayloadInvalid();
    }
    final items = data['results'] as List<dynamic>;
    if (items.length > 50) throw const NativeWorkspacePayloadInvalid();
    final next = data['next_offset'];
    if (next != null &&
        (next is! int || next != offset + 50 || items.length != 50 ||
         next > 10000)) {
      throw const NativeWorkspacePayloadInvalid();
    }
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
    return NativeWorkspacePage(
      results: List<NativeWorkspaceRenewal>.unmodifiable(results),
      nextOffset: next as int?,
    );
  }
}

class NativeWorkspacePayloadInvalid implements Exception {
  const NativeWorkspacePayloadInvalid();
}
