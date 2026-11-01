#!/usr/bin/env bash
cd "$(dirname "$0")" || exit 1
HERE="$(pwd)"
G=$'\033[92m'; Y=$'\033[93m'; R=$'\033[91m'; C=$'\033[96m'; W=$'\033[97m'; D=$'\033[90m'; X=$'\033[0m'

printf '\033[8;32;100t'   # nice default window size (ignored by terminals that cannot resize)
clear
printf '\n'
i=0
for color in 51 51 44 44 33 33; do
  case $i in
    0) row="██╗  ██╗ ██████╗  █████╗ ██╗  ██╗";;
    1) row="██║  ██║██╔═══██╗██╔══██╗╚██╗██╔╝";;
    2) row="███████║██║   ██║███████║ ╚███╔╝ ";;
    3) row="██╔══██║██║   ██║██╔══██║ ██╔██╗ ";;
    4) row="██║  ██║╚██████╔╝██║  ██║██╔╝ ██╗";;
    5) row="╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝";;
  esac
  printf '   \033[38;5;%sm%s\033[0m\n' "$color" "$row"; i=$((i+1))
done
printf '\n   %sF A K E   H A C K E D   P R A N K%s      %sv1.0%s\n' "$W" "$X" "$D" "$X"
printf '   %sA harmless joke: fake hack screen, then a fullscreen video.%s\n' "$D" "$X"

title() { printf '\n  %s%s%s\n  %s────────────────────────────────────────────────────────────────%s\n' "$C" "$1" "$X" "$D" "$X"; }
ok()   { printf '  %s■%s %s\n' "$G" "$X" "$1"; }
warn() { printf '  %s■%s %s\n' "$Y" "$X" "$1"; }
err()  { printf '  %s■%s %s\n' "$R" "$X" "$1"; }
ask()  { # label, default text, default value, variable
  printf '  %s»%s %-34s%sdefault: %s%s\n' "$C" "$X" "$1" "$D" "$2" "$X"
  printf '    %s►%s ' "$G" "$X"; read -r ans; printf -v "$4" '%s' "${ans:-$3}"
}

title "SETUP"
ask "Hacked by (name)"              "Hafiz Ibrahim" "Hafiz Ibrahim" PRANK_NAME
ask "Video link (YouTube or .mp4)"  "Rickroll"      "https://www.youtube.com/watch?v=dQw4w9WgXcQ" PRANK_VIDEO
ask "Port"                          "8080"          "8080" PRANK_PORT
ask "Public Cloudflare link? (Y/N)" "Y"             "y" PRANK_TUNNEL
case "$PRANK_PORT" in ''|*[!0-9]*) PRANK_PORT=8080;; esac
export PRANK_NAME PRANK_VIDEO PRANK_PORT HERE

PY="$(command -v python3 || command -v python)"
if [ -z "$PY" ] || ! "$PY" --version >/dev/null 2>&1; then
  err "python3 is needed (it comes with macOS and almost every Linux). Example: sudo apt install python3"; exit 1
fi

PY_PID=""; CF_PID=""
cleanup() { trap - INT TERM EXIT; [ -n "$CF_PID" ] && kill "$CF_PID" 2>/dev/null; [ -n "$PY_PID" ] && kill "$PY_PID" 2>/dev/null; echo; exit 0; }
trap cleanup INT TERM EXIT

title "LAUNCH"
# ---------- server (code is inside this file) ----------
"$PY" - <<'PYCODE' &
import os, re, json, html, datetime
from http.server import ThreadingHTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse, parse_qs

PORT  = int(os.environ["PRANK_PORT"])
NAME  = os.environ["PRANK_NAME"]
VIDEO = os.environ["PRANK_VIDEO"]

def parse_video(v):
    v = v.strip()
    if re.search(r"\.(mp4|webm|ogg)(\?.*)?$", v, re.I): return {"kind": "file", "src": v}
    m = re.search(r"(?:v=|youtu\.be/|embed/|shorts/)([\w-]{11})", v) or re.fullmatch(r"([\w-]{11})", v)
    return {"kind": "youtube", "id": m.group(1) if m else "dQw4w9WgXcQ"}

PAGE = open(os.path.join(os.environ["HERE"], "index.html"), encoding="utf-8").read()
PAGE = PAGE.replace("__NAME__", html.escape(NAME)).replace("__CONFIG__", json.dumps(parse_video(VIDEO)).replace("<", "\\u003c"))
PAGE = PAGE.encode("utf-8")

G, Y, C, W, D, X = "\033[92m", "\033[93m", "\033[96m", "\033[97m", "\033[90m", "\033[0m"
MSG = {
    "opened":  (Y, "opened the link"),
    "playing": (G, "is watching the video"),
    "ended":   (C, "watched the whole video"),
    "left":    (D, "left the page"),
}
visitors = {}   # random per-visit id -> Target number. No IPs or personal data are logged.

