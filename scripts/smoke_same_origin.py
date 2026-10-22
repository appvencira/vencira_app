#!/usr/bin/env python3
"""Smoke HTTP local desde un único origen (solo CI/desarrollo).

Sin credenciales: comprueba proxy, HTML, salud y denegación anónima.
Con credenciales de prueba por variables de entorno: verifica login, consulta
de organización y vencimientos y logout. Nunca imprime contraseñas.
"""
import http.cookiejar
import json
import os
import time
import urllib.error
import urllib.parse
import urllib.request

WEB_PORT_RAW = os.getenv("VENCIRA_WEB_BIND_PORT", "18732")
if not WEB_PORT_RAW.isascii() or not WEB_PORT_RAW.isdecimal():
    raise SystemExit("El puerto local debe ser numérico")
WEB_PORT = int(WEB_PORT_RAW)
if not 1024 <= WEB_PORT <= 65535:
    raise SystemExit("Puerto local fuera de rango")
BASE = os.getenv(
    "VENCIRA_WEB_URL", f"http://127.0.0.1:{WEB_PORT}"
).rstrip("/")
if BASE not in (
    f"http://127.0.0.1:{WEB_PORT}",
    f"http://localhost:{WEB_PORT}",
):
    raise SystemExit("Este test solo admite un proxy loopback en el puerto configurado")


def read(opener, path, *, data=None, headers=None, method=None):
    request = urllib.request.Request(
        BASE + path,
        data=data,
        headers=headers or {},
        method=method or ("POST" if data is not None else "GET"),
    )
    try:
        with opener.open(request, timeout=6) as response:
            return response.status, response.read().decode("utf-8")
    except urllib.error.HTTPError as error:
        return error.code, error.read().decode("utf-8")


jar = http.cookiejar.CookieJar()
client = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(jar))

for attempt in range(40):
    try:
        status, health = read(client, "/api/health/")
        if status == 200:
            break
    except (OSError, TimeoutError):
        pass
    time.sleep(2)
else:
    raise SystemExit("La API local no está disponible tras 80 segundos")

assert json.loads(health) == {"status": "ok"}, "Respuesta de salud inesperada"
status, page = read(client, "/")
assert status == 200 and "flutter_bootstrap.js" in page, "No se sirve Flutter web"
assert "serviceWorker.getRegistrations()" in page, "Falta limpieza del service worker antiguo"
assert "flutter_bootstrap.js?v=" in page, "Falta versión fresca del bootstrap"

# Evitar HTML/JS obsoletos con caché persistente; no afecta a cookies de sesión.
for asset in ("/", "/flutter_bootstrap.js?v=cache-test", "/main.dart.js"):
    with client.open(BASE + asset, timeout=8) as response:
        assert response.status == 200, f"Recurso ausente: {asset}"
        assert "no-store" in response.headers.get("Cache-Control", ""), (
            f"Cache-Control inseguro: {asset}"
        )
        if asset.endswith(".js") or ".js?" in asset:
            assert "javascript" in response.headers.get("Content-Type", ""), (
                f"El JS no tiene el tipo MIME correcto: {asset}"
            )
try:
    with client.open(BASE + "/main.dart-no-existe.js", timeout=8) as response:
        raise AssertionError(f"JS inexistente aceptado: HTTP {response.status}")
except urllib.error.HTTPError as error:
    # Un recurso inexistente jamás debe aparentar un JS válido.
    assert error.code in (404, 410)

status, login_page = read(client, "/accounts/login/")
assert status == 200 and "csrfmiddlewaretoken" in login_page, "Falta el formulario de acceso"
status, _ = read(client, "/api/v1/workspaces/")
assert status in (401, 403), "La API no bloqueó la sesión anónima"

username = os.getenv("VENCIRA_E2E_USERNAME", "")
password = os.getenv("VENCIRA_E2E_PASSWORD", "")
if bool(username) != bool(password):
    raise SystemExit("Especifica ambas credenciales E2E o ninguna")

