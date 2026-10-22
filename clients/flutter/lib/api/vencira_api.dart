import 'dart:convert';

import 'package:http/http.dart' as http;

/// La API usa cookies de sesión y solo funciona en web bajo el MISMO origen
/// que Django. No transportamos ni guardamos contraseñas, tokens o cookies.
abstract class VenciraApi {
  Future<List<VenciraWorkspace>> fetchWorkspaces();

  Future<VenciraRenewalPage> fetchRenewals(
    String workspaceId, {int page = 1, String search = '', String status = ''});

  /// Agenda de eventos PREVISTOS del día. No representan avisos entregados.
  Future<VenciraAgendaDayPage> fetchAgendaDay(
    String workspaceId, DateTime day, {int page = 1});

  Future<VenciraAgendaMonth> fetchAgendaMonth(String workspaceId, DateTime month);

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

/// Evento tipado de la proyección diaria; los valores son códigos de la API.
class VenciraAgendaEvent {
  const VenciraAgendaEvent({required this.kind, this.basis, this.candidateId});

  final String kind;
  final String? basis;
  final String? candidateId;

  factory VenciraAgendaEvent.fromJson(Map<String, dynamic> json) {
    final kind = json['kind'];
    if (kind != 'expiry' && kind != 'notice_deadline' && kind != 'reminder') {
      throw const FormatException('Unsupported agenda event');
    }
    final candidateId = json['candidate_id'];
    final basis = json['basis'];
    if (kind == 'reminder' &&
        (candidateId is! String ||
         (basis != 'expiry' && basis != 'notice_deadline'))) {
      throw const FormatException('Invalid reminder event');
    }
    return VenciraAgendaEvent(
      kind: kind as String,
      candidateId: candidateId as String?,
      basis: basis as String?,
    );
  }
}

class VenciraAgendaEntry {
  const VenciraAgendaEntry({required this.renewal, required this.events});

  final VenciraRenewal renewal;
  final List<VenciraAgendaEvent> events;

  factory VenciraAgendaEntry.fromJson(Map<String, dynamic> json) {
    return VenciraAgendaEntry(
      renewal: VenciraRenewal.fromJson(json['renewal'] as Map<String, dynamic>),
      events: (json['events'] as List<dynamic>)
          .map((value) => VenciraAgendaEvent.fromJson(value as Map<String, dynamic>))
          .toList(growable: false),
    );
  }
}

class VenciraAgendaDayPage {
  const VenciraAgendaDayPage({
    required this.day,
    required this.total,
    required this.entries,
    required this.hasNext,
  });

  final DateTime day;
  /// Cuenta anotaciones, NO cantidad total de recordatorios.
  final int total;
  final List<VenciraAgendaEntry> entries;
  final bool hasNext;

