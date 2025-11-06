#!/usr/bin/env bash
set -euo pipefail
WORKSPACE="/home/kavia/workspace/code-generation/uttar-pradesh-tourism-infrastructure-management-system-220373-220382/spring_backend"
cd "$WORKSPACE"
M2_DIR="$WORKSPACE/.m2"; mkdir -p "$M2_DIR" "$WORKSPACE/tmp"
command -v mvn >/dev/null 2>&1 || { echo 'mvn missing' >&2; exit 20; }
# package non-interactively into workspace-local repo
mvn -B -T1 -Dmaven.repo.local="$M2_DIR" -DskipTests package
