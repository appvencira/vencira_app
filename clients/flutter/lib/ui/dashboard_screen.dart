import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/link.dart';

import '../api/vencira_api.dart';

class VenciraDashboardScreen extends StatefulWidget {
  const VenciraDashboardScreen({super.key, this.api});

  final VenciraApi? api;

  @override
  State<VenciraDashboardScreen> createState() => _VenciraDashboardScreenState();
}

class _VenciraDashboardScreenState extends State<VenciraDashboardScreen> {
  late final VenciraApi _api;
  List<VenciraWorkspace> _workspaces = [];
  VenciraWorkspace? _selected;
  VenciraRenewalPage? _renewals;
  bool _loadingWorkspaces = true;
  bool _loadingRenewals = false;
  bool _unauthorized = false;
  bool _failed = false;
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
    if (_api is HttpVenciraApi && widget.api == null) {
      (_api as HttpVenciraApi).close();
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
      final result = await _api.fetchRenewals(selected.id, page: page);
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

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('VENCIRA'),
        actions: [
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
                uri: Uri.base.resolve('/accounts/login/'),
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
        onChanged: _loadingRenewals ? null : _selectWorkspace,
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
              child: Text('Aún no hay vencimientos en esta página.'),
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

  Widget _renewalTile(VenciraRenewal item, ColorScheme colors) {
    final date = item.expiresOn;
    final expiration =
        '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
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
        subtitle: Text('Vence el $expiration'),
        trailing: Chip(label: Text(label)),
      ),
    );
  }
}
