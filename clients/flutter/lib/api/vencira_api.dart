import 'dart:convert';

import 'package:http/http.dart' as http;

/// La API usa cookies de sesión y solo funciona en web bajo el MISMO origen
/// que Django. No transportamos ni guardamos contraseñas, tokens o cookies.
abstract class VenciraApi {
  Future<List<VenciraWorkspace>> fetchWorkspaces();

  /// Estadísticas agregadas del §11; solo web escritorio y propietarios.
  /// Los clientes de tests antiguos siguen siendo compatibles.
  Future<VenciraResultsSummary> fetchResults(
    String workspaceId, {required String period, required int year,
    int? month, int? quarter,
  }) async => throw const VenciraApiException();



  Future<VenciraRenewalPage> fetchRenewals(
    String workspaceId, {int page = 1, String search = '', String status = ''});

  /// Agenda de eventos PREVISTOS del día. No representan avisos entregados.
  Future<VenciraAgendaDayPage> fetchAgendaDay(
    String workspaceId, DateTime day, {int page = 1});

  Future<VenciraAgendaMonth> fetchAgendaMonth(String workspaceId, DateTime month);

  /// Vista previa informativa §7–8 sin persistir ni enviar avisos.
  Future<VenciraReminderPreview> fetchReminderPreview(
    String workspaceId, String renewalId, {List<int>? daysBefore}
  ) async => throw const VenciraApiException();

  /// O8c: solo borrador por anotación. Nunca habilita mensajes.
  Future<VenciraReminderDraft> fetchReminderDraft(
      String workspaceId, String renewalId) async =>
      throw const VenciraApiException();

  Future<VenciraReminderDraft> saveReminderDraft(
      String workspaceId, String renewalId,
      {required int revision, required List<int> daysBefore,
       Map<String, String>? reasonsByDay}) async =>
      throw const VenciraApiException();

  /// Macrofase B: bandeja de avisos, solo lectura y fecha civil explícita.
  Future<VenciraOperationalInbox> fetchOperationalInbox(String workspaceId,
      DateTime day, {String scope = 'due', int page = 1}) async =>
      throw const VenciraApiException();

  /// Historial de cambios internos de una ocurrencia (nunca envíos).
  Future<VenciraOperationalHistory> fetchOperationalHistory(
      String workspaceId, String renewalId, String reminderId,
      {int page = 1}) async => throw const VenciraApiException();

  /// Avisos internos: no implican notificación externa.
  Future<List<VenciraOperationalReminder>> fetchOperationalReminders(
      String workspaceId, String renewalId) async =>
      throw const VenciraApiException();

  Future<int> activateOperationalReminders(
      String workspaceId, String renewalId, int expectedRevision) async =>
      throw const VenciraApiException();

  Future<VenciraOperationalReminder> updateOperationalReminder(
      String workspaceId, String renewalId, VenciraOperationalReminder reminder,
      String action, String idempotencyKey, {int? daysLater}) async =>
      throw const VenciraApiException();

  /// O9a: evaluación de la pregunta de control, sin registrar respuesta.
  Future<void> createExplicitControl(
      String workspaceId, String renewalId, {
      required DateTime day, required String idempotencyKey,
  }) async => throw const VenciraApiException();

  Future<VenciraControlAssessment> fetchControlAssessment(
      String workspaceId, String renewalId) async =>
      throw const VenciraApiException();

  /// O9b: historial de respuestas manuales (no prueba de entrega).
  Future<List<VenciraControlResponse>> fetchControlResponses(
      String workspaceId, String renewalId) async =>
      throw const VenciraApiException();

  Future<VenciraControlResponse> saveControlResponse(
      String workspaceId, String renewalId, {
      required int revision, required String idempotencyKey,
      required String answer, String? yesOption, int? daysLater,
  }) async => throw const VenciraApiException();

  Future<VenciraRenewal> fetchRenewalDetail(
      String workspaceId, String renewalId);

  /// Historial técnico de creación y cambios: exclusivo UI web de escritorio.
  Future<VenciraHistoryPage> fetchRenewalHistory(
      String workspaceId, String renewalId, {int page = 1});

  Future<VenciraRenewal> createRenewal(String workspaceId, VenciraRenewalInput input);

  Future<VenciraRenewal> updateRenewal(
      String workspaceId, String renewalId, VenciraRenewalInput input);

  /// Acción rápida de seguimiento: PATCH mínimo de status, sin sobrescribir
  /// campos editados por otra sesión. No realiza contacto ni envía mensajes.
  /// La implementación predeterminada permite dobles de prueba existentes.
  Future<VenciraRenewal> changeRenewalStatus(
      String workspaceId, String renewalId, String status) async =>
      throw const VenciraApiException();

  /// Seguimiento manual: fecha civil, no equivale a aviso entregado.
  /// Resuelve una anotación según whitepaper; nunca envía comunicaciones.
  Future<void> applyOutcome(
    String workspaceId, String renewalId, String kind, {
    DateTime? scheduledFor,
  }) async => throw const VenciraApiException();

  Future<VenciraFollowUp?> fetchManualFollowUp(
      String workspaceId, String renewalId) async => null;

  Future<VenciraFollowUp> scheduleManualFollowUp(
      String workspaceId, String renewalId, DateTime day) async =>
      throw const VenciraApiException();

  Future<void> resolveManualFollowUp(
      String workspaceId, String renewalId, String followUpId,
      String action) async => throw const VenciraApiException();

  /// Métodos nuevos con valores por defecto para clientes de pruebas antiguos.
  Future<List<VenciraModalityOption>> fetchModalities(String workspaceId) async =>
      VenciraModalityOption.defaults;

  Future<VenciraModalityOption> addModality(String workspaceId, String label) async =>
      throw const VenciraApiException();

  Future<VenciraModalityOption> editModality(
      String workspaceId, String code, String label) async =>
      throw const VenciraApiException();

  Future<void> removeModality(String workspaceId, String code) async =>
      throw const VenciraApiException();

  Future<VenciraModalityOption> enableModality(
      String workspaceId, String code) async =>
      throw const VenciraApiException();

  Future<VenciraRenewalPage> fetchFilteredRenewals(
      String workspaceId, {int page = 1, String search = '',
      String status = '', String entry = '', String modality = '', String insurer = ''}) =>
      fetchRenewals(workspaceId, page: page, search: search, status: status);

  Future<VenciraAgendaDayPage> fetchFilteredAgendaDay(
      String workspaceId, DateTime day,
      {int page = 1, String entry = '', String modality = '', String insurer = ''}) =>
      fetchAgendaDay(workspaceId, day, page: page);

  Future<VenciraAgendaMonth> fetchFilteredAgendaMonth(
      String workspaceId, DateTime month,
      {String entry = '', String modality = '', String insurer = ''}) =>
      fetchAgendaMonth(workspaceId, month);

  Future<List<VenciraInsurer>> fetchInsurers(String workspaceId,
      {String search = ''}) async => const [];

  Future<VenciraInsurer> createInsurer(String workspaceId, String name) async =>
      throw const VenciraApiException();

  Future<VenciraInsurer> renameInsurer(
      String workspaceId, String id, String name) async =>
      throw const VenciraApiException();

  Future<VenciraInsurer> reactivateInsurer(String workspaceId, String id) async =>
      throw const VenciraApiException();

  Future<void> deactivateInsurer(String workspaceId, String id) async =>
      throw const VenciraApiException();

  /// Sugerencias solo bajo acción del usuario; clientes simulados pueden omitirlas.
  Future<List<VenciraPersonSuggestion>> suggestPeople(
    String workspaceId, String query, {String by = 'name', String? excludeId}
  ) async => const [];

  Future<void> logout();
}

