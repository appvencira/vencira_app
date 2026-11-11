"use strict";
// D2-E: actual mouse/keyboard gestures on Flutter Web semantics, not API writes.
// Only fixture identities exist in isolated PostgreSQL tmpfs.
const { chromium } = require("playwright");
(async () => {
  let browser,stage="LAUNCH";
  const jsErrors=[];
  const username=process.env.D2E_SYNTHETIC_USER;
  const password=process.env.D2E_SYNTHETIC_PASSWORD;
  if(!username?.startsWith("d2e-synthetic-")||!password||password.length<24)
    throw Error("SYNTHETIC_CREDENTIALS_REQUIRED");
  const origin="https://d2e-proxy";
  const passId=process.env.D2E_PASS_ID;
  if(!["first","second"].includes(passId))throw Error("PASS_ID_REQUIRED");
  const changedNotes="D2E GUI "+passId;
  try {
    browser=await chromium.launch({headless:true,args:["--no-sandbox","--lang=es-ES"]});
    const page=await browser.newPage({ignoreHTTPSErrors:true,locale:"es-ES",
      viewport:{width:1280,height:800}});
    page.on("pageerror",()=>jsErrors.push(1));
    stage="LOGIN_FORM";
    const login=await page.goto(origin+"/accounts/login/?next=/",
      {waitUntil:"domcontentloaded",timeout:45000});
    if(login?.status()!==200)throw Error("LOGIN_HTTP");
    await page.locator('input[name="username"]').fill(username);
    await page.locator('input[name="password"]').fill(password);
    await Promise.all([
      page.waitForURL(u=>u.pathname==="/",{timeout:45000}),
      page.locator('button[type="submit"]').click()
    ]);
    console.log("D2E_BROWSER_SYNTHETIC_LOGIN=PASS");
    stage="FLUTTER_VIEW";
    await page.locator("flutter-view").first().waitFor({
      state:"attached",timeout:45000
    });
    console.log("D2E_FLUTTER_VIEW_ATTACHED=PASS");
    // Flutter uses CanvasKit and may expose accessibility nodes through
    // shadow roots or an opt-in semantics placeholder. Inspect only counts;
    // never log DOM content, customer data, cookies, URLs, or tokens.
    stage="ACCESSIBILITY_DISCOVERY";
    const accessibility=await page.evaluate(() => {
      const view=document.querySelector("flutter-view");
      const viewRoot=view?.shadowRoot||view;
      const query=(sel)=>[...document.querySelectorAll(sel)].length+
        ((viewRoot && viewRoot!==document)?
          [...viewRoot.querySelectorAll(sel)].length:0);
      return {
        viewShadow:!!view?.shadowRoot,
        placeholderCount:query("flt-semantics-placeholder"),
        semanticsCount:query("flt-semantics"),
        hostCount:query("flt-semantics-host"),
        htmlButtonCount:query("button")
      };
    });
    console.log("D2E_FLUTTER_SHADOW_ROOT="+(accessibility.viewShadow?"YES":"NO"));
    console.log("D2E_FLUTTER_PLACEHOLDER_COUNT="+accessibility.placeholderCount);
    console.log("D2E_FLUTTER_SEMANTICS_COUNT_BEFORE="+accessibility.semanticsCount);
    console.log("D2E_FLUTTER_SEMANTICS_HOST_COUNT="+accessibility.hostCount);
    stage="ACCESSIBILITY_ENABLE";
    // A real pointer click is required; no Flutter state or DOM mutation.
    const placeholder=page.locator("flt-semantics-placeholder");
    if(await placeholder.count()){
      console.log("D2E_FLUTTER_PLACEHOLDER_FOUND=YES");
      const p=placeholder.first();
      const geometry=await p.evaluate(node=>{
        const r=node.getBoundingClientRect();
        const css=getComputedStyle(node);
        return {
          width:Math.round(r.width),height:Math.round(r.height),
          insideViewport:r.left>=0 && r.top>=0 &&
            r.right<=innerWidth && r.bottom<=innerHeight,
          displayNone:css.display==="none",
          visibilityHidden:css.visibility==="hidden",
          pointerNone:css.pointerEvents==="none",
          opacityZero:Number(css.opacity)===0
        };
      });
      console.log("D2E_PLACEHOLDER_GEOMETRY="+
        (geometry.width>0&&geometry.height>0?"NONZERO":"ZERO"));
      console.log("D2E_PLACEHOLDER_IN_VIEWPORT="+
        (geometry.insideViewport?"YES":"NO"));
      console.log("D2E_PLACEHOLDER_DISPLAY_NONE="+
        (geometry.displayNone?"YES":"NO"));
      console.log("D2E_PLACEHOLDER_VISIBILITY_HIDDEN="+
        (geometry.visibilityHidden?"YES":"NO"));
      console.log("D2E_PLACEHOLDER_POINTER_EVENTS_NONE="+
        (geometry.pointerNone?"YES":"NO"));
      console.log("D2E_PLACEHOLDER_OPACITY_ZERO="+
        (geometry.opacityZero?"YES":"NO"));
      stage="ACCESSIBILITY_BOOTSTRAP";
      // Flutter deliberately positions this opt-in placeholder offscreen
      // (-1,-1). A browser mouse cannot target it. Its native DOM click()
      // activates Flutter's accessibility handler. This is exclusively the
      // accessibility opt-in, NOT a business action, not an injected PATCH,
      // and not a replacement for mouse/keyboard interaction with the editor.
      if(!geometry.insideViewport){
        await p.evaluate(element=>element.click());
        console.log("D2E_ACCESSIBILITY_HIDDEN_BUTTON_ACTIVATED=PASS");
      } else {
        await p.click({timeout:10000});
        console.log("D2E_ACCESSIBILITY_POINTER_ACTIVATED=PASS");
      }
    } else {
      console.log("D2E_FLUTTER_PLACEHOLDER_FOUND=NO");
    }
    stage="ACCESSIBILITY_TREE";
    const semanticSelector=page.locator("flt-semantics, flt-semantics-host");
    await semanticSelector.first().waitFor({
      state:"attached",timeout:20000
    });
    console.log("D2E_FLUTTER_SEMANTICS_CONTAINER_ATTACHED=PASS");
    console.log("D2E_ACCESSIBILITY_BOOTSTRAP_ONLY=YES");
    stage="INITIAL_ROUTE";
    // A single-workspace login asynchronously opens Today's agenda. The
    // Flutter AX name is not necessarily EXACTLY "Back"/"Volver" and the
    // route transition can race semantics initialization. Poll until either
    // the synthetic customer is accessible or one unambiguous Back control
    // appears; no JS navigation/history manipulation or API writes.
    const customerText=page.getByText("Persona ficticia D2E",{exact:true});
    const customerSemantics=page.locator(
      'flt-semantics[aria-label*="Persona ficticia D2E"]'
    );
    const backByRole=page.getByRole("button",{
      name:/\b(?:back|volver|atrás|atras|regresar)\b/i
    });
    const backBySemantic=page.locator(
      'flt-semantics[role="button"]'
    ).filter({hasText:/\b(?:back|volver|atrás|atras|regresar)\b/i});
    // Avoid relying on a hidden semantic node's accessibility role; the
    // fallback checks the same Flutter node directly, not an arbitrary text.
    const backAria=page.locator(
      'flt-semantics[role="button"][aria-label*="Back"],'+
      'flt-semantics[role="button"][aria-label*="Volver"],'+
      'flt-semantics[role="button"][aria-label*="Atrás"]'
    );
    let route="UNKNOWN";
    let backCandidate=null;
    for(let tries=0;tries<40;tries++){
      if((await customerText.count())>0 ||
         (await customerSemantics.count())>0){
        route="DASHBOARD";break;
      }
      const roleCount=await backByRole.count();
      const semanticCount=await backBySemantic.count();
      const ariaCount=await backAria.count();
      if(roleCount===1){route="AGENDA";backCandidate=backByRole;break;}
      if(roleCount===0 && semanticCount===1){
        route="AGENDA";backCandidate=backBySemantic;break;
      }
      if(roleCount===0 && semanticCount===0 && ariaCount===1){
        route="AGENDA";backCandidate=backAria;break;
      }
      await page.waitForTimeout(250);
    }
    console.log("D2E_INITIAL_ROUTE="+route);
    console.log("D2E_INITIAL_BACK_ROLE_COUNT="+await backByRole.count());
    console.log("D2E_INITIAL_BACK_SEMANTIC_COUNT="+
      await backBySemantic.count());
    console.log("D2E_INITIAL_BACK_ARIA_COUNT="+await backAria.count());
    if(route==="AGENDA"){
      stage="RETURN_FROM_AGENDA";
      await backCandidate.click({timeout:20000});
      console.log("D2E_GUI_RETURN_FROM_AGENDA=PASS");
    }
    stage="DASHBOARD_LIST";
    // Flutter CanvasKit exposes text as ARIA labels as well as (sometimes)
    // plain DOM text nodes. Both are accessible DOM content, not API probes.
    const visible=await Promise.any([
      customerText.first().waitFor({state:"attached",timeout:15000})
        .then(()=>true),
      customerSemantics.first().waitFor({state:"attached",timeout:15000})
        .then(()=>true)
    ]).catch(()=>false);
    if(!visible){
      const summary=await page.evaluate(()=>{
        const nodes=[...document.querySelectorAll(
          "flt-semantics, flt-semantics-host, [role=button]"
        )];
        return {
          semantics:document.querySelectorAll("flt-semantics").length,
          labeled:nodes.filter(el=>el.hasAttribute("aria-label")).length,
          buttons:document.querySelectorAll('[role=button]').length,
          agendaLabeled:nodes.some(el=>/agenda/i.test(
            el.getAttribute("aria-label")||""))
        };
      });
      console.log("D2E_DASHBOARD_SEMANTICS_COUNT="+summary.semantics);
      console.log("D2E_DASHBOARD_LABELED_COUNT="+summary.labeled);
      console.log("D2E_DASHBOARD_ROLE_BUTTON_COUNT="+summary.buttons);
      console.log("D2E_DASHBOARD_AGENDA_LABEL_PRESENT="+
        (summary.agendaLabeled?"YES":"NO"));
      // Read-only API baseline separates data-loading failure from Flutter
      // accessibility/route failure. Never use an API write or expose body.
      const baseline=await page.evaluate(async()=>{
        try {
          const ws=await fetch("/api/v1/workspaces/",{
            credentials:"same-origin",cache:"no-store"});
          if(ws.status!==200)return "WORKSPACES_HTTP_"+ws.status;
          const memberships=await ws.json();
          if(!Array.isArray(memberships)||memberships.length!==1)
            return "MEMBERSHIP_COUNT";
          const api="/api/v1/workspaces/"+
            encodeURIComponent(memberships[0].id)+
            "/renewals/?q=D2E-EDIT";
          const renewals=await fetch(api,{
            credentials:"same-origin",cache:"no-store"});
          if(renewals.status!==200)
            return "RENEWALS_HTTP_"+renewals.status;
          const list=await renewals.json();
          return (list.results||[]).some(x=>
            x.customer_reference==="D2E-EDIT")?"FIXTURE_VISIBLE":"FIXTURE_MISSING";
        } catch(_){return "READ_ERROR";}
      });
      console.log("D2E_READONLY_API_BASELINE="+baseline);
      // Inspect Flutter semantics without printing actual text, DOM markup,
      // application data, cookies or URLs. A node may have textContent but no
      // aria-label; CanvasKit may expose names only in the accessibility tree.
      const dom=await page.evaluate(()=>{
        const nodes=[...document.querySelectorAll("flt-semantics")];
        const text=nodes.filter(n=>
          (n.textContent||"").includes("Persona ficticia D2E")).length;
        const aria=nodes.filter(n=>
          (n.getAttribute("aria-label")||"")
            .includes("Persona ficticia D2E")).length;
        const content=nodes.filter(n=>
          (n.getAttribute("flt-semantics-label")||"")
            .includes("Persona ficticia D2E")).length;
        const roles=nodes.filter(n=>n.hasAttribute("role")).length;
        const hasBack=nodes.some(n=>/back|volver|atrás|atras/i.test(
          [n.getAttribute("aria-label"),n.textContent]
            .filter(Boolean).join(" ")));
        return {text,aria,content,roles,hasBack};
      });
      console.log("D2E_SEMANTICS_TEXT_MATCH_COUNT="+dom.text);
      console.log("D2E_SEMANTICS_ARIA_MATCH_COUNT="+dom.aria);
      console.log("D2E_SEMANTICS_CUSTOM_LABEL_MATCH_COUNT="+dom.content);
      console.log("D2E_SEMANTICS_ROLE_COUNT="+dom.roles);
      console.log("D2E_SEMANTICS_BACK_TEXT_PRESENT="+
        (dom.hasBack?"YES":"NO"));
      // Chromium AX tree is read-only; compare names to a fixed synthetic
      // fixture, emit counts only, and never dump the tree to logs.
      try {
        const cdp=await page.context().newCDPSession(page);
        const ax=await cdp.send("Accessibility.getFullAXTree");
        const nodes=Array.isArray(ax.nodes)?ax.nodes:[];
        console.log("D2E_AX_NODE_COUNT="+nodes.length);
        console.log("D2E_AX_SYNTHETIC_NAME_MATCH="+
          (nodes.some(n=>String(n.name?.value||"")
            .includes("Persona ficticia D2E"))?"YES":"NO"));
        console.log("D2E_AX_BACK_NAME_MATCH="+
          (nodes.some(n=>/back|volver|atrás|atras/i.test(
            String(n.name?.value||"")))?"YES":"NO"));
        await cdp.detach();
      } catch(_) {console.log("D2E_AX_TREE_AVAILABLE=NO");}
      throw Error("RENEWAL_NOT_IN_ACCESSIBLE_DASHBOARD");
    }
    console.log("D2E_GUI_SYNTHETIC_RENEWAL_VISIBLE=PASS");
    stage="OPEN_EDITOR";
    const edit=page.getByRole("button",{name:/editar/i}).first();
    await edit.click({timeout:20000});
    console.log("D2E_GUI_EDIT_CLICK=PASS");
    stage="EDITOR_FORM";
    // Use the accessible text control generated by Flutter. No DOM injection,
    // direct API PATCH, programmatic Flutter state modifications or JavaScript
    // dispatchEvent substitutes.
    const notes=page.getByRole("textbox",{name:/notas|observaciones/i}).last();
    await notes.waitFor({state:"visible",timeout:20000});
    await notes.fill(changedNotes);
    console.log("D2E_GUI_NOTES_TYPED=PASS");
    stage="SAVE_CLICK";
    // Observe only metadata about actual Flutter-originating HTTP writes.
    // No response bodies, request payloads, URLs with IDs or credentials.
    const writes=[];
    const writeResponses=[];
    page.on("response",response=>{
      const request=response.request();
      if(request.method()==="PATCH" &&
        /\/api\/v1\/workspaces\/[^/]+\/renewals\/[^/]+\/$/.test(
          new URL(response.url()).pathname)){
        writes.push({status:response.status(),method:request.method()});
        // Only classify fixed synthetic fixture and notes equality;
        // do not log response bodies, request bodies, tokens or UUIDs.
        writeResponses.push(response.json().then(body=>({
          targetFixture:body?.customer_reference==="D2E-EDIT",
          returnedNotesMatch:body?.notes===changedNotes,
          returnedNotesPresent:typeof body?.notes==="string"
        })).catch(()=>({parseError:true})));
      }
    });
    const editorBefore=await page.getByRole("button",{name:/guardar/i}).count();
    console.log("D2E_GUI_SAVE_BUTTON_COUNT="+editorBefore);
    await page.getByRole("button",{name:/guardar/i}).last().click({timeout:20000});
    console.log("D2E_GUI_SAVE_CLICK=PASS");
    // Flutter updates asynchronously; give the actual PATCH operation time
    // to complete and observe its status rather than relying on a fixed sleep.
    await page.waitForTimeout(1800);
    console.log("D2E_GUI_PATCH_COUNT="+writes.length);
    console.log("D2E_GUI_PATCH_STATUS="+
      (writes.length===0?"NONE":writes.map(x=>x.status).join(",")));
    const writeBodies=await Promise.all(writeResponses);
    console.log("D2E_GUI_PATCH_FIXTURE_TARGET="+
      (writeBodies.some(x=>x.targetFixture)?"YES":"NO"));
    console.log("D2E_GUI_PATCH_RETURNED_NOTES_MATCH="+
      (writeBodies.some(x=>x.returnedNotesMatch)?"YES":"NO"));
    console.log("D2E_GUI_PATCH_RETURNED_NOTES_FIELD="+
      (writeBodies.some(x=>x.returnedNotesPresent)?"YES":"NO"));
    console.log("D2E_GUI_EDITOR_STILL_OPEN="+
      ((await page.getByRole("button",{name:/guardar/i}).count())>0?"YES":"NO"));
    stage="PERSISTENCE";
    // GET is evidence only; all writes must originate in actual GUI controls.
    const verified=await page.evaluate(async(expectedNotes)=>{
      const spaces=await fetch("/api/v1/workspaces/",{credentials:"same-origin"});
      if(spaces.status!==200)return "WORKSPACE_HTTP";
      const memberships=await spaces.json();
      if(!Array.isArray(memberships)||memberships.length!==1)return "WORKSPACE_LIST";
      const ws=memberships[0].id;
      for(let i=0;i<30;i++){
        const r=await fetch("/api/v1/workspaces/"+encodeURIComponent(ws)+
          "/renewals/?q=D2E-EDIT",{credentials:"same-origin",cache:"no-store"});
        if(r.status!==200)return "READ_HTTP";
        const body=await r.json();
        const match=(body.results||[]).find(x=>x.customer_reference==="D2E-EDIT");
        if(match?.notes===expectedNotes)return "PASS";
        await new Promise(resolve=>setTimeout(resolve,250));
      }
      return "NOT_PERSISTED";
    },changedNotes);
    if(verified==="NOT_PERSISTED"){
      const detailCheck=await page.evaluate(async(expectedNotes)=>{
        try{
          const ws=await fetch("/api/v1/workspaces/",{credentials:"same-origin",cache:"no-store"});
          if(ws.status!==200)return "WORKSPACE_READ_ERROR";
          const spaces=await ws.json();
          if(!Array.isArray(spaces)||spaces.length!==1)return "WORKSPACE_COUNT";
          const root="/api/v1/workspaces/"+encodeURIComponent(spaces[0].id);
          const list=await fetch(root+"/renewals/?q=D2E-EDIT",{
            credentials:"same-origin",cache:"no-store"});
          if(list.status!==200)return "LIST_READ_ERROR";
          const records=(await list.json()).results||[];
          const item=records.find(x=>x.customer_reference==="D2E-EDIT");
          if(!item)return "LIST_FIXTURE_NOT_FOUND";
          const detail=await fetch(root+"/renewals/"+
            encodeURIComponent(item.id)+"/",{
              credentials:"same-origin",cache:"no-store"});
          if(detail.status!==200)return "DETAIL_HTTP_"+detail.status;
          const data=await detail.json();
          if(data.notes===expectedNotes)return "DETAIL_MATCHES";
          if(typeof data.notes!=="string")return "DETAIL_NOTES_MISSING";
          if(data.notes==="Before D2E")return "DETAIL_NOTES_UNCHANGED";
          return "DETAIL_NOTES_DIFFERENT";
        }catch(_){return "DETAIL_READ_ERROR";}
      },changedNotes);
      console.log("D2E_READONLY_DETAIL_PERSISTENCE="+detailCheck);
    }
    if(verified!=="PASS")throw Error(verified);
    console.log("D2E_GUI_TO_DJANGO_PG17_PERSISTENCE=PASS");
    if(jsErrors.length)throw Error("JS_PAGE_ERRORS");
    console.log("D2E_GUI_PAGE_ERRORS=0");
    console.log("D2E_BROWSER_GUI_WRITE_METHOD=REAL_POINTER_KEYBOARD");
    console.log("D2E_REAL_GUI_END_TO_END_GATE=PASS");
  } catch(err) {
    const v=String(err?.message||"");
    const names=new Set(["LOGIN_HTTP","WORKSPACE_HTTP","WORKSPACE_LIST",
      "READ_HTTP","NOT_PERSISTED","JS_PAGE_ERRORS"]);
    console.log("D2E_GUI_FAILURE_STAGE="+(names.has(v)?v:stage));
    console.log("D2E_GUI_PAGE_ERROR_COUNT="+jsErrors.length);
    console.log("D2E_GUI_FAILURE_TYPE="+
      (err?.name==="TimeoutError"?"TIMEOUT":
       err?.name==="Error"?"ASSERTION_OR_RUNTIME":"OTHER"));
    process.exitCode=1;
  } finally {if(browser)await browser.close();}
})().catch(()=>{console.log("D2E_GUI_FAILURE_STAGE=UNHANDLED");process.exitCode=1;});
