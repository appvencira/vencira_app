"use strict";
// D1-Z browser-stage diagnostics: emit only fixed markers/counters, never URLs,
// console messages, cookies, tokens, or response bodies.
const { chromium } = require("playwright");
(async () => {
  let browser;
  let stage = "LAUNCH";
  const errors = [];
  const failedRequests = { internal: 0, external: 0 };
  const requestKinds = {};
  const failedHostCategories = {};
  const errorCategories = {};
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
    return "OTHER";
  }
  try {
    browser = await chromium.launch({ headless: true, args: ["--no-sandbox"] });
    console.log("D1Z_CHROMIUM_LAUNCH=PASS");
    stage = "CONTEXT";
    const page = await browser.newPage({
      ignoreHTTPSErrors: true, viewport: { width: 1280, height: 800 }
    });
    page.on("pageerror", err => {
      errors.push("PAGE_ERROR");
      tally(errorCategories, errorCategory(err && err.message));
    });
    page.on("console", msg => {
      if (msg.type() === "error") {
        errors.push("CONSOLE_ERROR");
        tally(errorCategories, errorCategory(msg.text()));
      }
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
    if (errors.length) throw Error("BROWSER_JS_ERRORS");
    console.log("D1Z_CHROMIUM_JS_ERRORS=NONE");
    console.log("D1Z_CHROMIUM_SMOKE=PASS");
  } catch (err) {
    const allowed = new Set([
      "ROOT_HTTP", "FLUTTER_VIEW_TIMEOUT", "BROWSER_API_HEALTH",
      "BROWSER_JS_ERRORS"
    ]);
    console.log("D1Z_CHROMIUM_FAILURE_STAGE=" +
                (allowed.has(err.message) ? err.message : stage));
    console.log("D1Z_CHROMIUM_JS_ERRORS_COUNT=" + errors.length);
    console.log("D1Z_CHROMIUM_FAILED_INTERNAL_REQUESTS=" + failedRequests.internal);
    console.log("D1Z_CHROMIUM_FAILED_EXTERNAL_REQUESTS=" + failedRequests.external);
    for (const [k, n] of Object.entries(requestKinds).sort()) console.log("D1Z_CHROMIUM_FAILED_REQUEST_TYPE_" + k + "=" + n);
    for (const [k, n] of Object.entries(failedHostCategories).sort()) console.log("D1Z_CHROMIUM_FAILED_HOST_CLASS_" + k + "=" + n);
    for (const [k, n] of Object.entries(errorCategories).sort()) console.log("D1Z_CHROMIUM_ERROR_CLASS_" + k + "=" + n);
    process.exitCode = 1;
  } finally {
    if (browser) await browser.close();
  }
})().catch(() => {
  console.log("D1Z_CHROMIUM_FAILURE_STAGE=UNHANDLED");
  process.exitCode = 1;
});
