#!/usr/bin/env python3
"""D9: compare apex/DEV DNS destinations and loaded Caddy host coverage, read-only."""
import json
import os
from pathlib import Path
import re
import socket
import subprocess
import sys
import urllib.request
import urllib.error

def emit(k,v): print("D9_"+k+"="+str(v),flush=True)

def run(args, timeout=15):
    try:
        return subprocess.run(args, stdin=subprocess.DEVNULL,
                              stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                              text=True, check=False, timeout=timeout)
    except (OSError, subprocess.TimeoutExpired):
        return None

def dns4(host):
    try:
        return {a[4][0] for a in socket.getaddrinfo(host,443,socket.AF_INET,socket.SOCK_STREAM)}
    except (OSError,socket.gaierror):
        return set()

def safe_get_active_caddy():
    req=urllib.request.Request("http://127.0.0.1:2019/config/",method="GET",
                               headers={"Accept":"application/json"})
    opener=urllib.request.build_opener(urllib.request.ProxyHandler({}))
    try:
        with opener.open(req,timeout=5) as response:
            if response.status!=200: return None
            raw=response.read(2_000_001)
            if len(raw)>2_000_000: return None
        return json.loads(raw)
    except (OSError,ValueError,urllib.error.URLError):
        return None

def host_matches(servers,target):
    """Only explicit host-scoped matches count. No assertion for catch-all."""
    found=False
    proxy=False
    def explore(routes, inherited=False,depth=0):
        nonlocal found,proxy
        if depth>32 or not isinstance(routes,list): return
        for route in routes:
            if not isinstance(route,dict):continue
            match=route.get("match",[])
            if not isinstance(match,list):continue
            conditions=[m.get("host") for m in match if isinstance(m,dict) and isinstance(m.get("host"),list)]
            has_explicit=bool(conditions)
            scope=(inherited and not has_explicit) or any(target in h for h in conditions)
            if scope: found=True
            for handler in route.get("handle",[]):
                if not isinstance(handler,dict): continue
                if scope and handler.get("handler")=="reverse_proxy": proxy=True
                if handler.get("handler")=="subroute":
                    explore(handler.get("routes",[]),scope,depth+1)
    for server in servers.values():
        if isinstance(server,dict): explore(server.get("routes",[]))
    return found,proxy

def probe_local_sni(host):
    # Caddy's local :443 listener is tested without requiring public DNS.
    # No -k: certificate verification is mandatory. No response body.
    p=run(["curl","--noproxy","*","--proto","=https","--tlsv1.2",
          "--resolve",host+":443:127.0.0.1","--silent","--show-error",
          "--connect-timeout","5","--max-time","12","--output","/dev/null",
          "--write-out","%{http_code} %{ssl_verify_result}",
          "https://"+host+"/"],timeout=16)
    if p is None: return ("UNAVAILABLE","UNKNOWN","UNKNOWN")
    items=p.stdout.strip().split()
    code=items[0] if len(items)==2 and re.fullmatch("[0-9]{3}",items[0]) else "UNKNOWN"
    verify=items[1] if len(items)==2 and re.fullmatch("[0-9]+",items[1]) else "UNKNOWN"
    return (str(p.returncode),code,verify)

def main():
    print("MFA_RELEASE_AUTHORIZED=NO")
    print("NO_DEPLOY_NO_LIVE_MIGRATION=1")
    for k in ("DEPLOY_EXECUTED","LIVE_MIGRATIONS_EXECUTED","LIVE_RESTORE_EXECUTED",
              "CADDY_RELOAD_EXECUTED","CADDY_CONFIG_CHANGED","DNS_CHANGED",
              "DOCKER_ACCESSED","O5_ACCESSED","PUBLIC_RELEASE_AUTHORIZED"):
        emit(k,"NO")
    if os.geteuid()==0:
        emit("ROOT_EXECUTION_DENIED","YES");emit("RESULT",2);return 2
    root=Path(__file__).resolve().parent.parent
    a=run(["git","rev-parse","HEAD"])
    b=run(["git","rev-parse","refs/remotes/origin/main"])
    c=run(["git","status","--porcelain"])
    if any(p is None or p.returncode!=0 for p in (a,b,c)) or a.stdout!=b.stdout or c.stdout.strip():
        emit("MAIN_CLEAN","FAIL");emit("RESULT",2);return 2
    emit("MAIN_CLEAN","PASS")
    dev=dns4("dev.vencira.es")
    apex=dns4("vencira.es")
    emit("DEV_IPV4_DNS","YES" if dev else "NO")
    emit("APEX_IPV4_DNS","YES" if apex else "NO")
    emit("APEX_ALL_IPV4_DESTINATIONS_MATCH_DEV","YES" if dev and apex and dev==apex else "NO")
    emit("APEX_ANY_IPV4_DESTINATION_SHARED_WITH_DEV","YES" if dev & apex else "NO")
    active=safe_get_active_caddy()
    if isinstance(active,dict):
        servers=active.get("apps",{}).get("http",{}).get("servers",{})
        if isinstance(servers,dict):
            emit("CADDY_LOADED_CONFIG_READ","PASS")
            for label,host in (("DEV","dev.vencira.es"),("APEX","vencira.es")):
                matched,proxy=host_matches(servers,host)
                emit(label+"_EXPLICIT_HOST_ROUTE_PRESENT","YES" if matched else "NO")
                emit(label+"_EXPLICIT_HOST_PROXY_PRESENT","YES" if proxy else "NO")
        else:
            emit("CADDY_LOADED_CONFIG_READ","INVALID_STRUCTURE")
    else:
        emit("CADDY_LOADED_CONFIG_READ","UNAVAILABLE")
    for label,host in (("DEV","dev.vencira.es"),("APEX","vencira.es")):
        rc,status,verify=probe_local_sni(host)
        emit(label+"_LOCAL_CADDY_SNI_CURL_EXIT",rc)
        emit(label+"_LOCAL_CADDY_SNI_HTTP_STATUS",status)
        emit(label+"_LOCAL_CADDY_SNI_TLS_VERIFY",verify)
    emit("PRODUCTION_COOKIES_CSRF_VERIFIED","NO")
    emit("EXTERNAL_NETWORK_PATH_ROOT_CAUSE_PROVEN","NO")
    emit("RELEASE_READINESS","BLOCKED")
    emit("RESULT",4)
    return 4

if __name__=="__main__": sys.exit(main())
