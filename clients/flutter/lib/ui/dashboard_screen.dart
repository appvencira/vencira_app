import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/link.dart';

import '../api/vencira_api.dart';
import '../l10n/app_localizations.dart';
import 'vencira_pagination_bar.dart';
import 'vencira_preferences.dart';
import 'renewal_editor.dart';
import 'renewal_detail_screen.dart';
import 'renewal_archive_screen.dart';
import 'results_screen.dart';
import 'modality_catalog_screen.dart';
import 'insurer_catalog_screen.dart';
import 'modality_labels.dart';
import 'day_agenda_screen.dart';
import 'operational_inbox_screen.dart';
import 'vencira_select.dart';
import 'mfa_setup_screen.dart';

class VenciraDashboardScreen extends StatefulWidget {
  const VenciraDashboardScreen({
    super.key, this.api, this.openTodayOnLoad = false,
    this.beforeSessionBoundary,
  });

  final VenciraApi? api;
  /// Cancellation-only native alarm barrier before account switch/logout.
  /// Failure aborts the user action rather than discarding encrypted identity.
  final Future<void> Function()? beforeSessionBoundary;
  /// En la aplicación real, tras autenticarse se abre HOY (§5).
  final bool openTodayOnLoad;

  @override
  State<VenciraDashboardScreen> createState() => _VenciraDashboardScreenState();
}

class _VenciraDashboardScreenState extends State<VenciraDashboardScreen> {
  late final VenciraApi _api;
  AppLocalizations get _t => AppLocalizations.of(context)!;
  final TextEditingController _searchController = TextEditingController();
  String _appliedSearch = '';
  String _statusFilter = '';
  String _entryFilter = '';
  String _modalityFilter = '';
  String _insurerFilter = '';
  List<VenciraModalityOption> _modalities = VenciraModalityOption.defaults;
  List<VenciraInsurer> _insurers = [];
  List<VenciraWorkspace> _workspaces = [];
  VenciraWorkspace? _selected;
  VenciraRenewalPage? _renewals;
  bool _loadingWorkspaces = true;
  bool _loadingRenewals = false;
  bool _unauthorized = false;
  bool _failed = false;
  bool _saving = false;
  int _page = 1;
  int _sequence = 0;
  int _sessionGeneration = 0;
  bool _initialTodayOpened = false;
  bool _nativeCleanupFailed = false;

  @override
  void initState() {
    super.initState();
    _api = widget.api ?? HttpVenciraApi();
    _loadWorkspaces();
  }

  @override
  void dispose() {
    _sequence++;
    _searchController.dispose();
    if (_api is HttpVenciraApi && widget.api == null) {
      _api.close();
    }
    super.dispose();
  }

  Future<void> _handleExpiredSession() async {
    if (!mounted) return;
    // Clear customer data and stale requests immediately on authentication
    // failure, even when native OS cancellation subsequently fails.
    setState(() {
      _sequence++;
      _sessionGeneration++;
      _unauthorized = true;
      _selected = null;
      _renewals = null;
      _workspaces = [];
      _modalities = VenciraModalityOption.defaults;
      _insurers = [];
      _loadingWorkspaces = false;
      _loadingRenewals = false;
    });
    try {
      await widget.beforeSessionBoundary?.call();
      if (mounted) setState(() => _nativeCleanupFailed = false);
    } catch (_) {
      // Never claim cleanup succeeded or erase the encrypted alarm journal.
      // Future workspace loading must pass the cleanup barrier again.
      if (mounted) setState(() {
        _nativeCleanupFailed = true;
        _failed = true;
      });
    }
  }

