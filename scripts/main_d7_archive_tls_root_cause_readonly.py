#!/usr/bin/env python3
"""D7: classify export-ID discrepancy and public TLS failure without mutation."""
import json
import os
from pathlib import Path
import re
import socket
import subprocess
import sys

PREFIX="D7_"
def mark(k,v): print(f"{PREFIX}{k}={v}",flush=True)
def safe_run(args, timeout=180):
    return subprocess.run(args, stdout=subprocess.PIPE,stderr=subprocess.PIPE,
                          text=True, timeout=timeout,check=False,
                          stdin=subprocess.DEVNULL)

def main():
    print("MFA_RELEASE_AUTHORIZED=NO")
    print("NO_DEPLOY_NO_LIVE_MIGRATION=1")
    for k in ("DEPLOY_EXECUTED","LIVE_MIGRATIONS_EXECUTED","LIVE_RESTORE_EXECUTED",
              "HOST_DOCKER_IMAGE_LOAD_EXECUTED","CONTAINER_RUN_EXECUTED",
              "O5_CREDENTIALS_ACCESSED","OPERATIONAL_ROLLBACK_EXECUTED"):
        mark(k,"NO")
    repo=Path(__file__).resolve().parent.parent
    if os.geteuid()==0:
        mark("ROOT_EXECUTION_DENIED","YES");return 2
    try:
        a=safe_run(["git","rev-parse","HEAD"],15)
        b=safe_run(["git","rev-parse","refs/remotes/origin/main"],15)
        c=safe_run(["git","status","--porcelain"],15)
        if any(x.returncode for x in (a,b,c)) or a.stdout!=b.stdout or c.stdout.strip():
            mark("MAIN_CLEAN","FAIL");return 2
        mark("MAIN_CLEAN","PASS")
        base=Path(sys.argv[1]) if len(sys.argv)==2 else Path("/home/vencira/vencira-release-archives/pre-upgrade-82d5a9324f6141b67b5b55a7")
        if not base.is_absolute() or base.is_symlink() or not base.is_dir() or base.stat().st_uid!=os.getuid() or base.stat().st_mode & 0o077:
            mark("ARCHIVE_PERMISSIONS","FAIL");return 2
        for fn in ("images.manifest","images.tar.gz","images.tar.gz.sha256"):
            f=base/fn
            if not f.is_file() or f.is_symlink() or f.stat().st_mode & 0o077:
                mark("ARCHIVE_FILE_PERMISSIONS","FAIL");return 2
        # Check the complete tar checksum from the archive directory.
        integrity=subprocess.run(["sha256sum","--status","-c","images.tar.gz.sha256"],
            cwd=str(base),stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,timeout=180,check=False)
        if integrity.returncode!=0:
            mark("ARCHIVE_SHA256","FAIL");return 3
        mark("ARCHIVE_SHA256","PASS")
        d=safe_run(["python3",str(repo/"scripts/main_d3b3_verify_archived_images_offline.py"),str(base)],180)
        marks=dict(re.findall(r"(?m)^D3B3_([A-Z0-9_]+)=([A-Z0-9_]+)$",d.stdout))
        mark("ARCHIVE_CONFIG_HASH_INTEGRITY",marks.get("CONFIG_HASH","NOT_FAILED") if "CONFIG_HASH" in marks else ("PASS" if marks.get("ARCHIVE_CHECKSUM")=="PASS" else "NOT_VERIFIED"))
        mark("ARCHIVE_MANIFEST_IMAGE_ID_MATCH","PASS" if marks.get("DOCKER_IMAGE_ID_EQ_CONFIG_DIGEST")=="PASS" else "UNRESOLVED")
        for role in ("API","DB","WEB"):
            mark("CONFIG_ID_"+role+"_MATCH",marks.get("EXPECTED_"+role+"_CONFIG_ID_MATCH","UNKNOWN"))
        mark("ARCHIVE_OFFLINE_CHECK_RESULT",str(d.returncode))
        # D3-B4 compares rootfs/platform and runtime config fields; suppress
        # all raw Docker data, IDs, filepaths and exit traceback.
        d=safe_run(["python3",str(repo/"scripts/main_d3b4_archive_vs_running_metadata_readonly.py"),str(base)],180)
        marks=dict(re.findall(r"(?m)^D3B4_([A-Z0-9_]+)=([A-Z0-9_]+)$",d.stdout))
        mark("ARCHIVE_ROOTFS_CHECK_RESULT",str(d.returncode))
        for role in ("API","DB","WEB"):
            for field in ("ROOTFS_PLATFORM_MATCH_COUNT","RUNTIME_FIELDS_COMPARED","RUNTIME_FIELDS_DIFFERENT"):
                mark(role+"_"+field,marks.get("EXPECTED_"+role+"_"+field,"UNKNOWN"))
        # Do not print IPs or DNS records. DNS failure can explain curl error 6.
        try:
            answers=socket.getaddrinfo("vencira.es",443,type=socket.SOCK_STREAM)
            mark("APEX_DNS_RESOLVES","YES" if answers else "NO")
        except socket.gaierror:
            mark("APEX_DNS_RESOLVES","NO")
        # No -k, no HTTP POST, no headers/body output.
        curl=safe_run(["curl","--noproxy","*","--proto","=https","--tlsv1.2",
            "--silent","--show-error","--connect-timeout","8","--max-time","20",
            "--output","/dev/null","--write-out","%{http_code} %{ssl_verify_result}",
            "https://vencira.es/"],35)
        pieces=curl.stdout.strip().split()
        status=pieces[0] if len(pieces)==2 and re.fullmatch(r"[0-9]{3}",pieces[0]) else "UNKNOWN"
        tls=pieces[1] if len(pieces)==2 and re.fullmatch(r"[0-9]+",pieces[1]) else "UNKNOWN"
        mark("APEX_CURL_EXIT",str(curl.returncode))
        mark("APEX_HTTP_STATUS",status)
        mark("APEX_TLS_VERIFY_CODE",tls)
        cls={0:"TRANSPORT_OK",6:"DNS_FAILURE",7:"TCP_CONNECT_FAILURE",
            28:"TIMEOUT",35:"TLS_HANDSHAKE_FAILURE",51:"CERT_VERIFY_FAILURE",
            60:"CERT_VERIFY_FAILURE",52:"EMPTY_RESPONSE",56:"NETWORK_READ_FAILURE",
            47:"TOO_MANY_REDIRECTS"}.get(curl.returncode,"OTHER_FAILURE")
        mark("APEX_TRANSPORT_CLASS",cls)
        mark("APEX_HTTPS_ACCEPTED","YES" if curl.returncode==0 and status in
             ("200","301","302","303","307","308") else "NO")
        mark("APEX_APPLICATION_CSRF_COOKIES_VERIFIED","NO")
        mark("ARCHIVED_IMAGES_RECOVERY_VERIFIED","NO")
        mark("OFF_HOST_ENCRYPTED_CUSTODY_VERIFIED","NO")
        mark("RELEASE_AUTHORIZED","NO")
        mark("RESULT","4")
        return 4
    except (OSError,subprocess.TimeoutExpired,ValueError):
        mark("DIAGNOSTIC","FAILED")
        mark("RESULT","3")
        return 3
if __name__=="__main__":
    sys.exit(main())
