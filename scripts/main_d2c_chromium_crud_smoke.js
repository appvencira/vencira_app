"use strict";
// D2-C: isolated PostgreSQL tmpfs only. Never log identities, request/response
// bodies, credentials, cookies, URLs containing UUIDs, or browser screenshots.
const { chromium } = require("playwright");
(async () => {
  let browser; let stage = "START";
  const user = process.env.D2C_SYNTHETIC_USER;
  const password = process.env.D2C_SYNTHETIC_PASSWORD;
  if (!user?.startsWith("d2c-synthetic-") || !password || password.length < 24)
    throw Error("MISSING_SYNTHETIC_CREDENTIALS");
  try {
    browser = await chromium.launch({headless:true,args:["--no-sandbox","--lang=es-ES"]});
    const page = await browser.newPage({locale:"es-ES",ignoreHTTPSErrors:true,
      viewport:{width:1280,height:800}});
    const jsErrors=[];
    page.on("pageerror", () => jsErrors.push("JS"));
    const origin="https://d2c-proxy";
    stage="LOGIN";
    const login = await page.goto(origin+"/accounts/login/?next=/",
      {waitUntil:"domcontentloaded",timeout:45000});
    if (login?.status()!==200 ||
        await page.locator('input[name="csrfmiddlewaretoken"]').count()!==1)
      throw Error("LOGIN_CSRF_MISSING");
    await page.locator('input[name="username"]').fill(user);
    await page.locator('input[name="password"]').fill(password);
    await Promise.all([
      page.waitForURL(u=>u.pathname==="/",{timeout:45000}),
      page.locator('form button[type="submit"]').click()
    ]);
    console.log("D2C_BROWSER_SYNTHETIC_LOGIN=PASS");
    stage="FLUTTER";
    await page.locator("flutter-view").first().waitFor({state:"attached",timeout:45000});
    console.log("D2C_FLUTTER_AUTHENTICATED_VIEW=PASS");
    stage="CRUD";
    const result=await page.evaluate(async () => {
      const get = async path => fetch(path,{credentials:"same-origin",cache:"no-store"});
      const csrf=await get("/api/v1/csrf/");
      if (csrf.status!==200) return "CSRF_GET";
      const match=document.cookie.match(/(?:^|;\s*)vencira_csrftoken=([^;]+)/);
      if(!match) return "CSRF_COOKIE";
      const token=decodeURIComponent(match[1]);
      const headers={"Content-Type":"application/json","X-CSRFToken":token};
      const write=async(path,method,body)=>fetch(path,{
        method,credentials:"same-origin",headers,body:JSON.stringify(body)
      });
      const me=await get("/api/v1/me/");
      const spaces=await get("/api/v1/workspaces/");
      if (me.status!==200 || spaces.status!==200) return "SESSION";
      const members=await spaces.json();
      if (!Array.isArray(members)||members.length!==1||members[0].role!=="owner")
        return "MEMBERSHIP";
      const workspace=members[0].id;
      if (typeof workspace!=="string")return "WORKSPACE_ID";
      const base="/api/v1/workspaces/"+encodeURIComponent(workspace);
      const expiry="2026-12-17", day="2026-12-17";
      const create=await write(base+"/renewals/","POST",{
        entry:"clients",full_name:"Persona ficticia D2C",
        expires_on:expiry,customer_reference:"D2C-TEST",status:"pending",
        notes:"Synthetic only"
      });
      if(create.status!==201) return "CREATE_HTTP_"+create.status;
      const created=await create.json();
      if(typeof created.id!=="string" || created.entry!=="clients" ||
         created.expires_on!==expiry)return "CREATE_BODY";
      const detail=base+"/renewals/"+encodeURIComponent(created.id)+"/";
      const shown=await get(detail);
      if(shown.status!==200)return "DETAIL_HTTP_"+shown.status;
      const item=await shown.json();
      if(item.customer_reference!=="D2C-TEST")return "DETAIL_BODY";
      const agenda=await get(base+"/agenda/?day="+day);
      if(agenda.status!==200)return "AGENDA_HTTP_"+agenda.status;
      const agendaData=await agenda.json();
      if(!Array.isArray(agendaData.results)||
         !agendaData.results.some(x=>x.id===created.id))return "AGENDA_MISSING";
      const patched=await write(detail,"PATCH",{notes:"Synthetic revised"});
      if(patched.status!==200)return "PATCH_HTTP_"+patched.status;
      const after=await get(detail);
      if(after.status!==200 || (await after.json()).notes!=="Synthetic revised")
        return "PATCH_NOT_PERSISTED";
      const history=await get(base+"/renewals/"+encodeURIComponent(created.id)+"/history/");
      if(history.status!==200)return "HISTORY_HTTP_"+history.status;
      const historyData=await history.json();
      if(!Array.isArray(historyData.results)||historyData.results.length<2)
        return "AUDIT_MISSING";
      return "PASS";
    });
    if(result!=="PASS")throw Error(result);
    console.log("D2C_SYNTHETIC_RENEWAL_CREATE_201=PASS");
    console.log("D2C_SYNTHETIC_RENEWAL_DETAIL=PASS");
    console.log("D2C_SYNTHETIC_AGENDA_DAY_VISIBLE=PASS");
    console.log("D2C_SYNTHETIC_RENEWAL_PATCH_PERSISTED=PASS");
    console.log("D2C_SYNTHETIC_AUDIT_EVENTS=PASS");
    stage="ANONYMOUS";
    const anon=await browser.newPage({ignoreHTTPSErrors:true,locale:"es-ES"});
    const denied=await anon.evaluate(async () => {
      const r=await fetch("https://d2c-proxy/api/v1/workspaces/",
        {credentials:"same-origin"});
      return r.status;
    });
    if(denied!==401 && denied!==403)throw Error("ANONYMOUS_NOT_DENIED");
    console.log("D2C_ANONYMOUS_WORKSPACE_DENIED=PASS");
    await anon.close();
    if(jsErrors.length)throw Error("FLUTTER_PAGE_ERRORS");
    console.log("D2C_BROWSER_PAGE_ERRORS=0");
    console.log("D2C_FIXTURE_ONLY=YES");
    console.log("D2C_REAL_UI_CRUD_CLICKS_VERIFIED=NO");
    console.log("D2C_CHROMIUM_SYNTHETIC_CRUD_GATE=PASS");
  } catch(e) {
    // Only constant class names or numeric HTTP statuses. Never print error
    // details returned by the server or dynamic URLs.
    const cause=String(e?.message||"UNKNOWN");
    console.log("D2C_BROWSER_FAILURE_STAGE="+stage);
    console.log("D2C_BROWSER_FAILURE_CLASS="+
      (/^[A-Z_]+(?:_[0-9]{3})?$/.test(cause)?cause:"OTHER"));
    process.exitCode=1;
  } finally { if(browser)await browser.close(); }
})().catch(()=>{console.log("D2C_BROWSER_FAILURE_STAGE=UNHANDLED");process.exitCode=1;});
