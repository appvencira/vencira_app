#!/usr/bin/env python3
"""I5: Chromium executes the real Flutter Web bundle against disposable I4 HTTPS/PG17.

No production access. Browser TLS uses ignore_https_errors *only* for this local
self-signed CI fixture; I4's separate client verifies its CA and hostname.
"""
import argparse
import json
import os
from pathlib import Path

from playwright.sync_api import sync_playwright

BASE = "https://localhost:18732"


def verify(ok, name):
    if not ok:
        raise AssertionError("I5_BROWSER_" + name + "=FAIL")
    print("I5_BROWSER_" + name + "=OK", flush=True)


def open_flutter(browser, fixture, *, viewport, label, artifacts):
    context = browser.new_context(
        viewport=viewport, ignore_https_errors=True,
        reduced_motion="reduce", locale="es-ES")
    page = context.new_page()
    errors = []
    responses = []
    page.on("pageerror", lambda exc: errors.append(str(exc)))
    page.on("response", lambda response: responses.append(
        (response.url.split("?", 1)[0], response.status)
    ) if "/api/v1/" in response.url else None)

    try:
        # Real Django login form in Chromium: no auth bypass or injected state.
        page.goto(BASE + "/accounts/login/", wait_until="domcontentloaded")
        verify(page.get_by_label("Usuario").count() == 1, label + "_LOGIN_VISIBLE")
        page.get_by_label("Usuario").fill("i4-owner")
        page.get_by_label("Contraseña").fill(os.environ["I4_OWNER_PASSWORD"])
        page.get_by_role("button", name="Entrar en VENCIRA").click()
        page.wait_for_url("**/api/v1/me/", timeout=20000)
        verify('"username": "i4-owner"' in page.locator("body").inner_text()
               or '"username":"i4-owner"' in page.locator("body").inner_text(),
               label + "_LOGIN_HTTPS")
        verify(any(c["name"] == "vencira_sessionid" and c["secure"]
                   for c in context.cookies()), label + "_SECURE_SESSION")

        page.goto(BASE + "/", wait_until="domcontentloaded")
        page.locator("flutter-view").wait_for(state="visible", timeout=60000)
        page.wait_for_function(
            """() => !!document.querySelector('flutter-view')
               && !!document.querySelector('flutter-view canvas, flutter-view flt-glass-pane, flutter-view flutter-scene')""",
            timeout=40000,
        )
        page.wait_for_timeout(3000)
        verify(not errors, label + "_NO_JS_EXCEPTIONS")
        verify(any("/api/v1/workspaces/" in url and status == 200
                   for url, status in responses), label + "_WORKSPACE_FETCH")
        verify(any("/renewals/" in url and status == 200
                   for url, status in responses), label + "_RENEWALS_FETCH")
        image = artifacts / (label.lower() + ".png")
        page.screenshot(path=str(image), full_page=True, animations="disabled")
        verify(image.stat().st_size > 9000, label + "_RENDERED_SCREENSHOT")

        # Authenticated browser must never be shown another tenant's private data.
        response = context.request.get(
            BASE + "/api/v1/workspaces/" + fixture["foreign"] + "/renewals/")
        verify(response.status == 404, label + "_TENANT_FENCE")
        response = context.request.get(
            BASE + "/api/v1/workspaces/" + fixture["workspace"] +
            "/renewals/" + fixture["renewal"] + "/attachments/")
        verify(response.status == 200 and
               not any(response.json()["capabilities"][key]
                       for key in ("upload", "download", "delete")),
               label + "_ATTACHMENTS_LOCKED")

        # Browser-origin CSRF and logout must invalidate the session.
        token = page.evaluate("""async () => {
          const r = await fetch('/api/v1/csrf/', {credentials: 'same-origin'});
          if (!r.ok) throw new Error('csrf failed');
          return (await r.json()).csrfToken;
        }""")
        status = page.evaluate("""async (token) => {
          const body = new URLSearchParams({csrfmiddlewaretoken: token});
          const r = await fetch('/accounts/logout/', {
            method: 'POST', credentials: 'same-origin',
            headers: {'X-CSRFToken': token, 'Content-Type': 'application/x-www-form-urlencoded'},
            body,
          });
          return r.status;
        }""", token)
        verify(status == 200, label + "_LOGOUT")
        verify(context.request.get(BASE + "/api/v1/me/").status in (401, 403),
               label + "_SESSION_REVOKED")
    finally:
        context.close()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--fixture", type=Path, default=Path("/tmp/vencira-i4-fixture.json"))
    parser.add_argument("--artifacts", type=Path, default=Path("/tmp/vencira-i5-screenshots"))
    args = parser.parse_args()
    verify(os.environ.get("I4_DISPOSABLE_DATABASE") == "YES" and
           os.environ.get("POSTGRES_DB") == "vencira_i4_ci" and
           os.environ.get("VENCIRA_ENV") == "test", "DISPOSABLE_ONLY")
    args.artifacts.mkdir(parents=True, exist_ok=True)
    fixture = json.loads(args.fixture.read_text(encoding="utf-8"))
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        try:
            open_flutter(browser, fixture, viewport={"width": 1440, "height": 900},
                         label="DESKTOP", artifacts=args.artifacts)
            open_flutter(browser, fixture, viewport={"width": 390, "height": 844},
                         label="MOBILE_WEB", artifacts=args.artifacts)
        finally:
            browser.close()
    print("I5_REAL_CHROMIUM_FLUTTER=PASS", flush=True)
    print("I5_NO_DEPLOY_NO_LIVE_MIGRATION=1", flush=True)


if __name__ == "__main__":
    main()