class H(BaseHTTPRequestHandler):
    def do_GET(self):
        if urlparse(self.path).path in ("/", "/index.html"):
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Cache-Control", "no-store")
            self.send_header("Content-Length", str(len(PAGE)))
            self.end_headers(); self.wfile.write(PAGE)
        else:
            self.send_error(404)
    def do_POST(self):
        u = urlparse(self.path)
        if u.path == "/event":
            q = parse_qs(u.query)
            m = MSG.get(q.get("e", [""])[0])
            if m:
                n = visitors.setdefault(q.get("id", ["?"])[0], len(visitors) + 1)
                print(f"  {D}{datetime.datetime.now():%H:%M:%S}{X}  {m[0]}►{X} {W}Target #{n}{X} {m[0]}{m[1]}{X}", flush=True)
        self.send_response(204); self.end_headers()
    def log_message(self, *a): pass

try:
    ThreadingHTTPServer(("0.0.0.0", PORT), H).serve_forever()
except OSError:
    print(f"  \033[91m■{X} Could not start on port {PORT} (already in use?). Try another port.", flush=True)
    raise SystemExit(1)
except KeyboardInterrupt:
    pass
PYCODE
PY_PID=$!
for _ in $(seq 1 40); do
  kill -0 "$PY_PID" 2>/dev/null || exit 1
  curl -s -o /dev/null "http://127.0.0.1:$PRANK_PORT/" && break
  sleep 0.25
done
ok "Server running on port $PRANK_PORT"

# ---------- cloudflared ----------
get_cloudflared() {
  if command -v cloudflared >/dev/null; then command -v cloudflared; return; fi
  if [ -x "$HERE/bin/cloudflared" ]; then echo "$HERE/bin/cloudflared"; return; fi
  mkdir -p "$HERE/bin"
  local os arch base="https://github.com/cloudflare/cloudflared/releases/latest/download"
  os="$(uname -s)"; arch="$(uname -m)"
  case "$arch" in x86_64|amd64) arch=amd64;; aarch64|arm64) arch=arm64;; armv*|arm) arch=arm;; i?86) arch=386;; esac
  warn "Downloading cloudflared (one time only)..." >&2
  if [ "$os" = "Darwin" ]; then
    curl -fsSL "$base/cloudflared-darwin-$arch.tgz" -o "$HERE/bin/cf.tgz" && tar -xzf "$HERE/bin/cf.tgz" -C "$HERE/bin" && rm -f "$HERE/bin/cf.tgz"
  else
    curl -fsSL "$base/cloudflared-linux-$arch" -o "$HERE/bin/cloudflared"
  fi
  chmod +x "$HERE/bin/cloudflared" 2>/dev/null
  [ -x "$HERE/bin/cloudflared" ] && echo "$HERE/bin/cloudflared"
}

LINK=""
case "$PRANK_TUNNEL" in n|N|no|NO|No) ;; *)
  CF="$(get_cloudflared)"
  if [ -n "$CF" ]; then
    CFLOG="$(mktemp)"
    "$CF" tunnel --url "http://127.0.0.1:$PRANK_PORT" --no-autoupdate >"$CFLOG" 2>&1 &
    CF_PID=$!
    sp='|/-\'; n=0
    for _ in $(seq 1 240); do
      printf '\r  %s%s Opening Cloudflare tunnel...%s' "$Y" "${sp:$((n%4)):1}" "$X"; n=$((n+1))
      LINK="$(grep -o 'https://[a-z0-9-]*\.trycloudflare\.com' "$CFLOG" 2>/dev/null | grep -v '^https://api\.' | head -1)"
      [ -n "$LINK" ] && break
      kill -0 "$CF_PID" 2>/dev/null || break
      sleep 0.25
    done
    printf '\r%*s\r' 50 ''
    if [ -n "$LINK" ]; then ok "Cloudflare tunnel ready"
    else
      err "Could not open the Cloudflare tunnel. Check your internet connection."
      tail -n 4 "$CFLOG" | sed "s/^/      ${D}/;s/\$/${X}/"
    fi
  else
    err "Could not download cloudflared. Continuing without the public link."
  fi;;
esac

# ---------- links ----------
title "LINKS"
[ -n "$LINK" ] && printf '    %sPublic   %s%s%s%s\n' "$D" "$X" "$C" "$LINK" "$X"
printf '    %sLocal    %s%s\n' "$D" "$X" "http://localhost:$PRANK_PORT"
IP="$(hostname -I 2>/dev/null | awk '{print $1}')"; [ -z "$IP" ] && IP="$(ipconfig getifaddr en0 2>/dev/null)"
[ -n "$IP" ] && printf '    %sWiFi     %s%s\n' "$D" "$X" "http://$IP:$PRANK_PORT"

title "LIVE ACTIVITY"
printf '  %sWaiting for targets...   (Ctrl + C to stop)%s\n\n' "$D" "$X"
wait "$PY_PID"