class VenciraConflictException implements Exception {
  const VenciraConflictException();
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

class VenciraModalityOption {
  const VenciraModalityOption({required this.code, required this.label,
      required this.active, required this.builtin});
  final String code;
  final String label;
  final bool active;
  final bool builtin;
  factory VenciraModalityOption.fromJson(Map<String, dynamic> json) {
    final code = json['code'];
    final label = json['label'];
    final active = json['active'];
    final builtin = json['builtin'];
    if (code is! String || label is! String || active is! bool ||
        builtin is! bool) throw const FormatException('Invalid modality');
    return VenciraModalityOption(
      code: code, label: label, active: active, builtin: builtin);
  }
  static const defaults = <VenciraModalityOption>[
    VenciraModalityOption(code:'autos',label:'Autos',active:true,builtin:true),
    VenciraModalityOption(code:'motos',label:'Motos',active:true,builtin:true),
    VenciraModalityOption(code:'patinetes',label:'Patinetes',active:true,builtin:true),
    VenciraModalityOption(code:'hogar',label:'Hogar',active:true,builtin:true),
    VenciraModalityOption(code:'comercio',label:'Comercio',active:true,builtin:true),
    VenciraModalityOption(code:'decesos',label:'Decesos',active:true,builtin:true),
    VenciraModalityOption(code:'salud',label:'Salud',active:true,builtin:true),
    VenciraModalityOption(code:'vida',label:'Vida',active:true,builtin:true),
    VenciraModalityOption(code:'accidentes',label:'Accidentes',active:true,builtin:true),
    VenciraModalityOption(code:'rc',label:'Responsabilidad civil',active:true,builtin:true),
    VenciraModalityOption(code:'comunidades',label:'Comunidades',active:true,builtin:true),
    VenciraModalityOption(code:'otros',label:'Otros',active:true,builtin:true),
  ];
}

class VenciraInsurer {
  const VenciraInsurer({required this.id, required this.name, required this.active});
  final String id;
  final String name;
  final bool active;

  factory VenciraInsurer.fromJson(Map<String, dynamic> json) =>
      VenciraInsurer(
        id: json['id'] as String,
        name: json['name'] as String,
        active: json['active'] as bool,
      );
}

class VenciraPersonSuggestion {
  const VenciraPersonSuggestion({
    required this.sourceId, required this.fullName, required this.nickname,
    required this.phone, required this.email, this.suggestedEntry,
  });
  final String? suggestedEntry;
  final String sourceId;
  final String fullName;
  final String nickname;
  final String phone;
  final String email;

  factory VenciraPersonSuggestion.fromJson(Map<String, dynamic> json) =>
      VenciraPersonSuggestion(
        sourceId: json['source_id'] as String,
        fullName: json['full_name'] as String,
        nickname: json['nickname'] as String,
        phone: json['phone'] as String,
        email: json['email'] as String,
        suggestedEntry: json['suggested_entry'] == 'clients' ? 'clients' : null,
      );
}

class VenciraRenewal {
  const VenciraRenewal({
    required this.id,
    required this.reference,
    required this.expiresOn,
    this.noticeDeadlineOn,
    required this.status,
    this.entry,
    this.modality = '',
    this.insurerId,
    this.fullName = '',
    this.nickname = '',
    this.phone = '',
    this.email = '',
    this.policyNumber = '',
    this.notes = '',
    this.archiveOutcome = '',
  });

  final String id;
  final String reference;
  final String? entry;
  final String modality;
  final String? insurerId;
  final String fullName;
  final String nickname;
  final String phone;
  final String email;
  final String policyNumber;
  final String notes;
  final String archiveOutcome;
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
      entry: json['entry'] as String?,
      modality: json['modality'] as String? ?? '',
      insurerId: json['insurer'] as String?,
      fullName: json['full_name'] as String? ?? '',
      nickname: json['nickname'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      email: json['email'] as String? ?? '',
      policyNumber: json['policy_number'] as String? ?? '',
      notes: json['notes'] as String? ?? '',
      archiveOutcome: json['archive_outcome'] as String? ?? '',
    );
  }
}

class VenciraReminderPreview {
  const VenciraReminderPreview({
    required this.expiresOn, required this.cutoffOn, required this.referenceDay,
    required this.noPreCutoffNotice, required this.lateControlNeedsDecision,
    required this.cutoffAlreadyElapsed, required this.lifeRuleRequiresReview,
    required this.reminders,
  });

  final DateTime expiresOn;
  final DateTime cutoffOn;
  final DateTime referenceDay;
  final bool noPreCutoffNotice;
  final bool lateControlNeedsDecision;
  final bool cutoffAlreadyElapsed;
  final bool lifeRuleRequiresReview;
  final List<VenciraPreviewReminder> reminders;

  static DateTime _readDay(dynamic raw) {
    if (raw is! String ||
        !RegExp(r'^[0-9]{4}-[0-9]{2}-[0-9]{2}$').hasMatch(raw)) {
      throw const FormatException('Invalid civil date');
    }
    final day = DateTime.tryParse(raw);
    if (day == null || day.toIso8601String().substring(0, 10) != raw) {
      throw const FormatException('Invalid civil date');
    }
    return day;
  }

  factory VenciraReminderPreview.fromJson(Map<String, dynamic> json) {
    final raw = json['reminders'];
    if (json['preview_only'] != true || json['delivered'] != false ||
        raw is! List || raw.isEmpty || raw.length > 12 ||
        json['no_pre_cutoff_notice'] is! bool ||
        json['late_control_needs_decision'] is! bool ||
        json['cutoff_already_elapsed'] is! bool ||
        json['life_rule_requires_review'] is! bool) {
      throw const FormatException('Invalid reminder preview');
    }
    final reminders = raw.map((item) {
      if (item is! Map<String, dynamic> ||
          item['days_before'] is! int ||
          item['days_before'] < 0 || item['days_before'] > 365 ||
          item['before_cutoff'] is! bool ||
          item['control_question'] is! bool ||
          item['already_elapsed'] is! bool) {
        throw const FormatException('Invalid reminder');
      }
      return VenciraPreviewReminder(
        daysBefore: item['days_before'] as int,
        scheduledFor: _readDay(item['scheduled_for']),
        controlQuestion: item['control_question'] as bool,
        alreadyElapsed: item['already_elapsed'] as bool,
      );
    }).toList(growable: false);
    return VenciraReminderPreview(
      expiresOn: _readDay(json['expires_on']),
      cutoffOn: _readDay(json['informational_cutoff_on']),
      referenceDay: _readDay(json['reference_day']),
      noPreCutoffNotice: json['no_pre_cutoff_notice'] as bool,
      lateControlNeedsDecision: json['late_control_needs_decision'] as bool,
      cutoffAlreadyElapsed: json['cutoff_already_elapsed'] as bool,
      lifeRuleRequiresReview: json['life_rule_requires_review'] as bool,
      reminders: reminders,
    );
  }
}

class VenciraPreviewReminder {
  const VenciraPreviewReminder({
    required this.daysBefore, required this.scheduledFor,
    required this.controlQuestion, required this.alreadyElapsed,
  });
  final int daysBefore;
  final DateTime scheduledFor;
  final bool controlQuestion;
  final bool alreadyElapsed;
}

class VenciraC2Policy {
  const VenciraC2Policy({
    required this.allowSave,
    required this.manualReviewRequired,
    required this.warningCode,
    required this.offerExplicitControl,
    required this.latestExplicitControlDay,
    required this.isLife,
  });

  final bool allowSave;
  final bool manualReviewRequired;
  final String? warningCode;
  final bool offerExplicitControl;
  final DateTime? latestExplicitControlDay;
  final bool isLife;

