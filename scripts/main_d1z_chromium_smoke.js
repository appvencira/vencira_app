"use strict";
// D1-Z browser-stage diagnostics: emit only fixed markers/counters, never URLs,
// console messages, cookies, tokens, or response bodies.
const { chromium } = require("playwright");
(async () => {
  let browser;
  let stage = "LAUNCH";
  const errors = [];
  let pageErrors = 0;
  let fontConsoleErrors = 0;
  let otherConsoleErrors = 0;
  let expectedAuthConsoleDenials = 0;
  const expectedAuthDenialConsoleRoutes = new Map();
  const otherConsoleSamples = [];
  const otherConsoleLocationTypes = {};
  const internalHttpErrors = {};
  const internalForbiddenRoutes = {};
  const internalResponseStatusByUrl = new Map();
  function safeRouteClass(path) {
    if (path === "/api/v1/me/") return "AUTH_ME";
    if (path === "/api/v1/workspaces/") return "WORKSPACES";
    if (path === "/api/v1/csrf/") return "CSRF";
    if (path === "/accounts/login/") return "LOGIN";
    if (path === "/api/health/") return "HEALTH";
    if (path.startsWith("/api/v1/")) return "OTHER_API_V1";
    if (path.startsWith("/api/")) return "OTHER_API";
    if (path.startsWith("/accounts/")) return "OTHER_ACCOUNT";
    return "OTHER_INTERNAL";
  }
  const failedRequests = { internal: 0, external: 0 };
  const requestKinds = {};
  const failedHostCategories = {};
  const errorCategories = {};
  const exceptionTypes = {};
  const safeErrorExamples = [];
  function safeExceptionSummary(raw) {
    // Only the first exception line, with URLs, paths, quoted text, long
    // opaque tokens and non-allowlisted punctuation removed.
    return String(raw || "")
      .split("\n")[0]
      .replace(/https?:\/\/[^\s)]+/gi, "[URL]")
      .replace(/(?:[A-Za-z]:)?\/[^\s:)]+/g, "[PATH]")
      .replace(/["'\x60][^"'\x60]*["'\x60]/g, "[STRING]")
      .replace(/\b[A-Za-z0-9+/_=-]{35,}\b/g, "[OPAQUE]")
      .replace(/[^A-Za-z0-9 .,;:!?()_\[\]-]/g, " ")
      .slice(0, 180)
      .trim() || "EMPTY";
  }
  let browserDocumentStatus = "UNKNOWN";
  let sameOriginScriptStatus = "UNKNOWN";
  function tally(target, key) { target[key] = (target[key] || 0) + 1; }
  function externalHostCategory(host) {
    // Known public infrastructure only; unknown domains are not printed.
    if (host === "fonts.googleapis.com" || host === "fonts.gstatic.com") return "GOOGLE_FONTS";
    if (host.endsWith(".gstatic.com")) return "GOOGLE_STATIC";
    if (host.endsWith(".googleapis.com")) return "GOOGLE_API";
    if (host === "www.gstatic.com") return "GOOGLE_STATIC";
    if (host === "unpkg.com" || host === "cdn.jsdelivr.net") return "JS_CDN";
    return "OTHER_EXTERNAL";
  }
  function errorCategory(message) {
    const s = String(message || "").toLowerCase();
    if (s.includes("canvaskit")) return "CANVASKIT";
    if (s.includes("skwasm")) return "SKWASM";
    if (s.includes("font")) return "FONT";
    if (s.includes("webassembly") || s.includes("wasm")) return "WASM";
    if (s.includes("fetch") || s.includes("network")) return "NETWORK";
    if (s.includes("content security policy") || s.includes("csp")) return "CSP";
    if (s.includes("script")) return "SCRIPT";
    if (s.includes("undefined") || s.includes("null")) return "NULL_OR_UNDEFINED";
    if (s.includes("is not a function")) return "NOT_A_FUNCTION";
    if (s.includes("not defined")) return "NOT_DEFINED";
    if (s.includes("unexpected token")) return "INVALID_SCRIPT";
    if (s.includes("failed to load")) return "LOAD_FAILURE";
    if (s.includes("permission")) return "PERMISSION";
    if (s.includes("timeout")) return "TIMEOUT";
    return "OTHER";
  }
  try {
    browser = await chromium.launch({ headless: true, args: ["--no-sandbox", "--lang=es-ES"] });
    console.log("D1Z_CHROMIUM_LAUNCH=PASS");
    stage = "CONTEXT";
    const page = await browser.newPage({
      ignoreHTTPSErrors: true, locale: "es-ES", viewport: { width: 1280, height: 800 }
    });
    const localeCheck = await page.evaluate(() => {
      const language = navigator.language;
      const accepted = language === "es-ES";
      let intl = false;
      try {
        intl = new Intl.DateTimeFormat(language).resolvedOptions().locale === "es-ES";
      } catch (_) { intl = false; }
      return { accepted, intl };
    });
    console.log("D1Z_CHROMIUM_SPANISH_LOCALE=" + (localeCheck.accepted ? "PASS" : "FAIL"));
    console.log("D1Z_CHROMIUM_INTL_DATE_LOCALE=" + (localeCheck.intl ? "PASS" : "FAIL"));
    if (!localeCheck.accepted || !localeCheck.intl) throw Error("INVALID_BROWSER_LOCALE");
    page.on("pageerror", err => {
      errors.push("PAGE_ERROR");
      pageErrors++;
      tally(errorCategories, errorCategory(err && err.message));
      const type = String(err?.name || "UNKNOWN").toUpperCase().replace(/[^A-Z]/g, "").slice(0, 30);
      tally(exceptionTypes, type || "UNKNOWN");
      if (safeErrorExamples.length < 2) safeErrorExamples.push(safeExceptionSummary(err?.message));
    });
    page.on("console", msg => {
      if (msg.type() === "error") {
        errors.push("CONSOLE_ERROR");
        const message = msg.text();
        const location = msg.location()?.url || "";
        const fontOrigin = /^https:\/\/fonts\.(?:googleapis|gstatic)\.com\//i.test(location);
        const mentionsFont = /(?:fonts\.googleapis\.com|fonts\.gstatic\.com|failed to load font)/i.test(message);
        if (fontOrigin || mentionsFont) {
          fontConsoleErrors++;
        } else {
          // A Chromium resource console 403 is expected ONLY if it maps
          // exactly to a recorded anonymous 403 on one of two auth endpoints.
          // Generic "403" messages or unknown routes remain gate failures.
          let expectedAuth403 = false;
          try {
            const loc = new URL(location);
            const expectedPath = loc.pathname === "/api/v1/me/" ||
              loc.pathname === "/api/v1/workspaces/";
            expectedAuth403 = loc.hostname === "d1z-proxy" && expectedPath &&
              internalResponseStatusByUrl.get(loc.href) === 403 &&
              /failed to load resource: the server responded with a status of 403/i.test(message);
            if (expectedAuth403) {
              expectedAuthDenialConsoleRoutes.set(loc.pathname,
                (expectedAuthDenialConsoleRoutes.get(loc.pathname) || 0) + 1);
            }
          } catch (_) { /* denied only if positively verified */ }
          if (expectedAuth403) {
            expectedAuthConsoleDenials++;
            tally(errorCategories, "EXPECTED_AUTH_DENIAL");
            return;
          }
          otherConsoleErrors++;
          if (otherConsoleSamples.length < 3) {
            otherConsoleSamples.push(safeExceptionSummary(message));
          }
          let originClass = "UNKNOWN";
          try {
            const url = new URL(location);
            originClass = url.hostname === "d1z-proxy" ? "INTERNAL" :
              externalHostCategory(url.hostname);
          } catch (_) {}
          tally(otherConsoleLocationTypes, originClass);
        }
        tally(errorCategories, errorCategory(message));
      }
    });
    page.on("response", response => {
      try {
        const loc = new URL(response.url());
        if (loc.hostname !== "d1z-proxy") return;
        if (response.status() >= 400) {
          internalResponseStatusByUrl.set(loc.href, response.status());
          const routeClass = safeRouteClass(loc.pathname);
          tally(internalHttpErrors, String(response.status()));
          if (response.status() === 403) tally(internalForbiddenRoutes, routeClass);
        }
        if (loc.pathname === "/flutter_bootstrap.js") sameOriginScriptStatus = String(response.status());
        if (loc.pathname === "/main.dart.js") sameOriginScriptStatus =
          response.ok() && sameOriginScriptStatus !== "ERROR" ? "200" : "ERROR";
      } catch (_) { /* do not log request content */ }
    });
    page.on("requestfailed", req => {
      try {
        const host = new URL(req.url()).hostname;
        const internal = host === "d1z-proxy";
        failedRequests[internal ? "internal" : "external"]++;
        tally(requestKinds, req.resourceType().toUpperCase().replace(/[^A-Z]/g, "").slice(0, 24) || "UNKNOWN");
        if (!internal) tally(failedHostCategories, externalHostCategory(host));
      } catch (_) {
        failedRequests.external++;
      }
    });
    stage = "DOCUMENT";
    const response = await page.goto("https://d1z-proxy/", {
      waitUntil: "domcontentloaded", timeout: 45000
    });
    if (!response || response.status() !== 200) throw Error("ROOT_HTTP");
    browserDocumentStatus = "200";
    console.log("D1Z_CHROMIUM_DOCUMENT=PASS");
    stage = "FLUTTER_VIEW";
    try {
      await page.locator("flutter-view").first().waitFor({
        state: "attached", timeout: 45000
      });
    } catch (_) {
      const state = await page.evaluate(() => ({
        bootstrap: !!document.querySelector('script[src*="flutter_bootstrap"]'),
        flutterView: !!document.querySelector("flutter-view"),
        flutterCanvas: !!document.querySelector("flt-glass-pane"),
        scriptCount: document.scripts.length
      })).catch(() => null);
      console.log("D1Z_CHROMIUM_BOOTSTRAP_TAG=" +
                  (state?.bootstrap ? "YES" : "NO"));
      console.log("D1Z_CHROMIUM_FLUTTER_VIEW_PRESENT=" +
                  (state?.flutterView ? "YES" : "NO"));
      console.log("D1Z_CHROMIUM_CANVAS_PRESENT=" +
                  (state?.flutterCanvas ? "YES" : "NO"));
      console.log("D1Z_CHROMIUM_SCRIPT_TAGS_PRESENT=" +
                  ((state?.scriptCount || 0) > 0 ? "YES" : "NO"));
      // Diagnostic control only: replace the one known blocked external font
      // stylesheet with an empty response. Never treat this as a browser PASS.
      let fontIsolation = "NOT_RUN";
      try {
        const probe = await browser.newPage({
          ignoreHTTPSErrors: true, viewport: { width: 1280, height: 800 }
        });
        await probe.route(/^https:\/\/fonts\.googleapis\.com\//, async route =>
          route.fulfill({ status: 200, contentType: "text/css", body: "" }));
        await probe.goto("https://d1z-proxy/", {
          waitUntil: "domcontentloaded", timeout: 15000
        });
        await probe.locator("flutter-view").first().waitFor({
          state: "attached", timeout: 12000
        });
        fontIsolation = "VIEW_PRESENT_WITH_FONT_STUB";
        await probe.close();
      } catch (_) {
        fontIsolation = "VIEW_ABSENT_OR_DIAGNOSTIC_FAILED";
      }
      console.log("D1Z_CHROMIUM_FONT_DEPENDENCY_DIAGNOSTIC=" + fontIsolation);
      throw Error("FLUTTER_VIEW_TIMEOUT");
    }
    console.log("D1Z_CHROMIUM_FLUTTER_VIEW=PASS");
    stage = "SAME_ORIGIN_API";
    const health = await page.evaluate(async () => {
      const response = await fetch("/api/health/", {
        credentials: "same-origin"
      });
      return response.status;
    });
    if (health !== 200) throw Error("BROWSER_API_HEALTH");
    console.log("D1Z_CHROMIUM_SAME_ORIGIN_API=PASS");
    stage = "JS_ERRORS";
    await page.waitForTimeout(1500);
    // The internal Docker network intentionally cannot reach external Google
    // Fonts. Such failures are tracked as degraded glyph coverage, never
    // silently counted as application JS errors. Any other console error,
    // pageerror, unexpected external host or internal request is fatal.
    console.log("D1Z_CHROMIUM_PAGE_ERRORS=" + pageErrors);
    console.log("D1Z_CHROMIUM_FONT_CONSOLE_ERRORS=" + fontConsoleErrors);
    console.log("D1Z_CHROMIUM_OTHER_CONSOLE_ERRORS=" + otherConsoleErrors);
    console.log("D1Z_CHROMIUM_EXPECTED_AUTH_DENIAL_CONSOLE=" + expectedAuthConsoleDenials);
    const allExternalAreFonts = failedRequests.external ===
      (failedHostCategories.GOOGLE_FONTS || 0);
    const authDenialsMatch = (internalForbiddenRoutes.AUTH_ME || 0) === 1 &&
      (internalForbiddenRoutes.WORKSPACES || 0) === 1 &&
      (internalHttpErrors["403"] || 0) === 2 &&
      Object.keys(internalHttpErrors).every(status => status === "403") &&
      expectedAuthConsoleDenials === 2 &&
      expectedAuthDenialConsoleRoutes.size === 2 &&
      expectedAuthDenialConsoleRoutes.get("/api/v1/me/") === 1 &&
      expectedAuthDenialConsoleRoutes.get("/api/v1/workspaces/") === 1;
    console.log("D1Z_CHROMIUM_EXPECTED_ANONYMOUS_403=" +
      (authDenialsMatch ? "PASS" : "FAIL"));
    if (pageErrors || otherConsoleErrors || failedRequests.internal ||
        !allExternalAreFonts || !authDenialsMatch) throw Error("BROWSER_JS_ERRORS");
    console.log("D1Z_CHROMIUM_APP_JS_ERRORS=NONE");
    if (fontConsoleErrors || failedRequests.external) {
      console.log("D1Z_CHROMIUM_FONT_NETWORK_DEGRADED=YES");
      console.log("D1Z_CHROMIUM_FONT_FIDELITY_VERIFIED=NO");
      console.log("D1Z_CHROMIUM_SMOKE=PASS_WITH_FONT_DEGRADATION");
    } else {
      console.log("D1Z_CHROMIUM_JS_ERRORS=NONE");
      console.log("D1Z_CHROMIUM_FONT_NETWORK_DEGRADED=NO");
      console.log("D1Z_CHROMIUM_FONT_FIDELITY_VERIFIED=YES");
      console.log("D1Z_CHROMIUM_SMOKE=PASS");
    }
  } catch (err) {
    const allowed = new Set([
      "INVALID_BROWSER_LOCALE", "ROOT_HTTP", "FLUTTER_VIEW_TIMEOUT", "BROWSER_API_HEALTH",
      "BROWSER_JS_ERRORS"
    ]);
    console.log("D1Z_CHROMIUM_FAILURE_STAGE=" +
                (allowed.has(err.message) ? err.message : stage));
    console.log("D1Z_CHROMIUM_JS_ERRORS_COUNT=" + errors.length);
    console.log("D1Z_CHROMIUM_PAGE_ERRORS=" + pageErrors);
    console.log("D1Z_CHROMIUM_FONT_CONSOLE_ERRORS=" + fontConsoleErrors);
    console.log("D1Z_CHROMIUM_OTHER_CONSOLE_ERRORS=" + otherConsoleErrors);
    console.log("D1Z_CHROMIUM_EXPECTED_AUTH_DENIAL_CONSOLE=" + expectedAuthConsoleDenials);
    console.log("D1Z_CHROMIUM_FAILED_INTERNAL_REQUESTS=" + failedRequests.internal);
    console.log("D1Z_CHROMIUM_FAILED_EXTERNAL_REQUESTS=" + failedRequests.external);
    console.log("D1Z_CHROMIUM_DOCUMENT_HTTP_STATUS=" + browserDocumentStatus);
    console.log("D1Z_CHROMIUM_SCRIPT_HTTP_STATUS=" + sameOriginScriptStatus);
    for (const [k, n] of Object.entries(requestKinds).sort()) console.log("D1Z_CHROMIUM_FAILED_REQUEST_TYPE_" + k + "=" + n);
    for (const [k, n] of Object.entries(failedHostCategories).sort()) console.log("D1Z_CHROMIUM_FAILED_HOST_CLASS_" + k + "=" + n);
    for (const [k, n] of Object.entries(errorCategories).sort()) console.log("D1Z_CHROMIUM_ERROR_CLASS_" + k + "=" + n);
    for (const [k, n] of Object.entries(exceptionTypes).sort()) console.log("D1Z_CHROMIUM_EXCEPTION_TYPE_" + k + "=" + n);
    safeErrorExamples.forEach((message, idx) => console.log("D1Z_CHROMIUM_SAFE_EXCEPTION_" + (idx + 1) + "=" + message));
    otherConsoleSamples.forEach((message, idx) => console.log("D1Z_CHROMIUM_OTHER_CONSOLE_SAFE_" + (idx + 1) + "=" + message));
    for (const [k, n] of Object.entries(otherConsoleLocationTypes).sort()) console.log("D1Z_CHROMIUM_OTHER_CONSOLE_ORIGIN_" + k + "=" + n);
    for (const [k, n] of Object.entries(internalHttpErrors).sort()) console.log("D1Z_CHROMIUM_INTERNAL_HTTP_STATUS_" + k + "=" + n);
    for (const [k, n] of Object.entries(internalForbiddenRoutes).sort()) console.log("D1Z_CHROMIUM_INTERNAL_403_ROUTE_" + k + "=" + n);
    process.exitCode = 1;
  } finally {
    if (browser) await browser.close();
  }
})().catch(() => {
  console.log("D1Z_CHROMIUM_FAILURE_STAGE=UNHANDLED");
  process.exitCode = 1;
});
