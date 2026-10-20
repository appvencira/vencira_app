import 'dart:convert';

import 'package:http/http.dart' as http;

/// La API usa cookies de sesión y solo funciona en web bajo el MISMO origen
/// que Django. No transportamos ni guardamos contraseñas, tokens o cookies.
abstract class VenciraApi {
  Future<List<VenciraWorkspace>> fetchWorkspaces();

  Future<VenciraRenewalPage> fetchRenewals(String workspaceId, {int page = 1});
}

class VenciraUnauthorized implements Exception {
  const VenciraUnauthorized();
}

class VenciraApiException implements Exception {
  const VenciraApiException();
}

class VenciraWorkspace {
  const VenciraWorkspace({
    required this.id,
    required this.name,
    required this.role,
  });

  final String id;
  final String name;
  final String role;

  factory VenciraWorkspace.fromJson(Map<String, dynamic> json) {
    return VenciraWorkspace(
      id: json['id'] as String,
      name: json['name'] as String,
      role: json['role'] as String,
    );
  }
}

class VenciraRenewal {
  const VenciraRenewal({
    required this.id,
    required this.reference,
    required this.expiresOn,
    required this.status,
  });

  final String id;
  final String reference;
  final DateTime expiresOn;
  final String status;

  factory VenciraRenewal.fromJson(Map<String, dynamic> json) {
    return VenciraRenewal(
      id: json['id'] as String,
      reference: json['customer_reference'] as String,
      expiresOn: DateTime.parse(json['expires_on'] as String),
      status: json['status'] as String,
    );
  }
}

class VenciraRenewalPage {
  const VenciraRenewalPage({
    required this.total,
    required this.items,
    required this.hasNext,
  });

  final int total;
  final List<VenciraRenewal> items;
  final bool hasNext;

  factory VenciraRenewalPage.fromJson(Map<String, dynamic> json) {
    return VenciraRenewalPage(
      total: json['count'] as int,
      items: (json['results'] as List<dynamic>)
          .map((value) => VenciraRenewal.fromJson(value as Map<String, dynamic>))
          .toList(growable: false),
      hasNext: json['next'] != null,
    );
  }
}

class HttpVenciraApi implements VenciraApi {
  HttpVenciraApi({http.Client? client, Uri? baseUri})
      : _client = client ?? http.Client(),
        _ownsClient = client == null,
        _baseUri = baseUri ?? Uri.base;

  final http.Client _client;
  final bool _ownsClient;
  final Uri _baseUri;

  /// No sigue URLs next suministradas por el servidor ni orígenes externos.
  /// El path y los UUID proceden de los valores seleccionados en la app.
  Future<Object?> _fetch(String path) async {
    final uri = _baseUri.resolve(path);
    late http.Response response;
    try {
      response = await _client.get(uri, headers: const {
        'Accept': 'application/json',
      });
    } catch (_) {
      throw const VenciraApiException();
    }
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const VenciraUnauthorized();
    }
    if (response.statusCode != 200) {
      throw const VenciraApiException();
    }
    try {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      throw const VenciraApiException();
    }
  }

  @override
  Future<List<VenciraWorkspace>> fetchWorkspaces() async {
    try {
      final payload = await _fetch('/api/v1/workspaces/') as List<dynamic>;
      return payload
          .map((value) => VenciraWorkspace.fromJson(value as Map<String, dynamic>))
          .toList(growable: false);
    } on VenciraUnauthorized {
      rethrow;
    } catch (_) {
      throw const VenciraApiException();
    }
  }

  @override
  Future<VenciraRenewalPage> fetchRenewals(
    String workspaceId, {
    int page = 1,
  }) async {
    // UUID estrictos; no admitimos paths arbitrarios ni traversal.
    final uuid = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
      r'[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );
    if (!uuid.hasMatch(workspaceId) || page < 1) {
      throw const VenciraApiException();
    }
    try {
      final path = '/api/v1/workspaces/$workspaceId/renewals/?page=$page';
      final payload = await _fetch(path) as Map<String, dynamic>;
      return VenciraRenewalPage.fromJson(payload);
    } on VenciraUnauthorized {
      rethrow;
    } catch (_) {
      throw const VenciraApiException();
    }
  }

  void close() {
    if (_ownsClient) _client.close();
  }
}
