#!/usr/bin/env bash
set -euo pipefail
WORKSPACE="/home/kavia/workspace/code-generation/uttar-pradesh-tourism-infrastructure-management-system-220373-220382/spring_backend"
cd "$WORKSPACE"
M2_DIR="$WORKSPACE/.m2"; mkdir -p "$M2_DIR" "$WORKSPACE/tmp"
LOG="$WORKSPACE/app.log"
# prefer spring-boot:run (backgrounded); if that fails, run executable jar
if mvn -q -DskipTests -Dmaven.repo.local="$M2_DIR" spring-boot:run &>/dev/null & then
  APP_PID=$!
  PGID=$(ps -o pgid= "$APP_PID" | tr -d ' ' || true)
  echo "$APP_PID:$PGID" > "$WORKSPACE/tmp/app.pid"
else
  JAR=$(ls target/*-SNAPSHOT.jar target/*.jar 2>/dev/null | grep -v 'original' | head -n1 || true)
  if [ -z "$JAR" ]; then echo 'no jar to run' >&2; exit 22; fi
  setsid java -jar "$JAR" >"$LOG" 2>&1 &
  APP_PID=$!
  PGID=$(ps -o pgid= "$APP_PID" | tr -d ' ' || true)
  echo "$APP_PID:$PGID" > "$WORKSPACE/tmp/app.pid"
fi
sleep 0.5
echo "started app pid=$APP_PID pgid=$PGID"
