#!/usr/bin/env bash
set -euo pipefail
WORKSPACE="/home/kavia/workspace/code-generation/uttar-pradesh-tourism-infrastructure-management-system-220373-220382/spring_backend"
cd "$WORKSPACE"
M2_DIR="$WORKSPACE/.m2"; mkdir -p "$M2_DIR" "$WORKSPACE/tmp"
command -v mvn >/dev/null 2>&1 || { echo 'mvn missing' >&2; exit 30; }
# create a trivial JUnit5 test if missing
TESTDIR="$WORKSPACE/src/test/java/com/example/demo"
if [ ! -f "$TESTDIR/SanityTest.java" ]; then
  mkdir -p "$TESTDIR"
  cat > "$TESTDIR/SanityTest.java" <<'EOF'
package com.example.demo;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.assertTrue;
public class SanityTest { @Test void ok(){ assertTrue(true); } }
EOF
fi
mvn -B -T1 -Dmaven.repo.local="$M2_DIR" test