  factory VenciraAgendaDayPage.fromJson(Map<String, dynamic> json) {
    final dayString = json['day'] as String;
    final date = DateTime.parse(dayString);
    if (dayString != _civilDayIso(date)) {
      throw const FormatException('Invalid civil day');
    }
    return VenciraAgendaDayPage(
      day: date,
      total: json['count'] as int,
      hasNext: json['next'] != null,
      entries: (json['results'] as List<dynamic>)
          .map((value) => VenciraAgendaEntry.fromJson(
              value as Map<String, dynamic>))
          .toList(growable: false),
    );
  }
}

class VenciraMonthCounts {
  const VenciraMonthCounts({required this.pending, required this.contacted});
  final int pending;
  final int contacted;
  int get total => pending + contacted;
  factory VenciraMonthCounts.fromJson(Map<String, dynamic> json) {
    final p = json['pending'], c = json['contacted'];
    if (p is! int || c is! int || p < 0 || c < 0) {
      throw const FormatException('Invalid month counts');
    }
    return VenciraMonthCounts(pending: p, contacted: c);
  }
}

class VenciraMonthDay {
  const VenciraMonthDay({required this.day, required this.expiry,
    required this.notice, required this.reminder});
  final DateTime day;
  final VenciraMonthCounts expiry;
  final VenciraMonthCounts notice;
  final VenciraMonthCounts reminder;
  factory VenciraMonthDay.fromJson(Map<String, dynamic> json) {
    final raw = json['day'];
    if (raw is! String || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(raw)) {
      throw const FormatException('Invalid month day');
    }
    final date = DateTime.parse(raw);
    if (_civilDayIso(date) != raw) throw const FormatException('Invalid civil day');
    return VenciraMonthDay(
      day: date,
      expiry: VenciraMonthCounts.fromJson(json['expiry'] as Map<String, dynamic>),
      notice: VenciraMonthCounts.fromJson(json['notice_deadline'] as Map<String, dynamic>),
      reminder: VenciraMonthCounts.fromJson(json['reminder'] as Map<String, dynamic>),
    );
  }
}

class VenciraAgendaMonth {
  const VenciraAgendaMonth({required this.month, required this.days});
  final DateTime month;
  final List<VenciraMonthDay> days;
  factory VenciraAgendaMonth.fromJson(Map<String, dynamic> json) {
    final raw = json['month'];
    if (raw is! String || !RegExp(r'^\d{4}-(0[1-9]|1[0-2])$').hasMatch(raw)) {
      throw const FormatException('Invalid month');
    }
    final month = DateTime.parse(raw + '-01');
    if (_civilDayIso(month).substring(0, 7) != raw) {
      throw const FormatException('Invalid month period');
    }
    final days = (json['days'] as List<dynamic>)
      .map((value) => VenciraMonthDay.fromJson(value as Map<String, dynamic>))
      .toList(growable: false);
    final seen = <String>{};
    for (final day in days) {
      final iso = _civilDayIso(day.day);
      if (!iso.startsWith(raw + '-') || !seen.add(iso) ||
          day.expiry.total + day.notice.total + day.reminder.total == 0) {
        throw const FormatException('Out-of-month, duplicate or empty day');
      }
    }
    return VenciraAgendaMonth(month: month, days: days);
  }
}

/// Fecha civil, independiente de UTC, huso del servidor o hora de verano.
String _civilDayIso(DateTime day) {
  final y = day.year.toString().padLeft(4, '0');
  final m = day.month.toString().padLeft(2, '0');
  final d = day.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
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
    String search = '',
    String status = '',
  }) async {
    // UUID estrictos; no admitimos paths arbitrarios ni traversal.
    final uuid = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
      r'[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );
    final cleanedSearch = search.trim();
    if (!uuid.hasMatch(workspaceId) ||
        page < 1 ||
        cleanedSearch.length > 80 ||
        (status.isNotEmpty && !const ['pending', 'contacted', 'closed'].contains(status))) {
      throw const VenciraApiException();
    }
    try {
      final params = <String, String>{
        'page': '$page',
        if (cleanedSearch.isNotEmpty) 'q': cleanedSearch,
        if (status.isNotEmpty) 'status': status,
      };
      final path = Uri(
        path: '/api/v1/workspaces/$workspaceId/renewals/',
        queryParameters: params,
      ).toString();
      final payload = await _fetch(path) as Map<String, dynamic>;
      return VenciraRenewalPage.fromJson(payload);
    } on VenciraUnauthorized {
      rethrow;
    } catch (_) {
      throw const VenciraApiException();
    }
  }

  @override
  Future<VenciraAgendaDayPage> fetchAgendaDay(
    String workspaceId, DateTime day, {int page = 1}) async {
    if (!_validUuid(workspaceId) || page < 1 ||
        day.year < 1 || day.year > 9999) {
      throw const VenciraApiException();
    }
    final requested = _civilDayIso(day);
    final path = Uri(
      path: '/api/v1/workspaces/$workspaceId/agenda/',
      queryParameters: {'day': requested, 'page': '$page'},
    ).toString();
    try {
      final result = VenciraAgendaDayPage.fromJson(
          await _fetch(path) as Map<String, dynamic>);
      // Un servidor o proxy mal configurado no debe mezclar fechas en pantalla.
      if (_civilDayIso(result.day) != requested) {
        throw const VenciraApiException();
      }
      return result;
    } on VenciraUnauthorized {
      rethrow;
    } catch (_) {
      throw const VenciraApiException();
    }
  }

  @override
  Future<VenciraAgendaMonth> fetchAgendaMonth(
      String workspaceId, DateTime month) async {
    if (!_validUuid(workspaceId) || month.year < 2000 || month.year > 2100) {
      throw const VenciraApiException();
    }
    final requested = _civilDayIso(DateTime(month.year, month.month, 1))
        .substring(0, 7);
    final path = Uri(
      path: '/api/v1/workspaces/$workspaceId/agenda/month/',
      queryParameters: {'month': requested},
    ).toString();
    try {
      final result = VenciraAgendaMonth.fromJson(
          await _fetch(path) as Map<String, dynamic>);
      if (_civilDayIso(result.month).substring(0, 7) != requested) {
        throw const VenciraApiException();
      }
      return result;
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
