#!/usr/bin/env bash
set -euo pipefail
WORKSPACE="/home/kavia/workspace/code-generation/uttar-pradesh-tourism-infrastructure-management-system-220373-220382/spring_backend"
export DEBIAN_FRONTEND=noninteractive

# ensure workspace dirs
sudo mkdir -p "$WORKSPACE" "$WORKSPACE/data" "$WORKSPACE/tmp"
sudo chmod 0755 "$WORKSPACE"

# detect java and version (numeric major) using pure bash
JAVA_BIN="$(command -v java || true)"
JAVA_OK=0
JAVA_VER_MAJOR=0
if [ -n "${JAVA_BIN}" ]; then
  # Parse major version from `java --version` first line
  VER_LINE="$("$JAVA_BIN" --version 2>&1 | head -n1 || true)"
  JAVA_VER_MAJOR="$(printf '%s\n' "$VER_LINE" | sed -n 's/[^0-9]*\([0-9]\+\).*/\1/p')"
  if [ -n "${JAVA_VER_MAJOR}" ] && [ "${JAVA_VER_MAJOR}" -ge 17 ] 2>/dev/null; then
    JAVA_OK=1
  fi
fi

# choose package installs only if missing or insufficient
PKGS=()
[ "$JAVA_OK" -eq 0 ] && PKGS+=(openjdk-17-jdk)
if ! command -v mvn >/dev/null 2>&1; then PKGS+=(maven); fi
if [ "${#PKGS[@]}" -gt 0 ]; then
  sudo apt-get update -q
  sudo apt-get install -y -qq "${PKGS[@]}" >/dev/null
fi

# resolve JAVA_HOME: prefer update-java-alternatives if available, else search /usr/lib/jvm for >=17
JAVA_HOME_PATH=""
if command -v update-java-alternatives >/dev/null 2>&1; then
  CAND="$(update-java-alternatives -l 2>/dev/null | awk '{print $3;exit}')"
  if [ -n "$CAND" ] && [ -x "$CAND/bin/java" ]; then JAVA_HOME_PATH="$CAND"; fi
fi
if [ -z "$JAVA_HOME_PATH" ]; then
  for d in /usr/lib/jvm/java-*-openjdk-* /usr/lib/jvm/java-* /usr/lib/jvm/*; do
    [ -d "$d" ] || continue
    if [ -x "$d/bin/java" ]; then
      MAJ="$("$d/bin/java" --version 2>&1 | head -n1 | sed -n 's/[^0-9]*\([0-9]\+\).*/\1/p')"
      if [ -n "$MAJ" ] && [ "$MAJ" -ge 17 ] 2>/dev/null; then JAVA_HOME_PATH="$d"; break; fi
    fi
  done
fi
if [ -z "$JAVA_HOME_PATH" ]; then
  JAVA_BIN="$(command -v java || true)"
  if [ -n "$JAVA_BIN" ]; then JAVA_HOME_PATH="$(cd "$(dirname "$JAVA_BIN")/.." && pwd -P)"; fi
fi
if [ -z "$JAVA_HOME_PATH" ]; then echo 'ERROR: JAVA_HOME not resolved or Java<17' >&2; exit 11; fi

# write /etc/profile.d entry safely (no variable expansion at write time)
PROFILE=/etc/profile.d/spring_env.sh
sudo tee "$PROFILE" > /dev/null <<'EOF'
# Spring dev environment persisted by automated setup
# Values will be replaced below via sed
export JAVA_HOME=__JAVA_HOME_PLACEHOLDER__
export MAVEN_HOME=/usr/share/maven
export PATH="__JAVA_HOME_PLACEHOLDER__/bin:/usr/share/maven/bin:$PATH"
EOF
sudo chmod 0644 "$PROFILE"
# Replace placeholder with actual JAVA_HOME_PATH
sudo sed -i "s#__JAVA_HOME_PLACEHOLDER__#${JAVA_HOME_PATH}#g" "$PROFILE"

# source for current run
# shellcheck disable=SC1091
. "$PROFILE" || true

# validate java and maven
command -v java >/dev/null 2>&1 || { echo 'java not on PATH' >&2; exit 12; }
VER_LINE="$(java --version 2>&1 | head -n1 || true)"
JAVA_VER_MAJOR="$(printf '%s\n' "$VER_LINE" | sed -n 's/[^0-9]*\([0-9]\+\).*/\1/p')"
if [ -z "$JAVA_VER_MAJOR" ] || [ "$JAVA_VER_MAJOR" -lt 17 ] 2>/dev/null; then
  echo "java version ${JAVA_VER_MAJOR:-unknown} < 17" >&2
  exit 13
fi
command -v mvn >/dev/null 2>&1 || { echo 'mvn not on PATH' >&2; exit 14; }
mvn -v | sed -n '1p'

# ensure workspace writable for current user
CURUID=$(id -u); CURGID=$(id -g)
OWNER_UID=$(stat -c %u "$WORKSPACE" 2>/dev/null || echo "$CURUID")
if [ "$OWNER_UID" -ne "$CURUID" ]; then sudo chown "$CURUID:$CURGID" "$WORKSPACE" || true; fi
umask 0022
