import 'dart:convert';

import 'package:http/http.dart' as http;

/// La API usa cookies de sesión y solo funciona en web bajo el MISMO origen
/// que Django. No transportamos ni guardamos contraseñas, tokens o cookies.
abstract class VenciraApi {
  Future<List<VenciraWorkspace>> fetchWorkspaces();

  Future<VenciraRenewalPage> fetchRenewals(String workspaceId, {int page = 1});

  Future<VenciraRenewal> createRenewal(String workspaceId, VenciraRenewalInput input);

  Future<VenciraRenewal> updateRenewal(
      String workspaceId, String renewalId, VenciraRenewalInput input);

  Future<void> logout();
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
    this.noticeDeadlineOn,
    required this.status,
  });

  final String id;
  final String reference;
  final DateTime expiresOn;
  final DateTime? noticeDeadlineOn;
  final String status;

  factory VenciraRenewal.fromJson(Map<String, dynamic> json) {
    return VenciraRenewal(
      id: json['id'] as String,
      reference: json['customer_reference'] as String,
      expiresOn: DateTime.parse(json['expires_on'] as String),
      noticeDeadlineOn: json['notice_deadline_on'] == null
          ? null
          : DateTime.parse(json['notice_deadline_on'] as String),
      status: json['status'] as String,
    );
  }
}

class VenciraRenewalInput {
  const VenciraRenewalInput({
    required this.reference,
    required this.expiresOn,
    this.noticeDeadlineOn,
    this.status = 'pending',
  });

  final String reference;
  final DateTime expiresOn;
  final DateTime? noticeDeadlineOn;
  final String status;

  static String _isoDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Map<String, dynamic> toJson() => {
        'customer_reference': reference.trim(),
        'expires_on': _isoDate(expiresOn),
        'notice_deadline_on':
            noticeDeadlineOn == null ? null : _isoDate(noticeDeadlineOn!),
        'status': status,
      };
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

  bool _validUuid(String id) {
    return RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
      r'[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(id);
  }

  Future<String> _csrf() async {
    final response = await _fetch('/api/v1/csrf/') as Map<String, dynamic>;
    final token = response['csrfToken'];
    if (token is! String || token.length < 32) {
      throw const VenciraApiException();
    }
    return token;
  }

  Future<VenciraRenewal> _write(
    String workspaceId,
    VenciraRenewalInput input, {
    String? renewalId,
  }) async {
    if (!_validUuid(workspaceId) ||
        (renewalId != null && !_validUuid(renewalId))) {
      throw const VenciraApiException();
    }
    final csrfToken = await _csrf();
    final target = renewalId == null
        ? '/api/v1/workspaces/$workspaceId/renewals/'
        : '/api/v1/workspaces/$workspaceId/renewals/$renewalId/';
    final uri = _baseUri.resolve(target);
    late http.Response response;
    try {
      final headers = {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'X-CSRFToken': csrfToken,
      };
      final body = jsonEncode(input.toJson());
      response = renewalId == null
          ? await _client.post(uri, headers: headers, body: body)
          : await _client.patch(uri, headers: headers, body: body);
    } catch (_) {
      throw const VenciraApiException();
    }
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const VenciraUnauthorized();
    }
    if (response.statusCode != (renewalId == null ? 201 : 200)) {
      throw const VenciraApiException();
    }
    try {
      return VenciraRenewal.fromJson(
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
      );
    } catch (_) {
      throw const VenciraApiException();
    }
  }

  @override
  Future<VenciraRenewal> createRenewal(
      String workspaceId, VenciraRenewalInput input) =>
      _write(workspaceId, input);

  @override
  Future<VenciraRenewal> updateRenewal(
          String workspaceId, String renewalId, VenciraRenewalInput input) =>
      _write(workspaceId, input, renewalId: renewalId);

  @override
  Future<void> logout() async {
    final token = await _csrf();
    late http.Response response;
    try {
      response = await _client.post(
        _baseUri.resolve('/accounts/logout/'),
        headers: {
          'X-CSRFToken': token,
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: '',
      );
    } catch (_) {
      throw const VenciraApiException();
    }
    // Django redirige tras terminar la sesión; el cliente puede seguir 302.
    if (response.statusCode != 200 && response.statusCode != 302) {
      throw const VenciraApiException();
    }
  }

  void close() {
    if (_ownsClient) _client.close();
  }
}
