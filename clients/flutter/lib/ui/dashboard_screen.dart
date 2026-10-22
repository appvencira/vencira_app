import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/link.dart';

import '../api/vencira_api.dart';
import '../l10n/app_localizations.dart';
import 'vencira_preferences.dart';
import 'renewal_editor.dart';
import 'day_agenda_screen.dart';

class VenciraDashboardScreen extends StatefulWidget {
  const VenciraDashboardScreen({super.key, this.api});

  final VenciraApi? api;

  @override
  State<VenciraDashboardScreen> createState() => _VenciraDashboardScreenState();
}

class _VenciraDashboardScreenState extends State<VenciraDashboardScreen> {
  late final VenciraApi _api;
  AppLocalizations get _t => AppLocalizations.of(context)!;
  final TextEditingController _searchController = TextEditingController();
  String _appliedSearch = '';
  String _statusFilter = '';
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

  Future<void> _loadWorkspaces() async {
    final sequence = ++_sequence;
    setState(() {
      _loadingWorkspaces = true;
      _loadingRenewals = false;
      _unauthorized = false;
      _failed = false;
      _selected = null;
      _renewals = null;
    });

    try {
      final loaded = await _api.fetchWorkspaces();
      if (!mounted || sequence != _sequence) return;
      setState(() {
        _workspaces = loaded;
        _selected = loaded.isEmpty ? null : loaded.first;
        _loadingWorkspaces = false;
      });
      if (loaded.isNotEmpty) {
        await _loadRenewals(1);
      }
    } on VenciraUnauthorized {
      if (!mounted || sequence != _sequence) return;
      setState(() {
        _loadingWorkspaces = false;
        _unauthorized = true;
      });
    } catch (_) {
      if (!mounted || sequence != _sequence) return;
      setState(() {
        _loadingWorkspaces = false;
        _failed = true;
      });
    }
  }

  Future<void> _selectWorkspace(VenciraWorkspace? workspace) async {
    if (workspace == null) return;
    setState(() {
      _selected = workspace;
      _renewals = null;
      _page = 1;
      _searchController.clear();
      _appliedSearch = '';
      _statusFilter = '';
    });
    await _loadRenewals(1);
  }

  Future<void> _loadRenewals(int page) async {
    final selected = _selected;
    if (selected == null) return;
    final sequence = ++_sequence;
    setState(() {
      _page = page;
      _renewals = null; // Evita mostrar datos de otro workspace mientras carga.
      _loadingRenewals = true;
      _failed = false;
      _unauthorized = false;
    });

    try {
      final result = await _api.fetchRenewals(
        selected.id, page: page, search: _appliedSearch, status: _statusFilter);
      if (!mounted || sequence != _sequence) return;
      setState(() {
        _renewals = result;
        _loadingRenewals = false;
      });
    } on VenciraUnauthorized {
      if (!mounted || sequence != _sequence) return;
      setState(() {
        _loadingRenewals = false;
        _renewals = null;
        _unauthorized = true;
      });
    } catch (_) {
      if (!mounted || sequence != _sequence) return;
      setState(() {
        _loadingRenewals = false;
        _failed = true;
      });
    }
  }

  void _applySearch() {
    if (_loadingRenewals || _saving) return;
    final value = _searchController.text.trim();
    if (value.length > 80) return;
    setState(() => _appliedSearch = value);
    _loadRenewals(1);
  }

  void _changeStatus(String? value) {
    if (value == null || _loadingRenewals || _saving) return;
    setState(() => _statusFilter = value);
    _loadRenewals(1);
  }

  void _clearFilters() {
    if (_loadingRenewals || _saving) return;
    setState(() {
      _searchController.clear();
      _appliedSearch = '';
      _statusFilter = '';
    });
    _loadRenewals(1);
  }

