import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vencira/api/vencira_api.dart';
import 'package:vencira/main.dart';

class FakeVenciraApi implements VenciraApi {
  FakeVenciraApi({required this.workspaces, required this.pages, this.auth = false});

  final List<VenciraWorkspace> workspaces;
  final Map<String, VenciraRenewalPage> pages;
  final bool auth;
  String lastSearch = '';
  String lastStatus = '';

  @override
  Future<List<VenciraWorkspace>> fetchWorkspaces() async {
    if (auth) throw const VenciraUnauthorized();
    return workspaces;
  }

  @override
  Future<VenciraRenewalPage> fetchRenewals(
      String workspaceId, {int page = 1, String search = '', String status = ''}) async {
    lastSearch = search;
    lastStatus = status;
    return pages[workspaceId]!;
  }

  @override
  Future<void> logout() async {}

  @override
  Future<VenciraRenewal> createRenewal(String workspaceId, VenciraRenewalInput input) async {
    throw UnimplementedError('Las pruebas de consulta no crean datos');
  }

  @override
  Future<VenciraRenewal> updateRenewal(
      String workspaceId, String renewalId, VenciraRenewalInput input) async {
    throw UnimplementedError('Las pruebas de consulta no editan datos');
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  const workspaceA = VenciraWorkspace(
    id: '11111111-1111-4111-8111-111111111111',
    name: 'Correduría de prueba A',
    role: 'owner',
  );
  const workspaceB = VenciraWorkspace(
    id: '22222222-2222-4222-8222-222222222222',
    name: 'Correduría de prueba B',
    role: 'member',
  );

  testWidgets('respeta el tema claro y oscuro del sistema', (tester) async {
    final api = FakeVenciraApi(
      workspaces: [workspaceA],
      pages: {
        workspaceA.id: const VenciraRenewalPage(
          total: 0, items: [], hasNext: false,
        ),
      },
    );
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await tester.pumpWidget(VenciraApp(api: api));
    await tester.pumpAndSettle();
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.system);
    expect(app.darkTheme, isNotNull);
    expect(Theme.of(tester.element(find.text('VENCIRA'))).brightness,
        Brightness.dark);
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    // Emular la notificación del sistema además del cambio de valor simulado.
    tester.binding.handlePlatformBrightnessChanged();
    await tester.pumpAndSettle();
    expect(Theme.of(tester.element(find.text('VENCIRA'))).brightness,
        Brightness.light);
  });