  factory VenciraC2Policy.fromJson(Map<String, dynamic> json) {
    const validWarnings = {
      'life_terms_review', 'civil_cutoff_reached',
      'no_pre_cutoff_notice', 'control_day_elapsed',
    };
    final rawWarning = json['warning_code'];
    final rawLast = json['latest_explicit_control_day'];
    if (json['allow_save'] is! bool ||
        json['manual_review_required'] is! bool ||
        json['offer_explicit_control'] is! bool ||
        json['is_life'] is! bool ||
        json['delivery_status'] != 'not_implemented' ||
        (rawWarning != null && !validWarnings.contains(rawWarning)) ||
        (rawLast != null && rawLast is! String) ||
        ((rawLast != null) != (json['offer_explicit_control'] == true))) {
      throw const FormatException('Invalid C2 control policy');
    }
    return VenciraC2Policy(
      allowSave: json['allow_save'] as bool,
      manualReviewRequired: json['manual_review_required'] as bool,
      warningCode: rawWarning as String?,
      offerExplicitControl: json['offer_explicit_control'] as bool,
      latestExplicitControlDay:
          rawLast == null ? null : VenciraControlAssessment._day(rawLast),
      isLife: json['is_life'] as bool,
    );
  }
}

class VenciraControlAssessment {
  const VenciraControlAssessment({
    required this.status, required this.reasons,
    required this.controlDay, required this.cutoffOn,
    required this.controlDaysBefore, required this.draftPersisted,
    this.c2Policy,
  });

  final String status;
  final List<String> reasons;
  final DateTime? controlDay;
  final DateTime cutoffOn;
  final int? controlDaysBefore;
  final bool draftPersisted;
  final VenciraC2Policy? c2Policy;

  static DateTime _day(dynamic raw) {
    if (raw is! String ||
        !RegExp(r'^[0-9]{4}-[0-9]{2}-[0-9]{2}$').hasMatch(raw)) {
      throw const FormatException('Invalid control civil date');
    }
    final day = DateTime.tryParse(raw);
    if (day == null || day.toIso8601String().substring(0, 10) != raw) {
      throw const FormatException('Invalid control civil date');
    }
    return day;
  }

  factory VenciraControlAssessment.fromJson(Map<String, dynamic> json) {
    const states = {
      'manual_review_required', 'control_day_future_preview',
      'control_day_today_preview',
    };
    const reasonsAllowed = {
      'life_case_needs_review', 'no_notice_before_cutoff',
      'informational_cutoff_reached',
      'control_date_already_past_no_execution_evidence',
    };
    final rawReasons = json['reasons'];
    final days = json['control_days_before'];
    final rawDay = json['control_day'];
    if (json['assessment_only'] != true ||
        json['answer_recorded'] != false ||
        json['scheduled'] != false || json['delivered'] != false ||
        !states.contains(json['status']) ||
        rawReasons is! List ||
        rawReasons.any((r) => r is! String || !reasonsAllowed.contains(r)) ||
        rawReasons.toSet().length != rawReasons.length ||
        ((json['status'] == 'manual_review_required') !=
            rawReasons.isNotEmpty) ||
        (days != null && (days is! int || days < 0 || days > 365)) ||
        ((rawDay == null) != (days == null)) ||
        json['draft_persisted'] is! bool) {
      throw const FormatException('Invalid control assessment');
    }
    return VenciraControlAssessment(
      status: json['status'] as String,
      reasons: List<String>.unmodifiable(rawReasons.cast<String>()),
      controlDay: rawDay == null ? null : _day(rawDay),
      cutoffOn: _day(json['informational_cutoff_on']),
      controlDaysBefore: days as int?,
      draftPersisted: json['draft_persisted'] as bool,
      c2Policy: json['c2_policy'] is Map<String, dynamic>
          ? VenciraC2Policy.fromJson(json['c2_policy'] as Map<String, dynamic>)
          : null,
    );
  }
}

class VenciraReminderDraft {
  const VenciraReminderDraft({
    required this.daysBefore, required this.revision,
    required this.isPersisted, required this.noPreCutoffNotice,
    required this.lifeRuleRequiresReview, this.reasonsByDay = const {},
  });

  final List<int> daysBefore;
  final Map<String, String> reasonsByDay;
  final int revision;
  final bool isPersisted;
  final bool noPreCutoffNotice;
  final bool lifeRuleRequiresReview;

  factory VenciraReminderDraft.fromJson(Map<String, dynamic> json) {
    final days = json['days_before'];
    final revision = json['revision'];
    final persisted = json['is_persisted'];
    final rawReasons = json['reasons_by_day'] ?? <String, dynamic>{};
    if (json['state'] != 'draft' || days is! List ||
        days.isEmpty || days.length > 12 ||
        days.any((value) => value is! int || value < 0 || value > 365) ||
        days.toSet().length != days.length ||
        revision is! int || revision < 0 ||
        persisted is! bool || (persisted && revision == 0) ||
        (!persisted && revision != 0) ||
        json['scheduling_enabled'] != false ||
        json['delivered'] != false ||
        json['no_pre_cutoff_notice'] is! bool ||
        json['life_rule_requires_review'] is! bool) {
      throw const FormatException('Invalid reminder draft');
    }
    if (rawReasons is! Map<String, dynamic> || rawReasons.entries.any(
      (entry) => !days.contains(int.tryParse(entry.key)) || entry.value is! String)) {
      throw const FormatException('Invalid reasons');
    }
    return VenciraReminderDraft(
      reasonsByDay: Map<String, String>.unmodifiable(rawReasons.cast<String, String>()),
      daysBefore: List<int>.unmodifiable(days.cast<int>()),
      revision: revision,
      isPersisted: persisted,
      noPreCutoffNotice: json['no_pre_cutoff_notice'] as bool,
      lifeRuleRequiresReview: json['life_rule_requires_review'] as bool,
    );
  }
}

class VenciraResultsSummary {
  const VenciraResultsSummary({
    required this.period, required this.won, required this.declined,
    required this.discarded, required this.pending,
  });

  final String period;
  final int won;
  final int declined;
  final int discarded;
  final int pending;

  factory VenciraResultsSummary.fromJson(Map<String, dynamic> json) {
    final period = json['period'];
    final keys = [json['won'], json['declined'], json['discarded'], json['pending']];
    if (!const ['month','quarter','year'].contains(period) ||
        keys.any((x) => x is! int || x < 0) ||
        json['from'] is! String || json['to_exclusive'] is! String) {
      throw const FormatException('Invalid results summary');
    }
    return VenciraResultsSummary(
      period: period as String,
      won: json['won'] as int,
      declined: json['declined'] as int,
      discarded: json['discarded'] as int,
      pending: json['pending'] as int,
    );
  }
}

class VenciraFollowUp {
  const VenciraFollowUp({required this.id, required this.scheduledFor});
  final String id;
  final DateTime scheduledFor;

  factory VenciraFollowUp.fromJson(Map<String, dynamic> json) {
    final id = json['id'], day = json['scheduled_for'];
    if (id is! String ||
        !RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
                r'[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$').hasMatch(id) ||
        day is! String || day.length != 10) {
      throw const FormatException('Invalid manual follow-up');
    }
    final parsed = DateTime.parse(day);
    if (_civilDayIso(parsed) != day || json['state'] != 'planned') {
      throw const FormatException('Invalid follow-up state/date');
    }
    return VenciraFollowUp(id: id, scheduledFor: parsed);
  }
}

class VenciraRenewalInput {
  const VenciraRenewalInput({
    required this.reference,
    required this.expiresOn,
    this.noticeDeadlineOn,
    this.status = 'pending',
    this.entry,
    this.modality = '',
    this.insurerId,
    this.fullName = '',
    this.nickname = '',
    this.phone = '',
    this.email = '',
    this.policyNumber = '',
    this.notes = '',
  });

