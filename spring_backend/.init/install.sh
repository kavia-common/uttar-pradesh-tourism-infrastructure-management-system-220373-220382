#!/usr/bin/env bash
set -euo pipefail
WORKSPACE="/home/kavia/workspace/code-generation/uttar-pradesh-tourism-infrastructure-management-system-220373-220382/spring_backend"
export DEBIAN_FRONTEND=noninteractive
# ensure workspace dirs
sudo mkdir -p "$WORKSPACE" "$WORKSPACE/data" "$WORKSPACE/tmp"
sudo chmod 0755 "$WORKSPACE"
# detect java and version (numeric major) using python3 for robustness
JAVA_BIN=$(command -v java || true)
JAVA_OK=0
JAVA_HOME_PATH=""
if [ -n "$JAVA_BIN" ]; then
  JAVA_VER_MAJOR=$(python3 - <<'PY'
import subprocess,re,sys
try:
  p=subprocess.run(["java","--version"], capture_output=True, text=True)
  s=p.stdout.splitlines()[0] if p.stdout else p.stderr.splitlines()[0]
  m=re.search(r"(\d+)(?:[.\d]*)", s)
  print(m.group(1) if m else "0")
except Exception:
  print("0")
PY
) || JAVA_VER_MAJOR=0
  if [ "$JAVA_VER_MAJOR" -ge 17 ]; then JAVA_OK=1; fi
fi
# choose package installs only if missing or insufficient
PKGS=()
[ "$JAVA_OK" -eq 0 ] && PKGS+=(openjdk-17-jdk)
if ! command -v mvn >/dev/null 2>&1; then PKGS+=(maven); fi
if [ "${#PKGS[@]}" -gt 0 ]; then sudo apt-get update -q && sudo apt-get install -y -qq "${PKGS[@]}" >/dev/null; fi
# resolve JAVA_HOME: prefer update-java-alternatives if available, else search /usr/lib/jvm for >=17
if command -v update-java-alternatives >/dev/null 2>&1; then
  CAND=$(update-java-alternatives -l 2>/dev/null | awk '{print $3;exit}') || CAND=""
  if [ -n "$CAND" ] && [ -x "$CAND/bin/java" ]; then JAVA_HOME_PATH="$CAND"; fi
fi
if [ -z "$JAVA_HOME_PATH" ]; then
  for d in /usr/lib/jvm/java-*-openjdk-* /usr/lib/jvm/java-*; do
    [ -d "$d" ] || continue
    if [ -x "$d/bin/java" ] && "$d/bin/java" --version >/dev/null 2>&1; then
      MAJ=$("$d/bin/java" --version 2>&1 | head -n1 | sed -n 's/[^0-9]*\([0-9]\+\).*/\1/p') || MAJ=0
      if [ "$MAJ" -ge 17 ]; then JAVA_HOME_PATH="$d"; break; fi
    fi
  done
fi
if [ -z "$JAVA_HOME_PATH" ] && [ -n "$JAVA_BIN" ]; then
  JAVA_HOME_PATH=$(cd "$(dirname "$JAVA_BIN")/.." && pwd -P)
fi
if [ -z "$JAVA_HOME_PATH" ]; then echo 'ERROR: JAVA_HOME not resolved or Java<17' >&2; exit 11; fi
# write /etc/profile.d entry safely (no variable expansion at write time)
PROFILE=/etc/profile.d/spring_env.sh
sudo tee "$PROFILE" > /dev/null <<'EOF'
# Spring dev environment persisted by automated setup
export JAVA_HOME=${JAVA_HOME_PATH}
export MAVEN_HOME=/usr/share/maven
export PATH="${JAVA_HOME_PATH}/bin:/usr/share/maven/bin:":"\$PATH"
EOF
sudo chmod 0644 "$PROFILE"
# source for current run
# shellcheck disable=SC1091
. "$PROFILE" || true
# validate
command -v java >/dev/null 2>&1 || { echo 'java not on PATH' >&2; exit 12; }
JAVA_VER_MAJOR=$(python3 - <<'PY'
import subprocess,re
p=subprocess.run(["java","--version"], capture_output=True, text=True)
s=p.stdout.splitlines()[0] if p.stdout else p.stderr.splitlines()[0]
m=re.search(r"(\d+)(?:[.\d]*)", s)
print(int(m.group(1)) if m else 0)
PY
)
if [ "$JAVA_VER_MAJOR" -lt 17 ]; then echo "java version $JAVA_VER_MAJOR < 17" >&2; exit 13; fi
command -v mvn >/dev/null 2>&1 || { echo 'mvn not on PATH' >&2; exit 14; }
mvn -v | sed -n '1p'
# ensure workspace writable for current user
CURUID=$(id -u); CURGID=$(id -g)
OWNER_UID=$(stat -c %u "$WORKSPACE" 2>/dev/null || echo "$CURUID")
if [ "$OWNER_UID" -ne "$CURUID" ]; then sudo chown "$CURUID:$CURGID" "$WORKSPACE" || true; fi
umask 0022
