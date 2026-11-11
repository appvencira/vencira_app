#!/usr/bin/env python3
"""D11: dry-run production Compose structure with synthetic config only."""
import json
import os
from pathlib import Path
import re
import socket
import subprocess
import sys
import tempfile

def mark(k,v): print("D11_"+k+"="+str(v), flush=True)

def main():
    print("MFA_RELEASE_AUTHORIZED=NO")
    print("NO_DEPLOY_NO_LIVE_MIGRATION=1")
    for k in ("DEPLOY_EXECUTED","LIVE_MIGRATIONS_EXECUTED","LIVE_RESTORE_EXECUTED",
              "HOST_DOCKER_IMAGE_LOAD_EXECUTED","CONTAINER_RUN_EXECUTED",
              "CADDY_RELOAD_EXECUTED","CADDY_CONFIG_CHANGED","DNS_CHANGED",
              "PRODUCTION_ENV_READ","PRODUCTION_SECRETS_CREATED"):
        mark(k,"NO")
    if os.geteuid()==0:
        mark("ROOTLESS_REQUIRED","FAIL");return 2
    root=Path(__file__).resolve().parent.parent
    def cmd(argv, *, env=None, timeout=25):
        return subprocess.run(argv, cwd=str(root),env=env,stdin=subprocess.DEVNULL,
                              stdout=subprocess.PIPE,stderr=subprocess.PIPE,
                              text=True,timeout=timeout,check=False)
    try:
        head=cmd(["git","rev-parse","HEAD"])
        remote=cmd(["git","rev-parse","refs/remotes/origin/main"])
        status=cmd(["git","status","--porcelain"])
        if any(x.returncode for x in (head,remote,status)) or head.stdout!=remote.stdout or status.stdout.strip():
            mark("MAIN_CLEAN","FAIL");return 2
        mark("MAIN_CLEAN","PASS")
        p=root/"ops/production/compose.production.candidate.yaml"
        cfg=root/"ops/caddy/vencira.es.Caddyfile.candidate"
        if not p.is_file() or p.is_symlink() or not cfg.is_file() or cfg.is_symlink():
            mark("CANDIDATE_FILES","FAIL");return 3
        text=p.read_text(encoding="utf-8")
        if "vencira_localcheck" in text or "18731" in text or "18732" in text or "dev.vencira.es" in text:
            mark("DEV_ISOLATION","FAIL");return 3
        if not all(x in text for x in ("127.0.0.1:18741:8000","127.0.0.1:18742:8080","internal: true","name: vencira_prod")):
            mark("STRUCTURE","FAIL");return 3
        for role in ("DB","API","WEB"):
            if "${VENCIRA_PROD_"+role+"_IMAGE:?" not in text:
                mark("IMMUTABLE_IMAGE_VARIABLES","FAIL");return 3
        if "VENCIRA_PROD_ENV_FILE:?" not in text:
            mark("PROTECTED_ENV_REQUIRED","FAIL");return 3
        mark("DEV_ISOLATION","PASS")
        mark("SEPARATE_COMPOSE_PROJECT","PASS")
        with tempfile.TemporaryDirectory(prefix="vencira-d11-") as tmp:
            envfile=Path(tmp)/"synthetic.env"
            envfile.write_text(
                "VENCIRA_ENV=production\nDJANGO_DEBUG=0\nPOSTGRES_DB=d11_synthetic\n"
                "POSTGRES_USER=d11_synthetic\nPOSTGRES_PASSWORD=synthetic_not_real\n"
                "POSTGRES_HOST=db\nDJANGO_ALLOWED_HOSTS=vencira.es\n"
                "DJANGO_CSRF_TRUSTED_ORIGINS=https://vencira.es\n"
                "DJANGO_HTTPS_BEHIND_PROXY=1\nDJANGO_SECRET_KEY="+("d11synthetic"*6)+"\n",
                encoding="utf-8")
            os.chmod(envfile,0o600)
            env={**os.environ,
                "VENCIRA_PROD_ENV_FILE":str(envfile),
                "VENCIRA_PROD_DB_IMAGE":"postgres@sha256:"+("1"*64),
                "VENCIRA_PROD_API_IMAGE":"candidate-api@sha256:"+("2"*64),
                "VENCIRA_PROD_WEB_IMAGE":"candidate-web@sha256:"+("3"*64)}
            proc=cmd(["sudo","-n","docker","compose","-f",str(p),"config","--format","json"],env=env)
            if proc.returncode!=0:
                mark("COMPOSE_PARSE","FAIL");return 4
            obj=json.loads(proc.stdout)
            if obj.get("name")!="vencira_prod" or set(obj.get("services",{}))!={"api","db","web"}:
                mark("PROJECT_SERVICE_BOUNDARY","FAIL");return 4
            sv=obj["services"]
            networks=obj.get("networks",{})
            if len(networks)!=1 or not all(x.get("internal") is True for x in networks.values()):
                mark("PRIVATE_NETWORK_ONLY","FAIL");return 4
            db=sv["db"]
            if db.get("ports"):
                mark("PG17_HOST_PORTS","FAIL");return 4
            mounts=db.get("volumes",[])
            if len(mounts)!=1 or mounts[0].get("target")!="/var/lib/postgresql/data" or mounts[0].get("type")!="volume":
                mark("PG17_STORAGE_ISOLATION","FAIL");return 4
            for service,hostport,containerport in (("api",18741,8000),("web",18742,8080)):
                ports=sv[service].get("ports",[])
                if len(ports)!=1 or ports[0].get("host_ip")!="127.0.0.1" or int(ports[0].get("published",0))!=hostport or int(ports[0].get("target",0))!=containerport:
                    mark("HOST_LOOPBACK_PORTS","FAIL");return 4
            if any(v.get("build") is not None for v in sv.values()):
                mark("UNAPPROVED_IMAGE_BUILD","FAIL");return 4
            if any("vencira_localcheck" in json.dumps(v) for v in sv.values()):
                mark("DEV_REFERENCE","FAIL");return 4
        mark("COMPOSE_PARSE","PASS")
        mark("PRIVATE_NETWORK_ONLY","PASS")
        mark("PG17_HOST_PORTS","NONE")
        mark("PG17_NAMED_VOLUME_SEPARATE","PASS")
        mark("HOST_LOOPBACK_PORTS","PASS")
        mark("PRODUCTION_COMPOSE_CANDIDATE","PASS")
        for port in (18741,18742):
            with socket.socket(socket.AF_INET,socket.SOCK_STREAM) as sock:
                sock.settimeout(1)
                available=sock.connect_ex(("127.0.0.1",port))!=0
            mark("PROPOSED_PORT_"+str(port)+"_NO_LISTENER_OBSERVED", "YES" if available else "NO")
        mark("PORTS_RESERVED","NO")
        mark("DEPLOY_AUTHORIZED","NO")
        mark("RESULT",0)
        return 0
    except (OSError,subprocess.TimeoutExpired,ValueError,KeyError,TypeError,json.JSONDecodeError):
        mark("CHECK_FAILURE","YES");mark("RESULT",5);return 5
if __name__=="__main__":sys.exit(main())