  Future<void> _editRenewal([VenciraRenewal? current]) async {
    final selected = _selected;
    if (selected == null || _saving || _loadingRenewals) return;
    final input = await showDialog<VenciraRenewalInput>(
      context: context,
      builder: (_) => VenciraRenewalEditor(existing: current),
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
      setState(() {
        _unauthorized = true;
        _renewals = null;
      });
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
      await _api.logout();
      if (!mounted) return;
      setState(() {
        _sequence++;
        _selected = null;
        _workspaces = [];
        _renewals = null;
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

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: const Text('VENCIRA'),
        actions: [
          PopupMenuButton<String>(
            tooltip: AppLocalizations.of(context)!.settings,
            icon: const Icon(Icons.tune),
            onSelected: (value) {
              final preferences = VenciraPreferences.of(context);
              switch (value) {
                case 'es':
                case 'ca':
                  preferences.setLocale(Locale(value));
                case 'system':
                  preferences.setThemeMode(ThemeMode.system);
                case 'light':
                  preferences.setThemeMode(ThemeMode.light);
                case 'dark':
                  preferences.setThemeMode(ThemeMode.dark);
              }
            },
            itemBuilder: (context) {
              final l10n = AppLocalizations.of(context)!;
              final settings = VenciraPreferences.of(context);
              return [
                PopupMenuItem<String>(
                  enabled: false,
                  child: Text(l10n.language),
                ),
                CheckedPopupMenuItem<String>(
                  value: 'es',
                  checked: settings.locale.languageCode == 'es',
                  child: Text(l10n.spanish),
                ),
                CheckedPopupMenuItem<String>(
                  value: 'ca',
                  checked: settings.locale.languageCode == 'ca',
                  child: Text(l10n.catalan),
                ),
                const PopupMenuDivider(),
                PopupMenuItem<String>(
                  enabled: false,
                  child: Text(l10n.appearance),
                ),
                CheckedPopupMenuItem<String>(
                  value: 'system',
                  checked: settings.themeMode == ThemeMode.system,
                  child: Text(l10n.system),
                ),
                CheckedPopupMenuItem<String>(
                  value: 'light',
                  checked: settings.themeMode == ThemeMode.light,
                  child: Text(l10n.light),
                ),
                CheckedPopupMenuItem<String>(
                  value: 'dark',
                  checked: settings.themeMode == ThemeMode.dark,
                  child: Text(l10n.dark),
                ),
              ];
            },
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
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(l10n.tagline),
                  const SizedBox(height: 26),
                  if (_saving) const LinearProgressIndicator(),
                  if (_loadingWorkspaces || _loadingRenewals)
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
                  if (!_loadingWorkspaces && !_unauthorized && !_failed)
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
      DropdownButtonFormField<VenciraWorkspace>(
        key: ValueKey(_selected?.id),
        isExpanded: true,
        initialValue: _selected,
        decoration: InputDecoration(
          border: const OutlineInputBorder(),
          labelText: _t.workspace,
        ),
        items: _workspaces
            .map(
              (workspace) => DropdownMenuItem(
                value: workspace,
                child: Text(
                  workspace.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            )
            .toList(),
        onChanged: _loadingRenewals || _saving ? null : _selectWorkspace,
      ),
      const SizedBox(height: 18),
      Wrap(
        spacing: 12,
        runSpacing: 8,
        children: [
          FilledButton.tonalIcon(
            onPressed: _saving || _loadingRenewals || _selected == null
                ? null
                : () => Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => VenciraDayAgendaScreen(
                      api: _api,
                      workspace: _selected!,
                    ),
                  )),
            icon: const Icon(Icons.calendar_today_outlined),
            label: Text(_t.agendaOpenDay),
          ),
          FilledButton.icon(
            onPressed: _loadingRenewals || _saving ? null : () => _editRenewal(),
            icon: const Icon(Icons.add),
            label: Text(_t.addRenewal),
          ),
        ],
      ),
      const SizedBox(height: 18),
      LayoutBuilder(
        builder: (context, constraints) {
          // No superar el espacio útil tras márgenes y padding de la pantalla.
          final searchWidth =
              constraints.maxWidth < 295 ? constraints.maxWidth : 295.0;
          final statusWidth =
              constraints.maxWidth < 240 ? constraints.maxWidth : 240.0;
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
              enabled: !_loadingRenewals && !_saving,
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
          SizedBox(
            width: statusWidth,
            child: DropdownButtonFormField<String>(
              key: ValueKey('status:${_selected?.id}:$_statusFilter'),
              isExpanded: true,
              initialValue: _statusFilter,
              decoration: InputDecoration(
                labelText: _t.status,
                border: const OutlineInputBorder(),
              ),
              items: [
                DropdownMenuItem(value: '', child: Text(_t.all)),
                DropdownMenuItem(value: 'pending', child: Text(_t.pending)),
                DropdownMenuItem(value: 'contacted', child: Text(_t.contacted)),
                DropdownMenuItem(value: 'closed', child: Text(_t.closed)),
              ],
              onChanged: _loadingRenewals || _saving ? null : _changeStatus,
            ),
          ),
          FilledButton.tonalIcon(
            onPressed: _loadingRenewals || _saving ? null : _applySearch,
            icon: const Icon(Icons.search),
            label: Text(_t.search),
          ),
          TextButton(
            onPressed: _loadingRenewals || _saving ? null : _clearFilters,
            child: Text(_t.clearFilters),
          ),
            ],
          );
        },
      ),
      const SizedBox(height: 18),
      if (!_loadingRenewals && _renewals != null) ...[
        Text(
          '${_t.renewals}: $_totalLabel',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 10),
        if (_renewals!.items.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(_appliedSearch.isNotEmpty || _statusFilter.isNotEmpty
                  ? _t.noFilterMatches
                  : AppLocalizations.of(context)!.emptyPage),
            ),
          )
        else
          ..._renewals!.items.map((item) => _renewalTile(item, colors)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: _page > 1 ? () => _loadRenewals(_page - 1) : null,
              icon: const Icon(Icons.chevron_left),
              label: Text(_t.previous),
            ),
            Text('${_t.page} $_page'),
            OutlinedButton.icon(
              onPressed: _renewals!.hasNext
                  ? () => _loadRenewals(_page + 1)
                  : null,
              icon: const Icon(Icons.chevron_right),
              label: Text(_t.next),
            ),
          ],
        ),
      ],
    ];
  }

  String get _totalLabel => _renewals?.total.toString() ?? '0';

  String _formatDate(DateTime date) {
    return DateFormat(
      'dd/MM/yyyy',
      Localizations.localeOf(context).languageCode,
    ).format(date);
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
    return Card(
      child: ListTile(
        leading: Icon(Icons.event_available_outlined, color: colors.primary),
        title: Text(
          item.reference,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${_t.expiresOn} $expiration'),
            if (notice != null) Text('${_t.noticeLabel}: $notice'),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: Chip(
                visualDensity: VisualDensity.compact,
                label: Text(label),
              ),
            ),
          ],
        ),
        trailing: IconButton(
          tooltip: _t.editRenewal,
          onPressed: _saving ? null : () => _editRenewal(item),
          icon: const Icon(Icons.edit_outlined),
        ),
      ),
    );
  }
}