  testWidgets('selector cambia idioma y tema sin recargar datos', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final api = FakeVenciraApi(
      workspaces: [workspaceA],
      pages: {
        workspaceA.id: const VenciraRenewalPage(
          total: 0, items: [], hasNext: false,
        ),
      },
    );
    await tester.pumpWidget(VenciraApp(api: api));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Preferencias'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Català').last);
    await tester.pumpAndSettle();
    final appInCatalan = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(appInCatalan.locale?.languageCode, 'ca');
    expect(find.text('Anticipa cada venciment'), findsOneWidget);
    await tester.tap(find.byTooltip('Preferències'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fosc').last);
    await tester.pumpAndSettle();
    final appInDark = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(appInDark.themeMode, ThemeMode.dark);
    final saved = await SharedPreferences.getInstance();
    expect(saved.getString('vencira.ui.locale.v1'), 'ca');
    expect(saved.getString('vencira.ui.theme.v1'), 'dark');
  });

  testWidgets('envía filtros al backend y puede limpiarlos', (tester) async {
    final api = FakeVenciraApi(
      workspaces: [workspaceA],
      pages: {workspaceA.id: const VenciraRenewalPage(
          total: 0, items: [], hasNext: false)},
    );
    await tester.pumpWidget(VenciraApp(api: api));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'CASA DEMO');
    await tester.tap(find.text('Buscar'));
    await tester.pumpAndSettle();
    expect(api.lastSearch, 'CASA DEMO');
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Contactado').last);
    await tester.pumpAndSettle();
    expect(api.lastStatus, 'contacted');
    await tester.tap(find.text('Limpiar filtros'));
    await tester.pumpAndSettle();
    expect(api.lastSearch, '');
    expect(api.lastStatus, '');
  });

  testWidgets('permite abrir y cancelar el editor sin modificar datos', (tester) async {
    await tester.pumpWidget(VenciraApp(
      api: FakeVenciraApi(
        workspaces: [workspaceA],
        pages: {
          workspaceA.id: const VenciraRenewalPage(
              total: 0, items: [], hasNext: false),
        },
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Añadir vencimiento'));
    await tester.pumpAndSettle();
    expect(find.text('Nuevo vencimiento'), findsOneWidget);
    expect(find.text('Referencia'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(find.text('Nuevo vencimiento'), findsNothing);
  });

  testWidgets('logout limpia los vencimientos de pantalla', (tester) async {
    await tester.pumpWidget(VenciraApp(
      api: FakeVenciraApi(
        workspaces: [workspaceA],
        pages: {
          workspaceA.id: VenciraRenewalPage(
            total: 1,
            hasNext: false,
            items: [
              VenciraRenewal(
                id: 'b2222222-2222-4222-8222-222222222222',
                reference: 'NO-DEBE-QUEDAR-VISIBLE',
                expiresOn: DateTime(2027, 5, 1),
                status: 'pending',
              ),
            ],
          ),
        },
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('NO-DEBE-QUEDAR-VISIBLE'), findsOneWidget);
    await tester.tap(find.text('Salir'));
    await tester.pumpAndSettle();
    expect(find.text('NO-DEBE-QUEDAR-VISIBLE'), findsNothing);
    expect(find.textContaining('Necesitas iniciar sesión'), findsOneWidget);
  });

  testWidgets('muestra estado vacío sin datos reales', (tester) async {
    await tester.pumpWidget(VenciraApp(
      api: FakeVenciraApi(
        workspaces: [workspaceA],
        pages: {workspaceA.id: const VenciraRenewalPage(total: 0, items: [], hasNext: false)},
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('VENCIRA'), findsOneWidget);
    expect(find.text('Aún no hay vencimientos en esta página.'), findsOneWidget);
  });

  testWidgets('expone por separado vencimiento y límite de preaviso', (tester) async {
    await tester.pumpWidget(VenciraApp(
      api: FakeVenciraApi(
        workspaces: [workspaceA],
        pages: {
          workspaceA.id: VenciraRenewalPage(
            total: 1,
            hasNext: false,
            items: [
              VenciraRenewal(
                id: 'b2222222-2222-4222-8222-222222222222',
                reference: 'CASO-DEMO',
                expiresOn: DateTime(2027, 5, 1),
                noticeDeadlineOn: DateTime(2027, 3, 31),
                status: 'pending',
              ),
            ],
          ),
        },
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Vence el 01/05/2027'), findsOneWidget);
    expect(find.text('Límite de preaviso: 31/03/2027'), findsOneWidget);
  });

  testWidgets('muestra estado de autenticación obligatoria', (tester) async {
    await tester.pumpWidget(VenciraApp(
      api: FakeVenciraApi(workspaces: [], pages: {}, auth: true),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('Necesitas iniciar sesión'), findsOneWidget);
    expect(find.text('Correduría de prueba A'), findsNothing);
  });

  testWidgets('solo muestra vencimientos del workspace seleccionado', (tester) async {
    final pages = {
      workspaceA.id: VenciraRenewalPage(
        total: 1,
        hasNext: false,
        items: [
          VenciraRenewal(
            id: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
            reference: 'REFERENCIA-A',
            expiresOn: DateTime(2027, 4, 10),
            status: 'pending',
          ),
        ],
      ),
      workspaceB.id: VenciraRenewalPage(
        total: 1,
        hasNext: false,
        items: [
          VenciraRenewal(
            id: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
            reference: 'REFERENCIA-B',
            expiresOn: DateTime(2027, 5, 10),
            status: 'contacted',
          ),
        ],
      ),
    };

    await tester.pumpWidget(VenciraApp(
      api: FakeVenciraApi(workspaces: [workspaceA, workspaceB], pages: pages),
    ));
    await tester.pumpAndSettle();
    expect(find.text('REFERENCIA-A'), findsOneWidget);
    expect(find.text('REFERENCIA-B'), findsNothing);

    await tester.tap(find.byType(DropdownButtonFormField<VenciraWorkspace>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(workspaceB.name).last);
    await tester.pumpAndSettle();

    expect(find.text('REFERENCIA-A'), findsNothing);
    expect(find.text('REFERENCIA-B'), findsOneWidget);
  });
}
