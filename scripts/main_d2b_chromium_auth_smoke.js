"use strict";
/* D2-B authenticates with disposable synthetic credentials against isolated PG17.
 * Do not log usernames, passwords, cookies, bodies, request URLs or screenshots.
 * The browser gets only the fixture username/password, never DB credentials.
 */
const { chromium } = require("playwright");

(async () => {
  let browser;
  let stage = "LAUNCH";
  const user = process.env.D2B_SYNTHETIC_USER;
  const password = process.env.D2B_SYNTHETIC_PASSWORD;
  if (!user?.startsWith("d2b-synthetic-") || !password || password.length < 24)
    throw Error("SYNTHETIC_IDENTITY_REQUIRED");
  const origin = "https://d2b-proxy";
  try {
    browser = await chromium.launch({
      headless: true, args: ["--no-sandbox", "--lang=es-ES"]
    });
    const page = await browser.newPage({
      ignoreHTTPSErrors: true, locale: "es-ES",
      viewport: { width: 1280, height: 800 }
    });
    const pageErrors = [];
    page.on("pageerror", () => pageErrors.push("JS_EXCEPTION"));

    stage = "LOGIN_FORM";
    const login = await page.goto(origin + "/accounts/login/?next=/", {
      waitUntil: "domcontentloaded", timeout: 45000
    });
    if (!login || login.status() !== 200) throw Error("LOGIN_FORM_HTTP");
    if (await page.locator('input[name="username"]').count() !== 1 ||
        await page.locator('input[name="password"]').count() !== 1 ||
        await page.locator('input[name="csrfmiddlewaretoken"]').count() !== 1)
      throw Error("LOGIN_FORM_FIELDS");
    console.log("D2B_LOGIN_FORM_AND_CSRF=PASS");

    stage = "LOGIN_SUBMIT";
    await page.locator('input[name="username"]').fill(user);
    await page.locator('input[name="password"]').fill(password);
    await Promise.all([
      page.waitForURL(url => url.pathname === "/", { timeout: 45000 }),
      page.locator('form button[type="submit"], form button:not([type])').first().click()
    ]);
    console.log("D2B_BROWSER_FORM_LOGIN=PASS");

    stage = "SESSION_IDENTITY";
    async function verifySession() {
      return page.evaluate(async () => {
        const me = await fetch("/api/v1/me/", {credentials: "same-origin"});
        const workspaces = await fetch("/api/v1/workspaces/", {
          credentials: "same-origin"
        });
        if (me.status !== 200 || workspaces.status !== 200)
          return {ok: false, identities: 0, memberships: 0};
        const identity = await me.json();
        const memberships = await workspaces.json();
        return {
          ok: typeof identity.id !== "undefined" &&
              typeof identity.username === "string" &&
              Array.isArray(memberships) &&
              memberships.length === 1 &&
              memberships[0].role === "owner",
          identities: identity.username === "REDACTED" ? 0 : 1,
          memberships: Array.isArray(memberships) ? memberships.length : 0
        };
      });
    }
    const first = await verifySession();
    if (!first.ok || first.memberships !== 1) throw Error("SESSION_WORKSPACE_CONTRACT");
    console.log("D2B_AUTHENTICATED_ME_200=PASS");
    console.log("D2B_AUTHENTICATED_WORKSPACE_OWNER=PASS");

    stage = "FLUTTER_RENDER";
    await page.locator("flutter-view").first().waitFor({
      state: "attached", timeout: 45000
    });
    await page.waitForTimeout(1500);
    if (pageErrors.length) throw Error("APP_PAGE_ERROR");
    console.log("D2B_AUTHENTICATED_FLUTTER_VIEW=PASS");
    console.log("D2B_AUTHENTICATED_PAGE_ERRORS=0");

    stage = "SESSION_RELOAD";
    await page.reload({waitUntil:"domcontentloaded",timeout:45000});
    await page.locator("flutter-view").first().waitFor({
      state: "attached", timeout: 45000
    });
    const second = await verifySession();
    if (!second.ok || second.memberships !== 1) throw Error("SESSION_RELOAD_FAILED");
    if (pageErrors.length) throw Error("APP_PAGE_ERROR_AFTER_RELOAD");
    console.log("D2B_BROWSER_RELOAD_SESSION_PRESERVED=PASS");
    console.log("D2B_SYNTHETIC_WORKSPACE_VISIBLE_IN_API=PASS");

    stage = "ANONYMOUS_ISOLATION";
    const anonymous = await browser.newPage({
      ignoreHTTPSErrors: true, locale: "es-ES"
    });
    await anonymous.goto(origin + "/", {waitUntil:"domcontentloaded"});
    const denied = await anonymous.evaluate(async () => {
      const a = await fetch("/api/v1/me/", {credentials:"same-origin"});
      const w = await fetch("/api/v1/workspaces/", {credentials:"same-origin"});
      return [a.status, w.status];
    });
    if (!denied.every(code => code === 401 || code === 403))
      throw Error("ANONYMOUS_ACCESS_NOT_DENIED");
    console.log("D2B_ANONYMOUS_SESSION_ISOLATION=PASS");
    await anonymous.close();

    stage = "COMPLETE";
    console.log("D2B_NO_CUSTOMER_DATA=YES");
    console.log("D2B_UI_AUTHENTICATED_NAVIGATION_COVERAGE=LOGIN_AND_RELOAD_ONLY");
    console.log("D2B_BROWSER_AUTH_SMOKE=PASS");
  } catch (e) {
    const markers = new Set([
      "LOGIN_FORM_HTTP", "LOGIN_FORM_FIELDS", "SESSION_WORKSPACE_CONTRACT",
      "APP_PAGE_ERROR", "APP_PAGE_ERROR_AFTER_RELOAD",
      "SESSION_RELOAD_FAILED", "ANONYMOUS_ACCESS_NOT_DENIED"
    ]);
    console.log("D2B_AUTH_FAILURE_STAGE=" +
      (markers.has(e.message) ? e.message : stage));
    process.exitCode = 1;
  } finally {
    if (browser) await browser.close();
  }
})().catch(() => {
  console.log("D2B_AUTH_FAILURE_STAGE=UNHANDLED");
  process.exitCode = 1;
});