if username:
    csrf = next((cookie.value for cookie in jar if cookie.name == "vencira_csrftoken"), None)
    assert csrf, "No se recibió cookie CSRF"
    payload = urllib.parse.urlencode({
        "username": username,
        "password": password,
        "csrfmiddlewaretoken": csrf,
        "next": "/",
    }).encode("utf-8")
    status, after_login = read(client, "/accounts/login/?next=/", data=payload,
                               headers={"Content-Type": "application/x-www-form-urlencoded"})
    assert status == 200 and "flutter_bootstrap.js" in after_login, "Inicio de sesión fallido"
    # Django rota el secreto CSRF al iniciar sesión; usar el valor nuevo.
    csrf = next((cookie.value for cookie in jar if cookie.name == "vencira_csrftoken"), None)
    assert csrf, "Falta cookie CSRF después del inicio de sesión"
    status, workspaces_raw = read(client, "/api/v1/workspaces/")
    assert status == 200, "No se obtuvo la lista privada de organizaciones"
    workspaces = json.loads(workspaces_raw)
    expected_workspace = os.getenv("VENCIRA_E2E_WORKSPACE", "Equipo E2E")
    expected_count = int(os.getenv("VENCIRA_E2E_COUNT", "1"))
    expected_reference = os.getenv("VENCIRA_E2E_REFERENCE", "PRUEBA-E2E-001")
    assert len(workspaces) == 1 and workspaces[0]["name"] == expected_workspace, "Organización errónea"
    workspace_id = workspaces[0]["id"]
    status, renewal_raw = read(client, f"/api/v1/workspaces/{workspace_id}/renewals/")
    assert status == 200, "No se obtuvieron vencimientos desde la sesión"
    renewal = json.loads(renewal_raw)
    assert renewal["count"] == expected_count
    assert renewal["results"][0]["customer_reference"] == expected_reference

    # Verificar el contrato nuevo de agenda a través del mismo proxy autenticado.
    # Se emplea la fecha ISO del primer vencimiento, sin calcularla desde UTC.
    expiry_day = renewal["results"][0]["expires_on"]
    agenda_path = f"/api/v1/workspaces/{workspace_id}/agenda/?day={expiry_day}"
    status, agenda_raw = read(client, agenda_path)
    assert status == 200, "La agenda diaria no responde por el proxy"
    agenda = json.loads(agenda_raw)
    assert agenda["day"] == expiry_day, "El backend alteró el día civil"
    assert agenda["count"] >= 1, "Falta el vencimiento en la agenda diaria"
    matching = [
        row for row in agenda["results"]
        if row["renewal"]["customer_reference"] == expected_reference
    ]
    assert len(matching) == 1, "La agenda no contiene la anotación de prueba"
    assert any(event["kind"] == "expiry" for event in matching[0]["events"]), (
        "El motivo de vencimiento está ausente"
    )
    # Un límite contractual debe aparecer en su fecha sin ReminderCandidate.
    notice_day = renewal["results"][0].get("notice_deadline_on")
    if notice_day:
        notice_status, notice_raw = read(
            client, f"/api/v1/workspaces/{workspace_id}/agenda/?day={notice_day}"
        )
        assert notice_status == 200, "La agenda no sirve la fecha de preaviso"
        notice_agenda = json.loads(notice_raw)
        assert notice_agenda["day"] == notice_day
        notice_matches = [
            row for row in notice_agenda["results"]
            if row["renewal"]["customer_reference"] == expected_reference
        ]
        assert len(notice_matches) == 1, "El preaviso contractual no aparece"
        assert any(
            event["kind"] == "notice_deadline"
            for event in notice_matches[0]["events"]
        ), "El evento del límite de preaviso está ausente"

    # Calendario mensual: agregación privada sin referencias individuales.
    month = expiry_day[:7]
    month_path = f"/api/v1/workspaces/{workspace_id}/agenda/month/?month={month}"
    month_status, month_raw = read(client, month_path)
    assert month_status == 200, "El resumen mensual no responde"
    month_data = json.loads(month_raw)
    assert month_data["month"] == month
    counts = {row["day"]: row for row in month_data["days"]}
    assert counts[expiry_day]["expiry"]["pending"] >= 1
    if notice_day:
        assert counts[notice_day]["notice_deadline"]["pending"] >= 1
    assert expected_reference not in month_raw, "El resumen filtra referencias de usuarios"
    invalid_month, _ = read(
        client, f"/api/v1/workspaces/{workspace_id}/agenda/month/?month=2027-13"
    )
    assert invalid_month == 400, "La API acepta meses imposibles"

    invalid_day_status, _ = read(
        client, f"/api/v1/workspaces/{workspace_id}/agenda/?day=no-es-una-fecha"
    )
    assert invalid_day_status == 400, "Se aceptó una fecha de agenda inválida"

    # Prueba E2E también de escrituras autenticadas, CSRF y auditoría de API.
    status, token_body = read(client, "/api/v1/csrf/")
    assert status == 200, "No hay endpoint CSRF"
    token = json.loads(token_body)["csrfToken"]
    create_path = f"/api/v1/workspaces/{workspace_id}/renewals/"
    status, created_raw = read(
        client, create_path,
        data=json.dumps({
            "customer_reference": "PRUEBA-E2E-ESCRITURA",
            "expires_on": "2027-05-01",
            "notice_deadline_on": "2027-03-31",
        }).encode("utf-8"),
        headers={"Content-Type": "application/json", "X-CSRFToken": token},
    )
    assert status == 201, f"Alta fallida: {status}"
    created = json.loads(created_raw)
    assert created["notice_deadline_on"] == "2027-03-31"
    status, edited_raw = read(
        client, f"{create_path}{created['id']}/",
        data=json.dumps({"status": "contacted"}).encode("utf-8"),
        headers={"Content-Type": "application/json", "X-CSRFToken": token},
        method="PATCH",
    )
    assert status == 200 and json.loads(edited_raw)["status"] == "contacted"
    # Ficha de la póliza externa y dos eventos de auditoría de alta y cambio.
    detail_path = f"{create_path}{created['id']}/"
    detail_status, detail_raw = read(client, detail_path)
    assert detail_status == 200, "Ficha privada no accesible"
    assert json.loads(detail_raw)["customer_reference"] == "PRUEBA-E2E-ESCRITURA"
    history_path = f"{detail_path}history/"
    history_status, history_raw = read(client, history_path)
    assert history_status == 200, "Historial no accesible"
    history = json.loads(history_raw)
    assert history["count"] == 2, "Historial de alta/cambio incompleto"
    assert {event["action"] for event in history["results"]} == {"created", "updated"}
    assert "PRUEBA-E2E-ESCRITURA" not in history_raw, "Historial almacena referencia personal"
    invalid_history_status, _ = read(
        client, f"/api/v1/workspaces/{workspace_id}/renewals/"
        "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa/history/"
    )
    assert invalid_history_status == 404, "Historial ajeno no se protege"

    status, after_create_raw = read(client, create_path)
    assert status == 200 and json.loads(after_create_raw)["count"] == expected_count + 1
    status, _ = read(
        client, "/accounts/logout/",
        data=b"",
        headers={"X-CSRFToken": csrf, "Content-Type": "application/x-www-form-urlencoded"},
    )
    assert status == 200, "Cierre de sesión sin respuesta"
    status, _ = read(client, "/api/v1/workspaces/")
    assert status in (401, 403), "La sesión sigue autenticada después de salir"
    status, _ = read(client, agenda_path)
    assert status in (401, 403), "La agenda permite consultar datos tras logout"
    status, _ = read(client, month_path)
    assert status in (401, 403), "El mes revela actividad después del logout"
    status, _ = read(client, history_path)
    assert status in (401, 403), "El historial sigue visible después del logout"
    print("OK: origen único, login + CSRF, agenda diaria, escrituras y logout")
else:
    print("OK: Flutter, proxy Django, login HTML y denegación anónima. Login E2E omitido.")
