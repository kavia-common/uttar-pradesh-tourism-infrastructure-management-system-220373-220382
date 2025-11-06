#!/usr/bin/env bash
set -euo pipefail
WORKSPACE="/home/kavia/workspace/code-generation/uttar-pradesh-tourism-infrastructure-management-system-220373-220382/spring_backend"
cd "$WORKSPACE"
command -v java >/dev/null 2>&1 || { echo 'java missing' >&2; exit 40; }
M2_DIR="$WORKSPACE/.m2"; mkdir -p "$M2_DIR" "$WORKSPACE/tmp"
# ensure build present
mvn -B -T1 -Dmaven.repo.local="$M2_DIR" -DskipTests package || { echo 'build failed' >&2; exit 41; }
LOG="$WORKSPACE/app.log"
HEALTH_JSON="$WORKSPACE/tmp/health.json"
CLEANED=0
APP_PID=""
PGID=""
cleanup(){ if [ "$CLEANED" -ne 0 ]; then return; fi; CLEANED=1; if [ -n "$PGID" ]; then if kill -0 -"$PGID" 2>/dev/null; then kill -TERM -- -"$PGID" 2>/dev/null || true; sleep 2; kill -0 -"$PGID" 2>/dev/null && kill -KILL -- -"$PGID" 2>/dev/null || true; fi; fi; if [ -n "$APP_PID" ] && kill -0 "$APP_PID" 2>/dev/null; then kill -TERM "$APP_PID" 2>/dev/null || true; sleep 1; kill -0 "$APP_PID" 2>/dev/null && kill -KILL "$APP_PID" 2>/dev/null || true; fi }
trap 'cleanup || true' EXIT
# prefer spring-boot:run
if mvn -q -DskipTests -Dmaven.repo.local="$M2_DIR" spring-boot:run &>/dev/null & then
  APP_PID=$!
  PGID=$(ps -o pgid= "$APP_PID" | tr -d ' ' || true)
else
  JAR=$(ls target/*-SNAPSHOT.jar target/*.jar 2>/dev/null | grep -v 'original' | head -n1 || true)
  if [ -z "$JAR" ]; then echo 'no jar to run' >&2; cleanup; exit 42; fi
  setsid java -jar "$JAR" >"$LOG" 2>&1 &
  APP_PID=$!
  PGID=$(ps -o pgid= "$APP_PID" | tr -d ' ' || true)
fi
URL="http://127.0.0.1:8080/actuator/health"
RETRIES=60; SLEEP=1; i=0; READY=0
while [ $i -lt $RETRIES ]; do
  if curl -sS --fail "$URL" >"$HEALTH_JSON" 2>/dev/null; then
    STATUS=$(python3 - <<PY
import json,sys
try:
  r=json.load(open('$HEALTH_JSON'))
  print(r.get('status',''))
except Exception:
  print('')
PY
)
    if [ "$STATUS" = "UP" ]; then READY=1; break; fi
  fi
  sleep $SLEEP
  i=$((i+1))
  if [ $i -eq 10 ]; then SLEEP=2; fi
  if [ $i -eq 30 ]; then SLEEP=3; fi
done
if [ "$READY" -eq 1 ]; then
  echo "validation: health=UP"
  ls -la "$WORKSPACE"/data || true
  cleanup; trap - EXIT; exit 0
else
  echo "validation failed: health endpoint not UP" >&2
  echo "--- last 200 lines of app log ---" >&2
  tail -n 200 "$LOG" >&2 || true
  cleanup; trap - EXIT; exit 50
fi