  final String reference;
  final String? entry;
  final String modality;
  final String? insurerId;
  final String fullName;
  final String nickname;
  final String phone;
  final String email;
  final String policyNumber;
  final String notes;
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
        if (entry != null) 'entry': entry,
        'modality': modality.trim(),
        'insurer': insurerId,
        'full_name': fullName.trim(),
        'nickname': nickname.trim(),
        'phone': phone.trim(),
        'email': email.trim(),
        'policy_number': policyNumber.trim(),
        'notes': notes.trim(),
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

class VenciraHistoryEvent {
  const VenciraHistoryEvent({
    required this.action, required this.timestamp, required this.fields,
    this.actor, required this.metadata,
  });
  final String action;
  final DateTime timestamp;
  final String? actor;
  final List<String> fields;
  final Map<String, dynamic> metadata;

  factory VenciraHistoryEvent.fromJson(Map<String, dynamic> json) {
    final action = json['action'];
    if (action != 'created' && action != 'updated') {
      throw const FormatException('Unknown audit action');
    }
    final fields = (json['changed_fields'] as List<dynamic>)
        .map((v) => v as String).toList(growable: false);
    return VenciraHistoryEvent(
      action: action as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      actor: json['actor'] as String?,
      fields: fields,
      metadata: json['metadata'] as Map<String, dynamic>,
    );
  }
}

class VenciraHistoryPage {
  const VenciraHistoryPage({
    required this.total, required this.events, required this.hasNext,
  });
  final int total;
  final List<VenciraHistoryEvent> events;
  final bool hasNext;
  factory VenciraHistoryPage.fromJson(Map<String, dynamic> json) {
    return VenciraHistoryPage(
      total: json['count'] as int,
      events: (json['results'] as List<dynamic>)
          .map((e) => VenciraHistoryEvent.fromJson(e as Map<String, dynamic>))
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
    if (kind != 'expiry' && kind != 'notice_deadline' &&
        kind != 'reminder' && kind != 'follow_up') {
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
    required this.notice, required this.reminder, this.followUp = const VenciraMonthCounts(pending: 0, contacted: 0)});
  final DateTime day;
  final VenciraMonthCounts expiry;
  final VenciraMonthCounts notice;
  final VenciraMonthCounts reminder;
  final VenciraMonthCounts followUp;
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
      followUp: json['follow_up'] == null
        ? const VenciraMonthCounts(pending: 0, contacted: 0)
        : VenciraMonthCounts.fromJson(
            json['follow_up'] as Map<String, dynamic>),
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
          day.expiry.total + day.notice.total +
          day.reminder.total + day.followUp.total == 0) {
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

class VenciraControlResponse {
  const VenciraControlResponse({required this.id, required this.revision,
    required this.answer, this.yesOption, this.repeatOn,
    required this.answeredAt});
  final String id;
  final int revision;
  final String answer;
  final String? yesOption;
  final DateTime? repeatOn;
  final DateTime answeredAt;

  factory VenciraControlResponse.fromJson(Map<String, dynamic> json) {
    if (json['origin'] != 'manual' || json['notice_scheduled'] is! bool ||
        json['notice_delivered'] != false || json['id'] is! String ||
        json['revision'] is! int || json['revision'] < 1 ||
        !const ['yes', 'no'].contains(json['answer']) ||
        json['answered_at'] is! String) {
      throw const FormatException('Invalid manual control response');
    }
    final option = json['yes_option'];
    final repeat = json['repeat_on'];
    if (option != null && option is! String || repeat != null && repeat is! String) {
      throw const FormatException('Invalid control choices');
    }
    return VenciraControlResponse(
      id: json['id'] as String, revision: json['revision'] as int,
      answer: json['answer'] as String, yesOption: option as String?,
      repeatOn: repeat == null ? null : DateTime.parse(repeat as String),
      answeredAt: DateTime.parse(json['answered_at'] as String),
    );
  }
}

class VenciraOperationalReminder {
  const VenciraOperationalReminder({
    required this.id, required this.state, required this.day,
    required this.reason, required this.controlQuestion});
  final String id, state, reason;
  final DateTime day;
  final bool controlQuestion;

  factory VenciraOperationalReminder.fromJson(Map<String, dynamic> raw) {
    if (raw['id'] is! String || raw['state'] is! String ||
        raw['scheduled_for'] is! String || raw['reason'] is! String ||
        raw['control_question'] is! bool ||
        raw['delivery_status'] != 'not_implemented') {
      throw const FormatException('Invalid internal reminder');
    }
    return VenciraOperationalReminder(
      id: raw['id'] as String, state: raw['state'] as String,
      day: DateTime.parse(raw['scheduled_for'] as String),
      reason: raw['reason'] as String,
      controlQuestion: raw['control_question'] as bool,
    );
  }
}

class VenciraInboxItem {
  const VenciraInboxItem({required this.renewalId,
    required this.reference, required this.reminder, required this.overdue});
  final String renewalId, reference;
  final VenciraOperationalReminder reminder;
  final bool overdue;

  factory VenciraInboxItem.fromJson(Map<String, dynamic> raw) {
    if (raw['renewal_id'] is! String || raw['reference'] is! String ||
        raw['overdue'] is! bool) {
      throw const FormatException('Invalid inbox item');
    }
    return VenciraInboxItem(
      renewalId: raw['renewal_id'] as String,
      reference: raw['reference'] as String,
      reminder: VenciraOperationalReminder.fromJson(raw),
      overdue: raw['overdue'] as bool,
    );
  }
}


class VenciraOperationalEvent {
  const VenciraOperationalEvent({
    required this.id, required this.action, required this.previousState,
    required this.nextState, required this.scheduledFor,
    required this.occurredAt, this.actor,
  });

  final String id, action, previousState, nextState;
  final DateTime scheduledFor, occurredAt;
  final String? actor;

  factory VenciraOperationalEvent.fromJson(Map<String, dynamic> raw) {
    const actions = {'planned', 'cancelled', 'complete',
      'tomorrow', 'another_day'};
    const states = {'', 'planned', 'pending', 'snoozed',
      'completed', 'cancelled'};
    final id = raw['id'], action = raw['action'];
    final previousState = raw['previous_state'];
    final nextState = raw['next_state'], actor = raw['actor'];
    final dayText = raw['scheduled_for'], dateText = raw['occurred_at'];
    if (id is! String ||
        !RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$').hasMatch(id) ||
        action is! String || !actions.contains(action) ||
        previousState is! String || !states.contains(previousState) ||
        nextState is! String || !states.contains(nextState) ||
        dayText is! String || dateText is! String ||
        (actor != null && (actor is! String || actor.length > 150))) {
      throw const FormatException('Invalid operational event');
    }
    final day = DateTime.parse(dayText);
    if (_civilDayIso(day) != dayText) {
      throw const FormatException('Invalid event civil date');
    }
    final timestamp = DateTime.parse(dateText);
    return VenciraOperationalEvent(
      id: id, action: action, previousState: previousState,
      nextState: nextState, scheduledFor: day,
      occurredAt: timestamp, actor: actor as String?,
    );
  }
}

class VenciraOperationalHistory {
  const VenciraOperationalHistory({
    required this.count, required this.hasNext, required this.items,
  });
  final int count;
  final bool hasNext;
  final List<VenciraOperationalEvent> items;

  factory VenciraOperationalHistory.fromJson(Map<String, dynamic> raw) {
    final count = raw['count'], results = raw['results'];
    if (count is! int || count < 0 || results is! List ||
        raw['delivery_status'] != 'not_implemented' ||
        (raw['next'] != null && raw['next'] is! String)) {
      throw const FormatException('Invalid operational history');
    }
    final events = results.map((value) =>
      VenciraOperationalEvent.fromJson(value as Map<String, dynamic>)
    ).toList(growable: false);
    if (events.length > count) {
      throw const FormatException('Invalid event count');
    }
    return VenciraOperationalHistory(
      count: count, hasNext: raw['next'] != null, items: events);
  }
}

class VenciraOperationalInbox {
  const VenciraOperationalInbox({required this.day, required this.scope,
    required this.overdue, required this.today, required this.upcoming,
    required this.items, required this.hasNext});
  final DateTime day;
  final String scope;
  final int overdue, today, upcoming;
  final List<VenciraInboxItem> items;
  final bool hasNext;

  factory VenciraOperationalInbox.fromJson(Map<String, dynamic> raw) {
    final dateText = raw['day'];
    final counts = raw['counts'];
    if (dateText is! String || counts is! Map<String, dynamic> ||
        raw['scope'] is! String || raw['results'] is! List) {
      throw const FormatException('Invalid inbox');
    }
    final date = DateTime.parse(dateText);
    if (dateText != _civilDayIso(date)) {
      throw const FormatException('Invalid inbox day');
    }
    final overdue = counts['overdue'], today = counts['today'],
      upcoming = counts['upcoming'];
    if (overdue is! int || today is! int || upcoming is! int ||
        overdue < 0 || today < 0 || upcoming < 0) {
      throw const FormatException('Invalid inbox counters');
    }
    return VenciraOperationalInbox(
      day: date, scope: raw['scope'] as String,
      overdue: overdue, today: today, upcoming: upcoming,
      hasNext: raw['next'] != null,
      items: (raw['results'] as List).map((value) =>
          VenciraInboxItem.fromJson(value as Map<String, dynamic>))
          .toList(growable: false),
    );
  }
}

class HttpVenciraApi implements VenciraApi {
  @override
  Future<VenciraOperationalInbox> fetchOperationalInbox(String workspaceId,
      DateTime day, {String scope = 'due', int page = 1}) async {
    if (!_validUuid(workspaceId) || day.year < 2000 || day.year > 2100 ||
        !const ['due','today','overdue','upcoming'].contains(scope) || page < 1) {
      throw const VenciraApiException();
    }
    final path = Uri(path: '/api/v1/workspaces/$workspaceId/operational-inbox/',
      queryParameters: {'day': _civilDayIso(day), 'scope': scope, 'page': '$page'})
      .toString();
    try {
      final result = VenciraOperationalInbox.fromJson(
          await _fetch(path) as Map<String, dynamic>);
      if (_civilDayIso(result.day) != _civilDayIso(day) ||
          result.scope != scope) {
        throw const VenciraApiException();
      }
      return result;
    } on VenciraUnauthorized { rethrow; }
    catch (_) { throw const VenciraApiException(); }
  }

  @override
  Future<VenciraOperationalHistory> fetchOperationalHistory(
      String workspaceId, String renewalId, String reminderId,
      {int page = 1}) async {
    if (!_validUuid(reminderId) || page < 1 || page > 100000) {
      throw const VenciraApiException();
    }
    final root = _operationalPath(workspaceId, renewalId);
    final path = Uri(
      path: '${root}operational-reminders/$reminderId/history/',
      queryParameters: {'page': '$page'},
    ).toString();
    try {
      return VenciraOperationalHistory.fromJson(
        await _fetch(path) as Map<String, dynamic>);
    } on VenciraUnauthorized { rethrow; }
    catch (_) { throw const VenciraApiException(); }
  }

  String _operationalPath(String ws, String renewal) {
    if (!_validUuid(ws) || !_validUuid(renewal)) {
      throw const VenciraApiException();
    }
    return '/api/v1/workspaces/$ws/renewals/$renewal/';
  }

  @override
  Future<List<VenciraOperationalReminder>> fetchOperationalReminders(
      String workspaceId, String renewalId) async {
    try {
      final json = await _fetch(
          '${_operationalPath(workspaceId, renewalId)}operational-reminders/')
          as Map<String, dynamic>;
      return (json['results'] as List<dynamic>).map((item) =>
          VenciraOperationalReminder.fromJson(
              item as Map<String, dynamic>)).toList();
    } on VenciraUnauthorized { rethrow; }
    catch (_) { throw const VenciraApiException(); }
  }

  @override
  Future<int> activateOperationalReminders(
      String workspaceId, String renewalId, int expectedRevision) async {
    final path = '${_operationalPath(workspaceId, renewalId)}reminder-activate/';
    final csrf = await _csrf();
    late http.Response response;
    try {
      response = await _client.post(_baseUri.resolve(path), headers: {
        'Accept':'application/json', 'Content-Type':'application/json',
        'X-CSRFToken':csrf,
      }, body:jsonEncode({'expected_revision':expectedRevision}));
    } catch (_) { throw const VenciraApiException(); }
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const VenciraUnauthorized();
    }
    if (response.statusCode == 409) throw const VenciraConflictException();
    if (response.statusCode != 200) throw const VenciraApiException();
    try {
      return (jsonDecode(utf8.decode(response.bodyBytes))
          as Map<String, dynamic>)['planned_count'] as int;
    } catch (_) { throw const VenciraApiException(); }
  }

  @override
  Future<VenciraOperationalReminder> updateOperationalReminder(
      String workspaceId, String renewalId, VenciraOperationalReminder reminder,
      String action, String idempotencyKey, {int? daysLater}) async {
    if (!_validUuid(reminder.id)) throw const VenciraApiException();
    final path = '${_operationalPath(workspaceId, renewalId)}operational-reminders/${reminder.id}/action/';
    final csrf = await _csrf();
    late http.Response response;
    try {
      response = await _client.post(_baseUri.resolve(path), headers: {
        'Accept':'application/json', 'Content-Type':'application/json',
        'X-CSRFToken':csrf,
      }, body:jsonEncode({
        'action':action, 'expected_state':reminder.state,
        'expected_day':_civilDayIso(reminder.day),
        'days_later':daysLater, 'idempotency_key':idempotencyKey,
      }));
    } catch (_) { throw const VenciraApiException(); }
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const VenciraUnauthorized();
    }
    if (response.statusCode == 409) throw const VenciraConflictException();
    if (response.statusCode != 200) throw const VenciraApiException();
    try {
      final raw = jsonDecode(utf8.decode(response.bodyBytes))
          as Map<String, dynamic>;
      return VenciraOperationalReminder(
        id: raw['id'] as String, state: raw['state'] as String,
        day: DateTime.parse(raw['scheduled_for'] as String),
        reason: reminder.reason, controlQuestion:reminder.controlQuestion);
    } catch (_) { throw const VenciraApiException(); }
  }


