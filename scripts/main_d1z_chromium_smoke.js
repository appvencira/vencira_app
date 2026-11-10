"use strict";
// D1-Z real Chromium smoke against synthetically certified HTTPS laboratory.
const { chromium } = require("playwright");
(async () => {
  const browser = await chromium.launch({ headless: true, args: ["--no-sandbox"] });
  const page = await browser.newPage({ ignoreHTTPSErrors: true, viewport: { width: 1280, height: 800 } });
  let errors = [];
  page.on("pageerror", err => errors.push(err.name || "PageError"));
  page.on("console", msg => { if (msg.type() === "error") errors.push("ConsoleError"); });
  try {
    const response = await page.goto("https://d1z-proxy/", { waitUntil: "domcontentloaded", timeout: 45000 });
    if (!response || response.status() !== 200) throw Error("ROOT_HTTP");
    await page.locator("flutter-view").first().waitFor({ state: "attached", timeout: 60000 });
    console.log("D1Z_CHROMIUM_FLUTTER_VIEW=PASS");
    // Runtime must stay active after painting and call through the same TLS proxy.
    const health = await page.evaluate(async () => {
      const response = await fetch("/api/health/", { credentials: "same-origin" });
      return response.status;
    });
    if (health !== 200) throw Error("BROWSER_API_HEALTH");
    console.log("D1Z_CHROMIUM_SAME_ORIGIN_API=PASS");
    await page.waitForTimeout(1500);
    if (errors.length) {
      console.log("D1Z_CHROMIUM_JS_ERRORS_COUNT=" + errors.length);
      throw Error("BROWSER_JS_ERRORS");
    }
    console.log("D1Z_CHROMIUM_JS_ERRORS=NONE");
    console.log("D1Z_CHROMIUM_SMOKE=PASS");
  } catch (err) {
    // Fixed categorical marker, not messages or URL response content.
    const known = new Set(["ROOT_HTTP", "BROWSER_API_HEALTH", "BROWSER_JS_ERRORS"]);
    console.log("D1Z_CHROMIUM_FAILURE_STAGE=" + (known.has(err.message) ? err.message : "RENDER_OR_BROWSER"));
    process.exitCode = 1;
  } finally {
    await browser.close();
  }
})().catch(() => {
  console.log("D1Z_CHROMIUM_FAILURE_STAGE=LAUNCH");
  process.exitCode = 1;
});
