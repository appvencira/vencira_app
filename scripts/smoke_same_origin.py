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

BASE = os.getenv("VENCIRA_WEB_URL", "http://127.0.0.1:18732").rstrip("/")
if BASE not in ("http://127.0.0.1:18732", "http://localhost:18732"):
    raise SystemExit("Este test solo admite el proxy local en el puerto 18732")


def read(opener, path, *, data=None, headers=None):
    request = urllib.request.Request(
        BASE + path,
        data=data,
        headers=headers or {},
        method="POST" if data is not None else "GET",
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
status, login_page = read(client, "/accounts/login/")
assert status == 200 and "csrfmiddlewaretoken" in login_page, "Falta el formulario de acceso"
status, _ = read(client, "/api/v1/workspaces/")
assert status in (401, 403), "La API no bloqueó la sesión anónima"

username = os.getenv("VENCIRA_E2E_USERNAME", "")
password = os.getenv("VENCIRA_E2E_PASSWORD", "")
if bool(username) != bool(password):
    raise SystemExit("Especifica ambas credenciales E2E o ninguna")

if username:
    csrf = next((cookie.value for cookie in jar if cookie.name == "csrftoken"), None)
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
    csrf = next((cookie.value for cookie in jar if cookie.name == "csrftoken"), None)
    assert csrf, "Falta cookie CSRF después del inicio de sesión"
    status, workspaces_raw = read(client, "/api/v1/workspaces/")
    assert status == 200, "No se obtuvo la lista privada de organizaciones"
    workspaces = json.loads(workspaces_raw)
    assert len(workspaces) == 1 and workspaces[0]["name"] == "Equipo E2E", "Organización errónea"
    workspace_id = workspaces[0]["id"]
    status, renewal_raw = read(client, f"/api/v1/workspaces/{workspace_id}/renewals/")
    assert status == 200, "No se obtuvieron vencimientos desde la sesión"
    renewal = json.loads(renewal_raw)
    assert renewal["count"] == 1
    assert renewal["results"][0]["customer_reference"] == "PRUEBA-E2E-001"
    status, _ = read(
        client, "/accounts/logout/",
        data=b"",
        headers={"X-CSRFToken": csrf, "Content-Type": "application/x-www-form-urlencoded"},
    )
    assert status == 200, "Cierre de sesión sin respuesta"
    status, _ = read(client, "/api/v1/workspaces/")
    assert status in (401, 403), "La sesión sigue autenticada después de salir"
    print("OK: mismo origen, login + CSRF, lectura de workspace y vencimiento, logout")
else:
    print("OK: Flutter, proxy Django, login HTML y denegación anónima. Login E2E omitido.")