  String _controlPath(String ws, String id) {
    if (!_validUuid(ws) || !_validUuid(id)) {
      throw const VenciraApiException();
    }
    return '/api/v1/workspaces/$ws/renewals/$id/control-responses/';
  }

  @override
  Future<List<VenciraControlResponse>> fetchControlResponses(
      String workspaceId, String renewalId) async {
    try {
      final json = await _fetch(_controlPath(workspaceId, renewalId))
          as Map<String, dynamic>;
      final items = json['results'] as List<dynamic>;
      return items.map((v) => VenciraControlResponse.fromJson(
          v as Map<String, dynamic>)).toList(growable: false);
    } on VenciraUnauthorized { rethrow; }
    catch (_) { throw const VenciraApiException(); }
  }

  @override
  Future<VenciraControlResponse> saveControlResponse(
      String workspaceId, String renewalId, {
      required int revision, required String idempotencyKey,
      required String answer, String? yesOption, int? daysLater,
  }) async {
    final path = _controlPath(workspaceId, renewalId);
    if (revision < 0 || revision > 2147483646 ||
        !const ['yes', 'no'].contains(answer) ||
        (answer == 'yes' && (daysLater != null ||
            !const ['notified_by_client', 'insurer_not_renewing',
                    'notified_by_mediator'].contains(yesOption))) ||
        (answer == 'no' && (yesOption != null ||
            daysLater == null || daysLater < 1))) {
      throw const VenciraApiException();
    }
    final csrf = await _csrf();
    late http.Response response;
    try {
      response = await _client.post(_baseUri.resolve(path), headers: {
        'Accept':'application/json', 'Content-Type':'application/json',
        'X-CSRFToken':csrf,
      }, body:jsonEncode({
        'origin':'manual', 'revision':revision,
        'idempotency_key':idempotencyKey, 'answer':answer,
        'yes_option':yesOption, 'days_later':daysLater,
      }));
    } catch (_) { throw const VenciraApiException(); }
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const VenciraUnauthorized();
    }
    if (response.statusCode == 409) {
      throw const VenciraConflictException();
    }
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw const VenciraApiException();
    }
    try {
      return VenciraControlResponse.fromJson(
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>);
    } catch (_) { throw const VenciraApiException(); }
  }

  @override
  Future<void> createExplicitControl(
      String workspaceId, String renewalId, {
      required DateTime day, required String idempotencyKey,
  }) async {
    if (!_validUuid(workspaceId) || !_validUuid(renewalId) ||
        !_validUuid(idempotencyKey)) {
      throw const VenciraApiException();
    }
    final dateText = day.toIso8601String().substring(0, 10);
    final csrf = await _csrf();
    late http.Response response;
    try {
      response = await _client.post(
        _baseUri.resolve(
          '/api/v1/workspaces/$workspaceId/renewals/$renewalId/explicit-control/'),
        headers: {
          'Accept': 'application/json', 'Content-Type': 'application/json',
          'X-CSRFToken': csrf,
        },
        body: jsonEncode({
          'confirmed': true, 'scheduled_for': dateText,
          'idempotency_key': idempotencyKey,
        }),
      );
    } catch (_) { throw const VenciraApiException(); }
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const VenciraUnauthorized();
    }
    if (response.statusCode == 409) {
      throw const VenciraConflictException();
    }
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw const VenciraApiException();
    }
    try {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (data is! Map<String, dynamic> ||
          data['control_question'] != true ||
          data['delivery_status'] != 'not_implemented' ||
          data['scheduled_for'] != dateText ||
          data['id'] is! String) {
        throw const FormatException('Invalid explicit control response');
      }
    } catch (_) { throw const VenciraApiException(); }
  }

  @override
  Future<VenciraControlAssessment> fetchControlAssessment(
      String workspaceId, String renewalId) async {
    if (!_validUuid(workspaceId) || !_validUuid(renewalId)) {
      throw const VenciraApiException();
    }
    try {
      final payload = await _fetch(
        '/api/v1/workspaces/$workspaceId/renewals/$renewalId/control-assessment/',
      );
      return VenciraControlAssessment.fromJson(
        payload as Map<String, dynamic>);
    } on VenciraUnauthorized {
      rethrow;
    } catch (_) {
      throw const VenciraApiException();
    }
  }

  String _draftPath(String workspaceId, String renewalId) {
    if (!_validUuid(workspaceId) || !_validUuid(renewalId)) {
      throw const VenciraApiException();
    }
    return '/api/v1/workspaces/$workspaceId/renewals/$renewalId/reminder-config/';
  }

  @override
  Future<VenciraReminderDraft> fetchReminderDraft(
      String workspaceId, String renewalId) async {
    try {
      final path = _draftPath(workspaceId, renewalId);
      final payload = await _fetch(path);
      return VenciraReminderDraft.fromJson(payload as Map<String, dynamic>);
    } on VenciraUnauthorized {
      rethrow;
    } catch (_) {
      throw const VenciraApiException();
    }
  }

  @override
  Future<VenciraReminderDraft> saveReminderDraft(
      String workspaceId, String renewalId,
      {required int revision, required List<int> daysBefore,
       Map<String, String>? reasonsByDay}) async {
    final path = _draftPath(workspaceId, renewalId);
    if (revision < 0 || daysBefore.isEmpty || daysBefore.length > 12 ||
        daysBefore.any((n) => n < 0 || n > 365) ||
        daysBefore.toSet().length != daysBefore.length) {
      throw const VenciraApiException();
    }
    final csrf = await _csrf();
    late http.Response response;
    try {
      response = await _client.put(_baseUri.resolve(path), headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'X-CSRFToken': csrf,
      }, body: jsonEncode({
        'state': 'draft',
        'revision': revision,
        'days_before': daysBefore,
        if (reasonsByDay != null) 'reasons_by_day': reasonsByDay,
      }));
    } catch (_) {
      throw const VenciraApiException();
    }
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const VenciraUnauthorized();
    }
    if (response.statusCode == 409) {
      throw const VenciraConflictException();
    }
    if (response.statusCode != 200) {
      throw const VenciraApiException();
    }
    try {
      return VenciraReminderDraft.fromJson(
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>);
    } catch (_) {
      throw const VenciraApiException();
    }
  }

  @override
  Future<VenciraReminderPreview> fetchReminderPreview(
      String workspaceId, String renewalId, {List<int>? daysBefore}) async {
    if (!_validUuid(workspaceId) || !_validUuid(renewalId) ||
        (daysBefore != null &&
          (daysBefore.isEmpty || daysBefore.length > 12 ||
           daysBefore.any((days) => days < 0 || days > 365) ||
           daysBefore.toSet().length != daysBefore.length))) {
      throw const VenciraApiException();
    }
    final url = Uri(
      path: '/api/v1/workspaces/$workspaceId/renewals/$renewalId/reminder-preview/',
      queryParameters: {
        if (daysBefore != null) 'days': daysBefore.join(','),
      },
    );
    try {
      final raw = await _fetch(url.toString());
      return VenciraReminderPreview.fromJson(raw as Map<String, dynamic>);
    } on VenciraUnauthorized {
      rethrow;
    } catch (_) {
      throw const VenciraApiException();
    }
  }

  @override
  Future<VenciraResultsSummary> fetchResults(
      String workspaceId, {required String period, required int year,
      int? month, int? quarter}) async {
    if (!_validUuid(workspaceId) || year < 2000 || year > 2100 ||
        !const ['month', 'quarter', 'year'].contains(period) ||
        (period == 'month' && (month == null || month < 1 || month > 12 || quarter != null)) ||
        (period == 'quarter' && (quarter == null || quarter < 1 || quarter > 4 || month != null)) ||
        (period == 'year' && (month != null || quarter != null))) {
      throw const VenciraApiException();
    }
    final uri = Uri(
      path: '/api/v1/workspaces/$workspaceId/results/',
      queryParameters: {
        'period': period, 'year': '$year',
        if (period == 'month') 'month': '$month',
        if (period == 'quarter') 'quarter': '$quarter',
      },
    );
    try {
      final data = await _fetch(uri.toString()) as Map<String, dynamic>;
      final summary = VenciraResultsSummary.fromJson(data);
      if (summary.period != period) throw const VenciraApiException();
      return summary;
    } on VenciraUnauthorized {
      rethrow;
    } catch (_) {
      throw const VenciraApiException();
    }
  }
  @override
  Future<List<VenciraPersonSuggestion>> suggestPeople(
      String workspaceId, String query, {String by = 'name', String? excludeId}) async {
    final q = query.trim();
    if (!_validUuid(workspaceId) || q.length < 3 || q.length > 160 ||
        !const ['name', 'phone'].contains(by) ||
        (excludeId != null && !_validUuid(excludeId))) {
      throw const VenciraApiException();
    }
    final uri = Uri(
      path: '/api/v1/workspaces/$workspaceId/renewals/suggestions/',
      queryParameters: {
        'by': by, 'q': q,
        if (excludeId != null) 'exclude': excludeId,
      },
    );
    try {
      final raw = await _fetch(uri.toString()) as List<dynamic>;
      return raw.map((item) => VenciraPersonSuggestion.fromJson(
        item as Map<String, dynamic>)).toList(growable: false);
    } on VenciraUnauthorized {
      rethrow;
    } catch (_) {
      throw const VenciraApiException();
    }
  }


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

  @override
  Future<List<VenciraModalityOption>> fetchModalities(String workspaceId) async {
    if (!_validUuid(workspaceId)) throw const VenciraApiException();
    try {
      final payload = await _fetch('/api/v1/workspaces/$workspaceId/modalities/')
          as List<dynamic>;
      return payload.map((v) =>
          VenciraModalityOption.fromJson(v as Map<String, dynamic>)).toList();
    } on VenciraUnauthorized { rethrow; } catch (_) {
      throw const VenciraApiException();
    }
  }

  Future<http.Response> _catalogWrite(String workspaceId, String method,
      {String? code, Map<String, Object>? body}) async {
    if (!_validUuid(workspaceId) ||
        (code != null &&
         !RegExp(r'^[a-z][a-z0-9_-]{0,63}$').hasMatch(code))) {
      throw const VenciraApiException();
    }
    final token = await _csrf();
    final path = '/api/v1/workspaces/$workspaceId/modalities/' +
        (code == null ? '' : '$code/');
    late http.Response response;
    try {
      final req = http.Request(method, _baseUri.resolve(path));
      req.headers.addAll({
        'Accept':'application/json', 'Content-Type':'application/json',
        'X-CSRFToken':token,
      });
      if (body != null) req.body = jsonEncode(body);
      response = await http.Response.fromStream(await _client.send(req));
    } catch (_) {
      throw const VenciraApiException();
    }
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const VenciraUnauthorized();
    }
    final expected = method == 'POST' ? 201 : method == 'DELETE' ? 204 : 200;
    if (response.statusCode != expected) throw const VenciraApiException();
    return response;
  }

  Future<VenciraModalityOption> _catalogResult(Future<http.Response> request) async {
    final res = await request;
    try {
      return VenciraModalityOption.fromJson(
        jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>);
    } catch (_) { throw const VenciraApiException(); }
  }

  @override
  Future<VenciraModalityOption> addModality(String workspaceId, String label) =>
    _catalogResult(_catalogWrite(workspaceId, 'POST', body:{'label':label}));

  @override
  Future<VenciraModalityOption> editModality(
      String workspaceId, String code, String label) =>
    _catalogResult(_catalogWrite(workspaceId, 'PATCH',
      code:code, body:{'label':label}));

  @override
  Future<VenciraModalityOption> enableModality(
      String workspaceId, String code) =>
    _catalogResult(_catalogWrite(workspaceId, 'PATCH',
      code:code, body:{'active':true}));

  @override
  Future<void> removeModality(String workspaceId, String code) async {
    await _catalogWrite(workspaceId, 'DELETE', code:code);
  }

  bool _filtersValid(String entry, String modality) =>
    (entry.isEmpty || const ['clients', 'prospects'].contains(entry)) &&
    (modality.isEmpty ||
      RegExp(r'^[a-z][a-z0-9_-]{0,63}$').hasMatch(modality));

  @override
  Future<VenciraRenewalPage> fetchFilteredRenewals(
      String workspaceId, {int page = 1, String search = '',
      String status = '', String entry = '', String modality = '', String insurer = ''}) async {
    if (!_validUuid(workspaceId) || page < 1 || search.trim().length > 80 ||
        (insurer.isNotEmpty && !_validUuid(insurer)) ||
        !_filtersValid(entry,modality) ||
        (status.isNotEmpty &&
          !const ['pending','contacted','closed'].contains(status))) {
      throw const VenciraApiException();
    }
    final uri = Uri(path:'/api/v1/workspaces/$workspaceId/renewals/',
      queryParameters:{
        'page':'$page', if(search.trim().isNotEmpty)'q':search.trim(),
        if(status.isNotEmpty)'status':status,
        if(entry.isNotEmpty)'entry':entry,
        if(modality.isNotEmpty)'modality':modality,
        if(insurer.isNotEmpty)'insurer':insurer,
      });
    try {
      return VenciraRenewalPage.fromJson(
        await _fetch(uri.toString()) as Map<String,dynamic>);
    } on VenciraUnauthorized { rethrow; } catch (_) {
      throw const VenciraApiException();
    }
  }

  @override
  Future<VenciraAgendaDayPage> fetchFilteredAgendaDay(
      String workspaceId, DateTime day,
      {int page = 1, String entry = '', String modality = '', String insurer = ''}) async {
    if (!_validUuid(workspaceId) || page < 1 ||
        (insurer.isNotEmpty && !_validUuid(insurer)) ||
        !_filtersValid(entry,modality)) {
      throw const VenciraApiException();
    }
    final date = _civilDayIso(day);
    final uri = Uri(path:'/api/v1/workspaces/$workspaceId/agenda/',
      queryParameters:{
        'day':date,'page':'$page',
        if(entry.isNotEmpty)'entry':entry,
        if(modality.isNotEmpty)'modality':modality,
        if(insurer.isNotEmpty)'insurer':insurer,
      });
    try {
      final data = VenciraAgendaDayPage.fromJson(
        await _fetch(uri.toString()) as Map<String,dynamic>);
      if (_civilDayIso(data.day) != date) throw const VenciraApiException();
      return data;
    } on VenciraUnauthorized { rethrow; } catch (_) {
      throw const VenciraApiException();
    }
  }

  @override
  Future<VenciraAgendaMonth> fetchFilteredAgendaMonth(
      String workspaceId, DateTime month,
      {String entry = '', String modality = '', String insurer = ''}) async {
    if (!_validUuid(workspaceId) || month.year < 2000 || month.year > 2100 ||
        (insurer.isNotEmpty && !_validUuid(insurer)) ||
        !_filtersValid(entry,modality)) {
      throw const VenciraApiException();
    }
    final period = _civilDayIso(DateTime(month.year,month.month,1)).substring(0,7);
    final uri = Uri(path:'/api/v1/workspaces/$workspaceId/agenda/month/',
      queryParameters:{
        'month':period,
        if(entry.isNotEmpty)'entry':entry,
        if(modality.isNotEmpty)'modality':modality,
        if(insurer.isNotEmpty)'insurer':insurer,
      });
    try {
      final data = VenciraAgendaMonth.fromJson(
        await _fetch(uri.toString()) as Map<String,dynamic>);
      if (_civilDayIso(data.month).substring(0,7) != period) {
        throw const VenciraApiException();
      }
      return data;
    } on VenciraUnauthorized { rethrow; } catch (_) {
      throw const VenciraApiException();
    }
  }

  @override
  Future<List<VenciraInsurer>> fetchInsurers(
      String workspaceId, {String search = ''}) async {
    if (!_validUuid(workspaceId) || search.length > 80) {
      throw const VenciraApiException();
    }
    final uri = Uri(
      path: '/api/v1/workspaces/$workspaceId/insurers/',
      queryParameters: {if (search.trim().isNotEmpty) 'q': search.trim()},
    );
    try {
      final rows = await _fetch(uri.toString()) as List<dynamic>;
      return rows.map((r) =>
        VenciraInsurer.fromJson(r as Map<String, dynamic>)).toList();
    } on VenciraUnauthorized { rethrow; } catch (_) {
      throw const VenciraApiException();
    }
  }

  Future<http.Response> _insurerWrite(
      String workspaceId, String method,
      {String? insurerId, String? name, bool? active}) async {
    if (!_validUuid(workspaceId) ||
        (insurerId != null && !_validUuid(insurerId))) {
      throw const VenciraApiException();
    }
    final csrf = await _csrf();
    final uri = _baseUri.resolve('/api/v1/workspaces/$workspaceId/insurers/' +
        (insurerId == null ? '' : '$insurerId/'));
    final request = http.Request(method, uri);
    request.headers.addAll({
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'X-CSRFToken': csrf,
    });
    if (name != null) request.body = jsonEncode({'name': name});
    if (active != null) request.body = jsonEncode({'active': active});
    late http.Response response;
    try {
      response = await http.Response.fromStream(await _client.send(request));
    } catch (_) { throw const VenciraApiException(); }
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const VenciraUnauthorized();
    }
    final code = method == 'POST' ? 201 : method == 'DELETE' ? 204 : 200;
    if (response.statusCode != code) throw const VenciraApiException();
    return response;
  }

  Future<VenciraInsurer> _insurerResult(Future<http.Response> request) async {
    final response = await request;
    try {
      return VenciraInsurer.fromJson(
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String,dynamic>);
    } catch (_) { throw const VenciraApiException(); }
  }

  @override
  Future<VenciraInsurer> createInsurer(String workspaceId, String name) =>
      _insurerResult(_insurerWrite(workspaceId, 'POST', name: name));

  @override
  Future<VenciraInsurer> renameInsurer(
      String workspaceId, String id, String name) =>
      _insurerResult(_insurerWrite(workspaceId, 'PATCH',
        insurerId: id, name: name));

  @override
  Future<VenciraInsurer> reactivateInsurer(String workspaceId, String id) =>
      _insurerResult(_insurerWrite(workspaceId, 'PATCH',
        insurerId: id, active: true));

  @override
  Future<void> deactivateInsurer(String workspaceId, String id) async {
    await _insurerWrite(workspaceId, 'DELETE', insurerId: id);
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
  Future<VenciraRenewal> fetchRenewalDetail(
      String workspaceId, String renewalId) async {
    if (!_validUuid(workspaceId) || !_validUuid(renewalId)) {
      throw const VenciraApiException();
    }
    try {
      final json = await _fetch(
        '/api/v1/workspaces/$workspaceId/renewals/$renewalId/',
      ) as Map<String, dynamic>;
      final renewal = VenciraRenewal.fromJson(json);
      if (renewal.id.toLowerCase() != renewalId.toLowerCase()) {
        throw const VenciraApiException();
      }
      return renewal;
    } on VenciraUnauthorized {
      rethrow;
    } catch (_) {
      throw const VenciraApiException();
    }
  }

  @override
  Future<VenciraHistoryPage> fetchRenewalHistory(
      String workspaceId, String renewalId, {int page = 1}) async {
    if (!_validUuid(workspaceId) || !_validUuid(renewalId) || page < 1) {
      throw const VenciraApiException();
    }
    try {
      final path = Uri(
        path: '/api/v1/workspaces/$workspaceId/renewals/$renewalId/history/',
        queryParameters: {'page': '$page'},
      ).toString();
      return VenciraHistoryPage.fromJson(
          await _fetch(path) as Map<String, dynamic>);
    } on VenciraUnauthorized {
      rethrow;
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
  Future<VenciraRenewal> changeRenewalStatus(
      String workspaceId, String renewalId, String status) async {
    if (!_validUuid(workspaceId) || !_validUuid(renewalId) ||
        !const ['pending', 'contacted'].contains(status)) {
      throw const VenciraApiException();
    }

    final csrfToken = await _csrf();
    late http.Response response;
    try {
      response = await _client.patch(
        _baseUri.resolve(
          '/api/v1/workspaces/$workspaceId/renewals/$renewalId/',
        ),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'X-CSRFToken': csrfToken,
        },
        body: jsonEncode({'status': status}),
      );
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
      final updated = VenciraRenewal.fromJson(
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
      );
      if (updated.id.toLowerCase() != renewalId.toLowerCase() ||
          updated.status != status) {
        throw const VenciraApiException();
      }
      return updated;
    } catch (_) {
      throw const VenciraApiException();
    }
  }

  @override
  Future<void> applyOutcome(
    String workspaceId, String renewalId, String kind, {
    DateTime? scheduledFor,
  }) async {
    if (!_validUuid(workspaceId) || !_validUuid(renewalId) ||
        !const ['won', 'declined', 'undecided', 'discarded', 'restored']
            .contains(kind) ||
        (kind == 'undecided') != (scheduledFor != null)) {
      throw const VenciraApiException();
    }
    final csrf = await _csrf();
    final payload = <String, dynamic>{'kind': kind};
    if (scheduledFor != null) {
      payload['scheduled_for'] = _civilDayIso(scheduledFor);
    }
    final path = '/api/v1/workspaces/$workspaceId/renewals/$renewalId/outcomes/';
    late http.Response response;
    try {
      response = await _client.post(_baseUri.resolve(path),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'X-CSRFToken': csrf,
        },
        body: jsonEncode(payload),
      );
    } catch (_) {
      throw const VenciraApiException();
    }
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const VenciraUnauthorized();
    }
    if (response.statusCode != 201) {
      throw const VenciraApiException();
    }
    try {
      final object = jsonDecode(utf8.decode(response.bodyBytes))
          as Map<String, dynamic>;
      final event = object['event'] as Map<String, dynamic>;
      if (event['kind'] != kind || event['id'] is! String) {
        throw const FormatException('Unexpected resolution response');
      }
    } catch (_) {
      throw const VenciraApiException();
    }
  }

  String _manualFollowUpPath(String workspaceId, String renewalId) {
    if (!_validUuid(workspaceId) || !_validUuid(renewalId)) {
      throw const VenciraApiException();
    }
    return '/api/v1/workspaces/$workspaceId/renewals/$renewalId/follow-up/';
  }

  @override
  Future<VenciraFollowUp?> fetchManualFollowUp(
      String workspaceId, String renewalId) async {
    final path = _manualFollowUpPath(workspaceId, renewalId);
    try {
      final json = await _fetch(path) as Map<String, dynamic>;
      final item = json['active'];
      return item == null
          ? null : VenciraFollowUp.fromJson(item as Map<String, dynamic>);
    } on VenciraUnauthorized {
      rethrow;
    } catch (_) {
      throw const VenciraApiException();
    }
  }

  @override
  Future<VenciraFollowUp> scheduleManualFollowUp(
      String workspaceId, String renewalId, DateTime day) async {
    final path = _manualFollowUpPath(workspaceId, renewalId);
    final csrf = await _csrf();
    late http.Response response;
    try {
      response = await _client.post(_baseUri.resolve(path),
        headers: {'Accept': 'application/json',
                  'Content-Type': 'application/json',
                  'X-CSRFToken': csrf},
        body: jsonEncode({'scheduled_for': _civilDayIso(day)}),
      );
    } catch (_) {
      throw const VenciraApiException();
    }
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const VenciraUnauthorized();
    }
    if (response.statusCode != 201 && response.statusCode != 200) {
      throw const VenciraApiException();
    }
    try {
      final json = jsonDecode(utf8.decode(response.bodyBytes))
          as Map<String, dynamic>;
      return VenciraFollowUp.fromJson(json['active'] as Map<String, dynamic>);
    } catch (_) {
      throw const VenciraApiException();
    }
  }

  @override
  Future<void> resolveManualFollowUp(
      String workspaceId, String renewalId, String followUpId,
      String action) async {
    final path = _manualFollowUpPath(workspaceId, renewalId);
    if (!_validUuid(followUpId) ||
        !const ['complete', 'cancel'].contains(action)) {
      throw const VenciraApiException();
    }
    final csrf = await _csrf();
    late http.Response response;
    try {
      response = await _client.patch(_baseUri.resolve(path),
        headers: {'Accept': 'application/json',
                  'Content-Type': 'application/json',
                  'X-CSRFToken': csrf},
        body: jsonEncode({'id': followUpId, 'action': action}),
      );
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
      final json = jsonDecode(utf8.decode(response.bodyBytes))
          as Map<String, dynamic>;
      if (json['active'] != null) throw const VenciraApiException();
    } catch (_) {
      throw const VenciraApiException();
    }
  }

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
