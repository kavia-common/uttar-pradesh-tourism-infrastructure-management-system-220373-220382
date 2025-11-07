# Init Scripts Guide

This directory contains helper scripts for local CI-like operations of the Spring Boot backend.

Scripts:
- install.sh: Installs Java 17+ and Maven if missing, and sets JAVA_HOME for current session. Exits with clear messages if requirements are not met.
- build.sh: Builds the project with Maven using a workspace-local repository (`.m2`).
- start.sh: Attempts to run the app via `spring-boot:run` or falls back to the packaged jar. Writes PID/PGID to `tmp/app.pid`.
- test.sh: Ensures a trivial JUnit test exists and runs `mvn test`.
- validation.sh: Builds the app, starts it, polls `/actuator/health` until it is `UP`, then cleans up.

All scripts:
- Use the correct shebang `#!/usr/bin/env bash`
- Enable strict mode: `set -euo pipefail`
- Use LF line endings
- Are executable

Usage:
```bash
# Optionally ensure toolchain
./.init/install.sh

# Build
./.init/build.sh

# Start (background)
./.init/start.sh

# Validate health endpoint
./.init/validation.sh

# Run tests
./.init/test.sh
```

Notes:
- PID/PGID are saved at `spring_backend/tmp/app.pid`. Use it to stop the process if needed:
  ```bash
  if [ -f tmp/app.pid ]; then
    IFS=: read -r APP_PID PGID < tmp/app.pid
    kill -TERM -- -"${PGID}" || true
  fi
  ```