  Future<void> _loadWorkspaces() async {
    if (_nativeCleanupFailed) {
      try {
        await widget.beforeSessionBoundary?.call();
        if (!mounted) return;
        _nativeCleanupFailed = false;
      } catch (_) {
        if (mounted) setState(() => _failed = true);
        return;
      }
    }
    final sequence = ++_sequence;
    // En una recarga manual conservar la organización y sus resultados.
    // Sólo se descartan si el servidor confirma cambio de pertenencia.
    setState(() {
      _loadingWorkspaces = true;
      _loadingRenewals = false;
      _unauthorized = false;
      _failed = false;
    });

    try {
      final loaded = await _api.fetchWorkspaces();
      if (!mounted || sequence != _sequence) return;
      // Membership can disappear while the app is open. Automatic selection
      // of a different workspace must also revoke the previous OS alarms;
      // otherwise a user could receive notifications from a lost workspace.
      final previousId = _selected?.id;
      final retained = loaded.any((w) => w.id == previousId);
      if (previousId != null && !retained) {
        try {
          await widget.beforeSessionBoundary?.call();
        } catch (_) {
          if (!mounted || sequence != _sequence) return;
          setState(() {
            _nativeCleanupFailed = true;
            _failed = true;
            _loadingWorkspaces = false;
            _loadingRenewals = false;
            _selected = null;
            _renewals = null;
            _workspaces = [];
            _modalities = VenciraModalityOption.defaults;
            _insurers = [];
            _sequence++;
            _sessionGeneration++;
          });
          return;
        }
        if (!mounted || sequence != _sequence) return;
      }
      setState(() {
        _workspaces = loaded;
        final previouslySelected = _selected?.id;
        final preserved = loaded.where((w) => w.id == previouslySelected);
        _selected = preserved.isNotEmpty
            ? preserved.first : (loaded.isEmpty ? null : loaded.first);
        if (_selected?.id != previouslySelected) {
          _sessionGeneration++;
          _renewals = null;
          _searchController.clear();
          _appliedSearch = '';
          _statusFilter = '';
          _entryFilter = '';
          _modalityFilter = '';
          _insurerFilter = '';
          _modalities = VenciraModalityOption.defaults;
          _insurers = [];
        }
        _loadingWorkspaces = false;
      });
      if (loaded.isNotEmpty) {
        // No bloquear la primera carga del listado por el catálogo.
        await _loadRenewals(1);
        _loadModalities();
        _loadInsurers();
        // Abrir HOY una sola vez al autenticar, sin forzar una cuenta
        // arbitraria si el usuario pertenece a varias organizaciones.
        if (mounted && widget.openTodayOnLoad && !_initialTodayOpened &&
            loaded.length == 1 && !_unauthorized && !_failed) {
          _initialTodayOpened = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _selected?.id == loaded.first.id) _openAgenda();
          });
        }
      }
    } on VenciraUnauthorized {
      if (!mounted || sequence != _sequence) return;
      await _handleExpiredSession();
    } catch (_) {
      if (!mounted || sequence != _sequence) return;
      setState(() {
        _loadingWorkspaces = false;
        _failed = true;
      });
    }
  }

  Future<void> _selectWorkspace(VenciraWorkspace? workspace) async {
    if (workspace == null || _saving) return;
    if (workspace.id != _selected?.id && widget.beforeSessionBoundary != null) {
      setState(() => _saving = true);
      try {
        await widget.beforeSessionBoundary!();
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_t.saveError)),
          );
        }
        return;
      } finally {
        if (mounted) setState(() => _saving = false);
      }
      if (!mounted) return;
    }
    setState(() {
      _sessionGeneration++;
      _sequence++;
      _selected = workspace;
      _renewals = null;
      _page = 1;
      _searchController.clear();
      _appliedSearch = '';
      _statusFilter = '';
      _entryFilter = '';
      _modalityFilter = '';
      _insurerFilter = '';
      _modalities = VenciraModalityOption.defaults;
      _insurers = [];
    });
    await _loadRenewals(1);
    _loadModalities();
    _loadInsurers();
    if (mounted && widget.openTodayOnLoad && !_initialTodayOpened &&
        !_failed && !_unauthorized) {
      _initialTodayOpened = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _selected?.id == workspace.id) _openAgenda();
      });
    }
  }

  Future<void> _loadRenewals(int page) async {
    final selected = _selected;
    if (selected == null) return;
    final sequence = ++_sequence;
    setState(() {
      _page = page;
      // Resultados conservados mientras refresca el MISMO workspace.
      _loadingRenewals = true;
      _failed = false;
      _unauthorized = false;
    });

    try {
      final result = await _api.fetchFilteredRenewals(
        selected.id, page: page, search: _appliedSearch,
        status: _statusFilter, entry: _entryFilter, modality: _modalityFilter,
        insurer: _insurerFilter);
      if (!mounted || sequence != _sequence) return;
      setState(() {
        _renewals = result;
        _loadingRenewals = false;
      });
    } on VenciraUnauthorized {
      if (!mounted || sequence != _sequence) return;
      await _handleExpiredSession();
    } catch (_) {
      if (!mounted || sequence != _sequence) return;
      setState(() {
        _loadingRenewals = false;
        _failed = true;
      });
    }
  }

  Future<void> _loadModalities() async {
    final selected = _selected;
    if (selected == null || _unauthorized || _nativeCleanupFailed) return;
    final generation = _sessionGeneration;
    try {
      final result = await _api.fetchModalities(selected.id);
      if (!mounted || _selected?.id != selected.id ||
          generation != _sessionGeneration || _unauthorized ||
          _nativeCleanupFailed) return;
      setState(() => _modalities = result);
    } on VenciraUnauthorized {
      if (mounted && _selected?.id == selected.id &&
          generation == _sessionGeneration && !_unauthorized &&
          !_nativeCleanupFailed) {
        await _handleExpiredSession();
      }
    } catch (_) {
      // La página de catálogo informa del fallo y permite reintentar.
    }
  }

  Future<void> _loadInsurers() async {
    final workspace = _selected;
    if (workspace == null || _unauthorized || _nativeCleanupFailed) return;
    final generation = _sessionGeneration;
    try {
      final results = await _api.fetchInsurers(workspace.id);
      if (!mounted || _selected?.id != workspace.id ||
          generation != _sessionGeneration || _unauthorized ||
          _nativeCleanupFailed) return;
      setState(() => _insurers = results);
    } on VenciraUnauthorized {
      if (mounted && _selected?.id == workspace.id &&
          generation == _sessionGeneration && !_unauthorized &&
          !_nativeCleanupFailed) {
        await _handleExpiredSession();
      }
    } catch (_) {
      // No mostrar resultados de otra cuenta si falla una recarga.
      if (mounted && _selected?.id == workspace.id) {
        setState(() => _insurers = []);
      }
    }
  }

  Future<void> _openInsurers() async {
    final workspace = _selected;
    if (workspace == null) return;
    await Navigator.of(context).push<void>(MaterialPageRoute(
      builder: (_) => VenciraInsurerCatalogScreen(
        api: _api, workspace: workspace,
      ),
    ));
    if (!mounted || _selected?.id != workspace.id) return;
    await _loadInsurers();
    await _loadRenewals(1);
  }

  Future<void> _openCatalog() async {
    final selected = _selected;
    if (selected == null) return;
    await Navigator.of(context).push<void>(MaterialPageRoute(
      builder: (_) => VenciraModalityCatalogScreen(
        api: _api, workspace: selected,
      ),
    ));
    if (!mounted || _selected?.id != selected.id) return;
    await _loadModalities();
    await _loadRenewals(1);
  }

  void _changeEntry(String? value) {
    if (value == null || _saving) return;
    setState(() => _entryFilter = value);
    _loadRenewals(1);
  }

  void _changeModality(String? value) {
    if (value == null || _saving) return;
    setState(() => _modalityFilter = value);
    _loadRenewals(1);
  }

  void _changeInsurer(String? id) {
    if (id == null || _saving) return;
    setState(() => _insurerFilter = id);
    _loadRenewals(1);
  }

  void _applySearch() {
    if (_saving) return;
    final value = _searchController.text.trim();
    if (value.length > 80) return;
    setState(() => _appliedSearch = value);
    _loadRenewals(1);
  }

  void _changeStatus(String? value) {
    if (value == null || _saving) return;
    setState(() => _statusFilter = value);
    _loadRenewals(1);
  }

  void _clearFilters() {
    if (_saving) return;
    setState(() {
      _searchController.clear();
      _appliedSearch = '';
      _statusFilter = '';
      _entryFilter = '';
      _modalityFilter = '';
      _insurerFilter = '';
    });
    _loadRenewals(1);
  }

  Future<void> _editRenewal([VenciraRenewal? current]) async {
    final selected = _selected;
    if (selected == null || _saving || (current != null && _loadingRenewals)) return;
    final input = await showDialog<VenciraRenewalInput>(
      context: context,
      builder: (_) => VenciraRenewalEditor(
        existing: current, modalities: _modalities, insurers: _insurers,
        api: _api, workspaceId: selected.id),
    );
    if (input == null || !mounted || _selected?.id != selected.id) return;
    setState(() => _saving = true);
    try {
      if (current == null) {
        await _api.createRenewal(selected.id, input);
      } else {
        await _api.updateRenewal(selected.id, current.id, input);
      }
      if (!mounted || _selected?.id != selected.id) return;
      if (current == null) {
        // Tras una creación quitar filtros para que el nuevo registro no quede oculto.
        setState(() {
          _searchController.clear();
          _appliedSearch = '';
          _statusFilter = '';
        });
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t.saved)),
      );
      await _loadRenewals(1);
    } on VenciraUnauthorized {
      if (!mounted) return;
      await _handleExpiredSession();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t.saveError)),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _logout() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      // Never terminate the authenticated session while native alarms
      // remain recoverable only under the current encrypted account scope.
      await widget.beforeSessionBoundary?.call();
      if (!mounted) return;
      await _api.logout();
      if (!mounted) return;
      setState(() {
        _sequence++;
        _sessionGeneration++;
        _selected = null;
        _workspaces = [];
        _renewals = null;
        _modalities = VenciraModalityOption.defaults;
        _insurers = [];
        _unauthorized = true;
        _failed = false;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t.logoutError)),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _clearLocalDeviceNotices() async {
    final cleanup = widget.beforeSessionBoundary;
    if (_saving || cleanup == null) return;
    setState(() => _saving = true);
    final ca = Localizations.localeOf(context).languageCode == 'ca';
    try {
      await cleanup();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ca
            ? 'S’han cancel·lat els avisos locals del dispositiu.'
            : 'Se han cancelado los avisos locales del dispositivo.'),
      ));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ca
            ? 'No s’han pogut cancel·lar els avisos locals. Torna-ho a provar.'
            : 'No se han podido cancelar los avisos locales. Reinténtalo.'),
      ));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Ajustes agrupados y táctiles, sin menú emergente Material de pantalla
  /// completa. Accesibles también en escritorio y con textos localizados.
  Future<void> _openSettingsSheet() async {
    final t = AppLocalizations.of(context)!;
    final preferences = VenciraPreferences.of(context);
    final colors = Theme.of(context).colorScheme;

    Widget option(String title, IconData icon, bool selected,
        VoidCallback onTap) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Material(
          color: selected ? colors.primaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
              child: Row(children: [
                Icon(icon, size: 20, color: selected
                    ? colors.onPrimaryContainer : colors.onSurfaceVariant),
                const SizedBox(width: 13),
                Expanded(child: Text(title,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                    color: selected ? colors.onPrimaryContainer
                        : colors.onSurface))),
                if (selected) Icon(Icons.check_circle_rounded,
                  color: colors.primary, size: 21),
              ]),
            ),
          ),
        ),
      );
    }

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: colors.surfaceContainerLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (sheetContext) => Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 520,
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.78,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.settings,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700)),
                const SizedBox(height: 18),
                Text(t.language, style: Theme.of(context).textTheme.labelLarge
                    ?.copyWith(color: colors.primary)),
                const SizedBox(height: 6),
                option(t.spanish, Icons.translate_rounded,
                  preferences.locale.languageCode == 'es', () {
                  Navigator.of(sheetContext).pop();
                  preferences.setLocale(const Locale('es'));
                }),
                option(t.catalan, Icons.translate_rounded,
                  preferences.locale.languageCode == 'ca', () {
                  Navigator.of(sheetContext).pop();
                  preferences.setLocale(const Locale('ca'));
                }),
                if (_selected != null) ...[
                  const SizedBox(height: 17),
                  Text(preferences.locale.languageCode == 'ca'
                    ? 'Seguretat' : 'Seguridad',
                    style: Theme.of(context).textTheme.labelLarge
                      ?.copyWith(color: colors.primary)),
                  const SizedBox(height: 6),
                  // Build flag solo para tests/preview aislados. Nunca activar
                  // sin backend preparado, custodia de claves y release gate.
                  if (const bool.fromEnvironment('VENCIRA_MFA_UI_ENABLED', defaultValue: false))
                    ListTile(
                      key: const ValueKey('settings-mfa-setup'),
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.verified_user_outlined),
                      title: Text(preferences.locale.languageCode == 'ca'
                        ? 'Activar verificació en dos passos'
                        : 'Activar verificación en dos pasos'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        Navigator.of(context).push(MaterialPageRoute<void>(
                          builder: (_) => MfaSetupScreen(api: _api,
                            catalan: preferences.locale.languageCode == 'ca'),
                        ));
                      },
                    ),
                  // This is a meaningful opt-OUT only. No UI action can
                  // enable OS notifications until the release gate is opened.
                  if (!kIsWeb &&
                      defaultTargetPlatform == TargetPlatform.android &&
                      widget.beforeSessionBoundary != null)
                    ListTile(
                      key: const ValueKey('settings-clear-local-notices'),
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.notifications_off_outlined),
                      title: Text(preferences.locale.languageCode == 'ca'
                        ? 'Cancel·lar avisos locals del dispositiu'
                        : 'Cancelar avisos locales del dispositivo'),
                      subtitle: Text(preferences.locale.languageCode == 'ca'
                        ? 'No s’activen nous avisos automàticament.'
                        : 'No se activan nuevos avisos automáticamente.'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _saving ? null : () {
                        Navigator.of(sheetContext).pop();
                        _clearLocalDeviceNotices();
                      },
                    ),
                  ListTile(
                    key: const ValueKey('settings-close-other-sessions'),
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.phonelink_lock_outlined),
                    title: Text(preferences.locale.languageCode == 'ca'
                      ? 'Tancar sessions en altres dispositius'
                      : 'Cerrar sesiones en otros dispositivos'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      _closeOtherSessions();
                    },
                  ),
                ],
                const SizedBox(height: 17),
                Text(t.appearance, style: Theme.of(context).textTheme.labelLarge
                    ?.copyWith(color: colors.primary)),
                const SizedBox(height: 6),
                option(t.system, Icons.brightness_auto_outlined,
                  preferences.themeMode == ThemeMode.system, () {
                  Navigator.of(sheetContext).pop();
                  preferences.setThemeMode(ThemeMode.system);
                }),
                option(t.light, Icons.light_mode_outlined,
                  preferences.themeMode == ThemeMode.light, () {
                  Navigator.of(sheetContext).pop();
                  preferences.setThemeMode(ThemeMode.light);
                }),
                option(t.dark, Icons.dark_mode_outlined,
                  preferences.themeMode == ThemeMode.dark, () {
                  Navigator.of(sheetContext).pop();
                  preferences.setThemeMode(ThemeMode.dark);
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _closeOtherSessions() async {
    final locale = VenciraPreferences.of(context).locale.languageCode;
    final ca = locale == 'ca';
    final controller = TextEditingController();
    final password = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(ca ? 'Tancar altres sessions' : 'Cerrar otras sesiones'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(ca
              ? 'Tancarem les sessions dels altres dispositius. Aquesta sessió continuarà oberta.'
              : 'Cerraremos las sesiones de otros dispositivos. Esta sesión seguirá abierta.'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              obscureText: true,
              enableSuggestions: false,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: ca ? 'Contrasenya actual' : 'Contraseña actual',
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(ca ? 'Cancel·lar' : 'Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: Text(ca ? 'Tancar sessions' : 'Cerrar sesiones'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (!mounted || password == null || password.isEmpty) return;
    try {
      final count = await _api.logoutOtherSessions(password);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ca
          ? 'Sessions tancades: $count. Aquesta sessió continua oberta.'
          : 'Sesiones cerradas: $count. Esta sesión sigue abierta.'),
      ));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ca
          ? 'No s’han pogut tancar les sessions. Comprova la contrasenya.'
          : 'No se han podido cerrar las sesiones. Comprueba la contraseña.'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: const Text('VENCIRA'),
        actions: [
          IconButton(
            tooltip: l10n.settings,
            icon: const Icon(Icons.tune_rounded),
            onPressed: _openSettingsSheet,
          ),
          if (_selected != null)
            IconButton(
              tooltip: _t.logout,
              onPressed: _saving ? null : _logout,
              icon: const Icon(Icons.logout),
            ),
          IconButton(
            tooltip: _t.refresh,
            icon: const Icon(Icons.refresh),
            onPressed: _loadingWorkspaces || _loadingRenewals
                ? null
                : () => _loadWorkspaces(),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 940),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: ListView(
                children: [
                  Text(
                    l10n.headline,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(l10n.tagline,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    )),
                  const SizedBox(height: 22),
                  if (_saving) const LinearProgressIndicator(),
                  if ((_loadingWorkspaces && _selected == null) ||
                       (_loadingRenewals && _renewals == null))
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                  if (_unauthorized) _authenticationNotice(),
                  if (_failed)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            Text(_t.loadError),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: _selected == null
                                  ? () => _loadWorkspaces()
                                  : () => _loadRenewals(_page),
                              child: Text(_t.retry),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if ((_selected != null || !_loadingWorkspaces) &&
                       !_unauthorized && (!_failed || _renewals != null))
                    ..._workspaceContent(colors),
                  const SizedBox(height: 20),
                  Text(
                    _t.developmentWarning,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _authenticationNotice() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppLocalizations.of(context)!.loginRequired),
            const SizedBox(height: 12),
            if (kIsWeb)
              Link(
                uri: Uri.base.resolve('/accounts/login/?next=/'),
                target: LinkTarget.self,
                builder: (context, followLink) => FilledButton(
                  onPressed: followLink,
                  child: Text(_t.login),
                ),
              )
            else
              Text(_t.mobilePending),
          ],
        ),
      ),
    );
  }

  void _openResults() {
    final workspace = _selected;
    // §11: resultados solo web escritorio; acceso de usuarios Equipo
    // sigue pendiente §18, por eso únicamente owner.
    if (!kIsWeb || MediaQuery.sizeOf(context).width < 800 ||
        workspace == null || workspace.role != 'owner' ||
        _saving) return;
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => VenciraResultsScreen(
        api: _api, workspace: workspace,
      ),
    ));
  }

  void _openArchive() {
    final workspace = _selected;
    if (workspace == null || _saving) return;
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => VenciraArchiveScreen(
        api: _api, workspace: workspace,
      ),
    )).then((_) {
      // La recuperacion de una poliza puede cambiar la lista principal.
      if (mounted && _selected?.id == workspace.id) _loadRenewals(1);
    });
  }

  void _openOperationalInbox() {
    final workspace = _selected;
    if (workspace == null || _saving) return;
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => VenciraOperationalInboxScreen(
        api: _api, workspace: workspace),
    ));
  }

  void _openAgenda() {
    final workspace = _selected;
    if (workspace == null) return;
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => VenciraDayAgendaScreen(
        api: _api,
        workspace: workspace,
        initialEntry: _entryFilter,
        initialModality: _modalityFilter,
        initialInsurer: _insurerFilter,
      ),
    ));
  }

  List<Widget> _workspaceContent(ColorScheme colors) {
    if (_workspaces.isEmpty) {
      return [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(_t.noWorkspace),
          ),
        ),
      ];
    }
    return [
      if (_workspaces.length > 1)
        VenciraSelect<VenciraWorkspace>(
          key: const ValueKey('workspace-select'),
          label: _t.workspace,
          value: _selected,
          prefixIcon: Icons.apartment_rounded,
          options: [
            for (final workspace in _workspaces)
              VenciraOption(value: workspace, label: workspace.name),
          ],
          onChanged: _saving
              ? null : _selectWorkspace,
        ),
      if (_workspaces.length == 1)
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(children: [
            Icon(Icons.apartment_rounded, size: 18, color: colors.primary),
            const SizedBox(width: 9),
            Flexible(child: Text(_selected?.name ?? '',
              style: Theme.of(context).textTheme.titleSmall,
              overflow: TextOverflow.ellipsis)),
          ]),
        ),
      const SizedBox(height: 18),
      LayoutBuilder(builder: (context, constraints) {
        final compact = constraints.maxWidth < 600;
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(child: constraints.maxWidth < 340
              ? OutlinedButton(
                  onPressed: _saving || _selected == null
                      ? null : _openAgenda,
                  child: Text(_t.agendaShort, maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                )
              : OutlinedButton.icon(
                  onPressed: _saving || _selected == null
                      ? null : _openAgenda,
                  icon: const Icon(Icons.calendar_month_outlined),
                  label: Text(compact ? _t.agendaShort : _t.agendaOpenDay,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                )),
            const SizedBox(width: 10),
            Expanded(child: constraints.maxWidth < 340
              ? FilledButton(
                  onPressed: _loadingRenewals || _saving
                      ? null : () => _editRenewal(),
                  child: Text(_t.addRenewal.split(' ').first,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                )
              : FilledButton.icon(
                  onPressed: _loadingRenewals || _saving
                      ? null : () => _editRenewal(),
                  icon: const Icon(Icons.add_rounded),
                  label: Text(compact
                      ? _t.addRenewal.split(' ').first : _t.addRenewal,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                )),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: OutlinedButton.icon(
              key: const ValueKey('open-archive'),
              onPressed: _saving || _selected == null
                  ? null : _openArchive,
              icon: const Icon(Icons.inventory_2_outlined, size: 19),
              label: Text(_t.archiveOpen, maxLines: 1,
                overflow: TextOverflow.ellipsis),
            )),
            const SizedBox(width: 10),
            Expanded(child: OutlinedButton.icon(
              key: const ValueKey('open-operational-inbox'),
              onPressed: _saving || _selected == null
                  ? null : _openOperationalInbox,
              icon: const Icon(Icons.notifications_active_outlined, size: 19),
              label: Text(_t.inboxShortcut, maxLines: 1,
                overflow: TextOverflow.ellipsis),
            )),
          ]),
          if (kIsWeb && MediaQuery.sizeOf(context).width >= 800 &&
              _selected?.role == 'owner') ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                key: const ValueKey('open-results'),
                onPressed: _saving ? null : _openResults,
                icon: const Icon(Icons.bar_chart_outlined),
                label: Text(_t.resultsOpen),
              ),
            ),
          ],
          if (_selected?.role == 'owner') ...[
            const SizedBox(height: 8),
            ExpansionTile(
              key: const ValueKey('workspace-tools'),
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 12),
              leading: const Icon(Icons.settings_outlined),
              title: Text(_t.workspaceCatalogHeading,
                style: Theme.of(context).textTheme.bodyMedium),
              children: [
                Row(children: [
                  Expanded(child: _catalogShortcut(
                    key: const ValueKey('open-catalog'),
                    icon: Icons.category_outlined,
                    label: _t.modalityManage,
                    onPressed: _saving ? null : _openCatalog,
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: _catalogShortcut(
                    key: const ValueKey('open-insurers'),
                    icon: Icons.business_outlined,
                    label: _t.insurerManage,
                    onPressed: _saving ? null : _openInsurers,
                  )),
                ]),
              ],
            ),
          ],
        ]);
      }),
      const SizedBox(height: 18),
      if (MediaQuery.sizeOf(context).width < 600)
        ExpansionTile(
          key: const ValueKey('dashboard-filters'),
          tilePadding: EdgeInsets.zero,
          leading: const Icon(Icons.tune_outlined),
          title: Text(_t.search),
          subtitle: Text(_t.searchReference,
            style: Theme.of(context).textTheme.bodySmall),
          childrenPadding: const EdgeInsets.only(bottom: 12),
          children: [_advancedFilterPanel()],
        )
      else
        _advancedFilterPanel(),
      const SizedBox(height: 18),
      // Un espacio fijo de progreso evita reflujo al consultar de nuevo.
      SizedBox(
        height: 3,
        child: _loadingRenewals && _renewals != null
            ? const LinearProgressIndicator() : null,
      ),
      if (_renewals != null) ...[
        Text(
          '${_t.renewals}: $_totalLabel',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 10),
        if (_renewals!.items.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(_appliedSearch.isNotEmpty || _statusFilter.isNotEmpty ||
                   _entryFilter.isNotEmpty || _modalityFilter.isNotEmpty ||
                   _insurerFilter.isNotEmpty
                  ? _t.noFilterMatches
                  : AppLocalizations.of(context)!.emptyPage),
            ),
          )
        else
          ..._renewals!.items.map((item) => _renewalTile(item, colors)),
        const SizedBox(height: 12),
        VenciraPaginationBar(
          pageLabel: '${_t.page} $_page',
          previousLabel: _t.previous,
          nextLabel: _t.next,
          onPrevious: _page > 1 && !_loadingRenewals
              ? () => _loadRenewals(_page - 1) : null,
          onNext: _renewals!.hasNext && !_loadingRenewals
              ? () => _loadRenewals(_page + 1) : null,
        ),
      ],
    ];
  }

  /// Catálogos: dos accesos equilibrados en la misma fila, incluso a 320 px.
  Widget _catalogShortcut({
    required Key key,
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
  }) {
    final colors = Theme.of(context).colorScheme;
    return OutlinedButton(
      key: key,
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 84),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 11),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18)),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 21),
        const SizedBox(height: 6),
        Text(label, maxLines: 2, textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: onPressed == null
              ? colors.onSurfaceVariant : colors.primary,
            fontWeight: FontWeight.w700)),
      ]),
    );
  }

  Widget _advancedFilterPanel() {
    return LayoutBuilder(
        builder: (context, constraints) {
          // No superar el espacio útil tras márgenes y padding de la pantalla.
          final compact = constraints.maxWidth < 600;
          final searchWidth = compact ? constraints.maxWidth : 295.0;
          final statusWidth = compact ? constraints.maxWidth : 240.0;
          return Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
          SizedBox(
            width: searchWidth,
            child: TextField(
              controller: _searchController,
              maxLength: 80,
              enabled: !_saving,
              onSubmitted: (_) => _applySearch(),
              decoration: InputDecoration(
                labelText: _t.searchReference,
                hintText: _t.exampleReference,
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                counterText: '',
              ),
            ),
          ),
          SizedBox(width: statusWidth, child: VenciraSelect<String>(
            key: ValueKey('status:${_selected?.id}:$_statusFilter'),
            label: _t.status, value: _statusFilter,
            prefixIcon: Icons.flag_outlined,
            options: [
              VenciraOption(value: '', label: _t.all),
              VenciraOption(value: 'pending', label: _t.pending,
                icon: Icons.schedule_rounded),
              VenciraOption(value: 'contacted', label: _t.contacted,
                icon: Icons.forum_outlined),
              VenciraOption(value: 'closed', label: _t.closed,
                icon: Icons.check_circle_outline_rounded),
            ],
            onChanged: _saving ? null : _changeStatus,
          )),
          SizedBox(width: statusWidth, child: VenciraSelect<String>(
            key: ValueKey('entry-filter-${_selected?.id}-$_entryFilter'),
            label: _t.entryLabel, value: _entryFilter,
            prefixIcon: Icons.people_outline_rounded,
            options: [
              VenciraOption(value: '', label: _t.all),
              VenciraOption(value: 'clients', label: _t.entryClients),
              VenciraOption(value: 'prospects', label: _t.entryProspects),
            ],
            onChanged: _saving ? null : _changeEntry,
          )),
          SizedBox(width: statusWidth, child: VenciraSelect<String>(
            key: ValueKey('modality-filter-${_selected?.id}-$_modalityFilter'),
            label: _t.modalityLabel, value: _modalityFilter,
            prefixIcon: Icons.category_outlined,
            options: [
              VenciraOption(value: '', label: _t.all),
              for (final option in _modalities)
                if (option.active || option.code == _modalityFilter)
                  VenciraOption(value: option.code,
                    label: modalityCaption(context, option)),
            ],
            onChanged: _saving ? null : _changeModality,
          )),
          SizedBox(width: statusWidth, child: VenciraSelect<String>(
            key: ValueKey('insurer-filter-$_insurerFilter'),
            label: _t.insurerLabel, value: _insurerFilter,
            prefixIcon: Icons.apartment_outlined,
            options: [
              VenciraOption(value: '', label: _t.all),
              for (final insurer in _insurers)
                if (insurer.active || insurer.id == _insurerFilter)
                  VenciraOption(value: insurer.id, label: insurer.name),
              if (_insurerFilter.isNotEmpty &&
                  !_insurers.any((v) => v.id == _insurerFilter))
                VenciraOption(value: _insurerFilter,
                  label: _t.insurerLegacy),
            ],
            onChanged: _saving ? null : _changeInsurer,
          )),
          FilledButton.tonalIcon(
            onPressed: _saving ? null : _applySearch,
            icon: const Icon(Icons.search),
            label: Text(_t.search),
          ),
          TextButton(
            onPressed: _saving ? null : _clearFilters,
            child: Text(_t.clearFilters),
          ),
            ],
          );
        },
      );
  }

  String get _totalLabel => _renewals?.total.toString() ?? '0';

  String _formatDate(DateTime date) {
    return DateFormat(
      'dd/MM/yyyy',
      Localizations.localeOf(context).languageCode,
    ).format(date);
  }

  Future<void> _openDetail(VenciraRenewal item) async {
    final selected = _selected;
    if (selected == null || _saving) return;
    await Navigator.of(context).push<void>(MaterialPageRoute(
      builder: (_) => VenciraRenewalDetailScreen(
        api: _api, workspace: selected, renewalId: item.id,
        onSessionExpired: _handleExpiredSession,
      ),
    ));
    if (mounted && _selected?.id == selected.id) _loadRenewals(1);
  }

  Widget _renewalTile(VenciraRenewal item, ColorScheme colors) {
    final expiration = _formatDate(item.expiresOn);
    final notice = item.noticeDeadlineOn == null
        ? null
        : _formatDate(item.noticeDeadlineOn!);
    final label = switch (item.status) {
      'pending' => _t.pending,
      'contacted' => _t.contacted,
      'closed' => _t.closed,
      _ => _t.unknown,
    };
    final hasName = item.fullName.trim().isNotEmpty;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _openDetail(item),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(Icons.event_note_outlined,
                  size: 21, color: colors.onPrimaryContainer),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(hasName ? item.fullName : item.reference,
                      maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700)),
                    if (hasName) ...[
                      const SizedBox(height: 3),
                      Text(item.reference,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant)),
                    ],
                    const SizedBox(height: 9),
                    Text('${_t.expiresOn} $expiration',
                      style: Theme.of(context).textTheme.bodyMedium),
                    if (notice != null) ...[
                      const SizedBox(height: 3),
                      Text('${_t.noticeLabel}: $notice',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant)),
                    ],
                    const SizedBox(height: 9),
                    Wrap(spacing: 8, runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (item.entry != null)
                          Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.circle, size: 8,
                              color: item.entry == 'clients'
                                  ? colors.primary : colors.tertiary),
                            const SizedBox(width: 4),
                            Text(item.entry == 'clients'
                                ? _t.entryClients : _t.entryProspects,
                              style: Theme.of(context).textTheme.labelSmall),
                          ]),
                        VenciraStatusBadge(
                          status: item.status,
                          label: label,
                        ),
                      ]),
                  ],
                ),
              ),
              IconButton(
                tooltip: _t.editRenewal,
                onPressed: _saving ? null : () => _editRenewal(item),
                icon: const Icon(Icons.edit_outlined, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }

}
