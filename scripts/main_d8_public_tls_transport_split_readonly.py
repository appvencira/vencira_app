#!/usr/bin/env python3
"""D8: private, non-mutating public TLS split and image-identity disposition."""
import os
import re
import socket
import subprocess
import sys
from pathlib import Path

def mark(key, value):
    print(f"D8_{key}={value}", flush=True)

def run(args, timeout=25, cwd=None):
    try:
        return subprocess.run(args, cwd=cwd, stdin=subprocess.DEVNULL,
                              stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                              text=True, timeout=timeout, check=False)
    except (OSError, subprocess.TimeoutExpired):
        return None

def tls_class(rc, err):
    if rc == 0: return "TRANSPORT_OK"
    text = (err or "").lower()
    if rc == 6: return "DNS_FAILURE"
    if rc == 7: return "TCP_CONNECT_FAILURE"
    if rc == 28: return "TIMEOUT"
    if rc == 60: return "CERTIFICATE_VALIDATION_FAILURE"
    if rc == 35:
        if "wrong version number" in text: return "TLS_WRONG_VERSION"
        if "handshake failure" in text: return "TLS_HANDSHAKE_REJECTED"
        if "protocol version" in text: return "TLS_PROTOCOL_VERSION"
        if "unexpected eof" in text or "eof while reading" in text: return "TLS_PEER_EOF"
        if "connection reset" in text: return "TLS_PEER_RESET"
        if "no peer certificate" in text: return "TLS_PEER_NO_CERTIFICATE"
        return "TLS_HANDSHAKE_OTHER"
    return "OTHER"

def dns_family(host, family):
    try:
        return bool(socket.getaddrinfo(host, 443, family, socket.SOCK_STREAM))
    except (socket.gaierror, OSError):
        return False

def inspect_host(host, prefix):
    mark(prefix+"_DNS_IPV4", "YES" if dns_family(host,socket.AF_INET) else "NO")
    mark(prefix+"_DNS_IPV6", "YES" if dns_family(host,socket.AF_INET6) else "NO")
    # Does not follow redirects, send credentials or print response contents.
    for flag,label in (("-4","IPV4"),("-6","IPV6")):
        p=run(["curl","--noproxy","*","--proto","=https",flag,
               "--tlsv1.2","--silent","--show-error",
               "--connect-timeout","6","--max-time","16",
               "--output","/dev/null",
               "--write-out","%{http_code} %{ssl_verify_result}",
               "https://"+host+"/"],timeout=23)
        if p is None:
            mark(prefix+"_"+label+"_CURL_EXIT","TIMEOUT_OR_UNAVAILABLE")
            mark(prefix+"_"+label+"_TLS_CLASS","NO_RESULT")
            continue
        pieces=p.stdout.strip().split()
        code=pieces[0] if len(pieces)==2 and re.fullmatch(r"[0-9]{3}",pieces[0]) else "UNKNOWN"
        verify=pieces[1] if len(pieces)==2 and re.fullmatch(r"[0-9]+",pieces[1]) else "UNKNOWN"
        mark(prefix+"_"+label+"_CURL_EXIT",str(p.returncode))
        mark(prefix+"_"+label+"_HTTP_STATUS",code)
        mark(prefix+"_"+label+"_TLS_VERIFY_CODE",verify)
        mark(prefix+"_"+label+"_TLS_CLASS",tls_class(p.returncode,p.stderr))
    # Probe TLS without printing certificate, negotiated secrets or targets.
    for version,label in (("-tls1_2","TLS12"),("-tls1_3","TLS13")):
        p=run(["openssl","s_client","-connect",host+":443","-servername",host,
               "-brief",version],timeout=17)
        if p is None:
            mark(prefix+"_"+label+"_OPENSSL","NO_RESULT")
            continue
        output=(p.stdout+"\n"+p.stderr).lower()
        established=(p.returncode==0 and
                     ("protocol version:" in output or "protocol  :" in output or
                      "ciphersuite:" in output or "cipher    :" in output))
        if established:
            category="HANDSHAKE_OK"
        elif "connection refused" in output: category="TCP_REFUSED"
        elif "wrong version number" in output: category="WRONG_VERSION"
        elif "unexpected eof" in output: category="PEER_EOF"
        elif "alert handshake failure" in output: category="HANDSHAKE_ALERT"
        elif "connection reset" in output: category="PEER_RESET"
        elif "no route" in output or "network is unreachable" in output: category="NETWORK_UNREACHABLE"
        elif "name or service not known" in output: category="DNS_FAILURE"
        else: category="OTHER_OR_UNCLASSIFIED"
        mark(prefix+"_"+label+"_OPENSSL",category)

def main():
    print("MFA_RELEASE_AUTHORIZED=NO")
    print("NO_DEPLOY_NO_LIVE_MIGRATION=1")
    for k in ("DEPLOY_EXECUTED","LIVE_MIGRATIONS_EXECUTED","LIVE_RESTORE_EXECUTED",
              "HOST_DOCKER_IMAGE_LOAD_EXECUTED","CONTAINER_RUN_EXECUTED",
              "CADDY_RELOAD_EXECUTED","CADDY_CONFIG_CHANGED",
              "O5_CREDENTIALS_ACCESSED","OPERATIONAL_ROLLBACK_EXECUTED"):
        mark(k,"NO")
    if os.geteuid()==0:
        mark("ROOTLESS_EXECUTION","FAIL")
        mark("RESULT",2)
        return 2
    for cmd in ("git","curl","openssl"):
        if run(["sh","-c","command -v "+cmd],timeout=5) is None:
            mark("PREREQUISITE","FAIL");mark("RESULT",2);return 2
    repo=Path(__file__).resolve().parent.parent
    a=run(["git","rev-parse","HEAD"],cwd=repo)
    b=run(["git","rev-parse","refs/remotes/origin/main"],cwd=repo)
    c=run(["git","status","--porcelain"],cwd=repo)
    if any(p is None or p.returncode!=0 for p in (a,b,c)) or a.stdout!=b.stdout or c.stdout.strip():
        mark("MAIN_CLEAN","FAIL");mark("RESULT",2);return 2
    mark("MAIN_CLEAN","PASS")
    inspect_host("dev.vencira.es","DEV")
    inspect_host("vencira.es","APEX")
    mark("D7_CONFIG_SHA256_INTEGRITY","PASS_RECORDED")
    mark("D7_IMAGE_CONFIG_IDS","ALL_THREE_MISMATCH_RECORDED")
    mark("D7_IMAGE_UNIQUE_ROOTFS_PLATFORM","THREE_MATCHES_RECORDED")
    mark("ARCHIVE_EXACT_IDENTITY_VERIFIED","NO")
    mark("PUBLIC_CADDY_CONFIG_AND_CSRF_VERIFIED","NO")
    mark("OFF_HOST_ENCRYPTED_CUSTODY_VERIFIED","NO")
    mark("ANDROID_FINAL_RELEASE_VERIFIED","NO")
    mark("PUBLIC_RELEASE_AUTHORIZED","NO")
    mark("RELEASE_READINESS","BLOCKED")
    mark("RESULT",4)
    return 4

if __name__=="__main__":
    sys.exit(main())
