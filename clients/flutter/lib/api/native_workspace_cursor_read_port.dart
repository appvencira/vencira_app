import 'native_api_transport.dart';
import 'native_workspace_read_port.dart';

/// D26 candidate-only signed cursor reader. The cursor is an opaque server
/// value; it cannot authorize anything without current bearer + membership.
class NativeWorkspaceCursorPage {
  const NativeWorkspaceCursorPage({
    required this.results, required this.nextCursor,
  });

  final List<NativeWorkspaceRenewal> results;
  final String? nextCursor;
}

class NativeWorkspaceCursorReadPort {
  const NativeWorkspaceCursorReadPort(this.transport);
  final NativeApiTransport transport;

  static final _uuid = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  );
  static final _cursor = RegExp(r'^[A-Za-z0-9_:.-]+$');
  static final _day = RegExp(r'^\d{4}-\d{2}-\d{2}$');
  static const _status = {'pending', 'contacted', 'closed'};

  Future<NativeWorkspaceCursorPage> loadPage(
      String workspaceId, {String? cursor}) async {
    if (!_uuid.hasMatch(workspaceId) ||
        (cursor != null && (cursor.length < 10 || cursor.length > 1024 ||
            !_cursor.hasMatch(cursor)))) {
      throw const NativeWorkspacePayloadInvalid();
    }
    final json = await transport.getJson(
      '/api/v1/mobile/workspaces/$workspaceId/renewals/cursor/',
      query: cursor == null ? const {} : {'cursor': cursor},
    );
    if (json is! Map<String, dynamic> || json.length != 3 ||
        json['workspace_id'] != workspaceId ||
        json['results'] is! List<dynamic>) {
      throw const NativeWorkspacePayloadInvalid();
    }
    final items = json['results'] as List<dynamic>;
    if (items.length > 50) throw const NativeWorkspacePayloadInvalid();
    final next = json['next_cursor'];
    if (next != null && (next is! String || next.length < 10 ||
        next.length > 1024 || !_cursor.hasMatch(next) ||
        items.length != 50)) {
      throw const NativeWorkspacePayloadInvalid();
    }
    final results = <NativeWorkspaceRenewal>[];
    for (final row in items) {
      if (row is! Map<String, dynamic> || row.length != 3 ||
          row['id'] is! String || row['expires_on'] is! String ||
          row['status'] is! String) {
        throw const NativeWorkspacePayloadInvalid();
      }
      final id = row['id'] as String;
      final date = row['expires_on'] as String;
      final parsed = DateTime.tryParse(date);
      if (!_uuid.hasMatch(id) || !_day.hasMatch(date) ||
          parsed == null || parsed.toIso8601String().substring(0, 10) != date ||
          !_status.contains(row['status'])) {
        throw const NativeWorkspacePayloadInvalid();
      }
      results.add(NativeWorkspaceRenewal(
        id: id, expiresOn: date, status: row['status'] as String,
      ));
    }
    return NativeWorkspaceCursorPage(
      results: List.unmodifiable(results),
      nextCursor: next as String?,
    );
  }
}
