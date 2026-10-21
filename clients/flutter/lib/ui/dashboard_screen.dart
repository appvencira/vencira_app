import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/link.dart';

import '../api/vencira_api.dart';
import 'renewal_editor.dart';

class VenciraDashboardScreen extends StatefulWidget {
  const VenciraDashboardScreen({super.key, this.api});

  final VenciraApi? api;

  @override
  State<VenciraDashboardScreen> createState() => _VenciraDashboardScreenState();
}

class _VenciraDashboardScreenState extends State<VenciraDashboardScreen> {
  late final VenciraApi _api;
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
        const SnackBar(content: Text('Vencimiento guardado correctamente.')),
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
        const SnackBar(content: Text('No se pudo guardar. Revisa los datos e inténtalo otra vez.')),
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
        const SnackBar(content: Text('No se pudo cerrar la sesión.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('VENCIRA'),
        actions: [
          if (_selected != null)
            TextButton.icon(
              onPressed: _saving ? null : _logout,
              icon: const Icon(Icons.logout),
              label: const Text('Salir'),
            ),
          IconButton(
            tooltip: 'Actualizar',
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
                    'Anticipa cada vencimiento',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text('Anticipamos vencimientos. Creamos oportunidades.'),
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
                            const Text('No se han podido cargar los datos.'),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: _selected == null
                                  ? () => _loadWorkspaces()
                                  : () => _loadRenewals(_page),
                              child: const Text('Reintentar'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (!_loadingWorkspaces && !_unauthorized && !_failed)
                    ..._workspaceContent(colors),
                  const SizedBox(height: 20),
                  Text(
                    'Versión de desarrollo. No introducir información real de clientes.',
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
            const Text('Necesitas iniciar sesión para acceder a VENCIRA.'),
            const SizedBox(height: 12),
            if (kIsWeb)
              Link(
                uri: Uri.base.resolve('/accounts/login/?next=/'),
                target: LinkTarget.self,
                builder: (context, followLink) => FilledButton(
                  onPressed: followLink,
                  child: const Text('Iniciar sesión'),
                ),
              )
            else
              const Text(
                'El acceso desde aplicaciones móviles está pendiente de implementación.',
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _workspaceContent(ColorScheme colors) {
    if (_workspaces.isEmpty) {
      return [
        const Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('Todavía no perteneces a ninguna organización.'),
          ),
        ),
      ];
    }
    return [
      DropdownButtonFormField<VenciraWorkspace>(
        key: ValueKey(_selected?.id),
        initialValue: _selected,
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
          labelText: 'Organización',
        ),
        items: _workspaces
            .map(
              (workspace) => DropdownMenuItem(
                value: workspace,
                child: Text(workspace.name),
              ),
            )
            .toList(),
        onChanged: _loadingRenewals || _saving ? null : _selectWorkspace,
      ),
      const SizedBox(height: 18),
      Align(
        alignment: Alignment.centerLeft,
        child: FilledButton.icon(
          onPressed: _loadingRenewals || _saving ? null : () => _editRenewal(),
          icon: const Icon(Icons.add),
          label: const Text('Añadir vencimiento'),
        ),
      ),
      const SizedBox(height: 18),
      Wrap(
        spacing: 12,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 295,
            child: TextField(
              controller: _searchController,
              maxLength: 80,
              enabled: !_loadingRenewals && !_saving,
              onSubmitted: (_) => _applySearch(),
              decoration: const InputDecoration(
                labelText: 'Buscar referencia',
                hintText: 'Ej. DEMO-HOGAR',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                counterText: '',
              ),
            ),
          ),
          SizedBox(
            width: 195,
            child: DropdownButtonFormField<String>(
              key: ValueKey('status:${_selected?.id}:$_statusFilter'),
              initialValue: _statusFilter,
              decoration: const InputDecoration(
                labelText: 'Estado',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: '', child: Text('Todos')),
                DropdownMenuItem(value: 'pending', child: Text('Pendiente')),
                DropdownMenuItem(value: 'contacted', child: Text('Contactado')),
                DropdownMenuItem(value: 'closed', child: Text('Cerrado')),
              ],
              onChanged: _loadingRenewals || _saving ? null : _changeStatus,
            ),
          ),
          FilledButton.tonalIcon(
            onPressed: _loadingRenewals || _saving ? null : _applySearch,
            icon: const Icon(Icons.search),
            label: const Text('Buscar'),
          ),
          TextButton(
            onPressed: _loadingRenewals || _saving ? null : _clearFilters,
            child: const Text('Limpiar filtros'),
          ),
        ],
      ),
      const SizedBox(height: 18),
      if (!_loadingRenewals && _renewals != null) ...[
        Text(
          'Vencimientos: $_totalLabel',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 10),
        if (_renewals!.items.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(_appliedSearch.isNotEmpty || _statusFilter.isNotEmpty
                  ? 'No hay vencimientos que coincidan con los filtros.'
                  : 'Aún no hay vencimientos en esta página.'),
            ),
          )
        else
          ..._renewals!.items.map((item) => _renewalTile(item, colors)),
        const SizedBox(height: 12),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: _page > 1 ? () => _loadRenewals(_page - 1) : null,
              icon: const Icon(Icons.chevron_left),
              label: const Text('Anterior'),
            ),
            const SizedBox(width: 14),
            Text('Página $_page'),
            const SizedBox(width: 14),
            OutlinedButton.icon(
              onPressed: _renewals!.hasNext
                  ? () => _loadRenewals(_page + 1)
                  : null,
              icon: const Icon(Icons.chevron_right),
              label: const Text('Siguiente'),
            ),
          ],
        ),
      ],
    ];
  }

  String get _totalLabel => _renewals?.total.toString() ?? '0';

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  Widget _renewalTile(VenciraRenewal item, ColorScheme colors) {
    final expiration = _formatDate(item.expiresOn);
    final notice = item.noticeDeadlineOn == null
        ? null
        : _formatDate(item.noticeDeadlineOn!);
    final label = switch (item.status) {
      'pending' => 'Pendiente',
      'contacted' => 'Contactado',
      'closed' => 'Cerrado',
      _ => 'Sin clasificar',
    };
    return Card(
      child: ListTile(
        leading: Icon(Icons.event_available_outlined, color: colors.primary),
        title: Text(item.reference),
        subtitle: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Vence el $expiration'),
            if (notice != null) Text('Límite de preaviso: $notice'),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Chip(label: Text(label)),
            IconButton(
              tooltip: 'Editar vencimiento',
              onPressed: _saving ? null : () => _editRenewal(item),
              icon: const Icon(Icons.edit_outlined),
            ),
          ],
        ),
      ),
    );
  }
}
