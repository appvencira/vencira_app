import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vencira/api/vencira_api.dart';
import 'package:vencira/main.dart';

class FakeVenciraApi implements VenciraApi {
  FakeVenciraApi({required this.workspaces, required this.pages, this.auth = false});

  final List<VenciraWorkspace> workspaces;
  final Map<String, VenciraRenewalPage> pages;
  final bool auth;

  @override
  Future<List<VenciraWorkspace>> fetchWorkspaces() async {
    if (auth) throw const VenciraUnauthorized();
    return workspaces;
  }

  @override
  Future<VenciraRenewalPage> fetchRenewals(String workspaceId, {int page = 1}) async {
    return pages[workspaceId]!;
  }
}

void main() {
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
