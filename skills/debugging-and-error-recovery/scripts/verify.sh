#!/bin/bash
set -e

PROJECT_DIR="."
TMPDIR_PREFIX="/tmp/dbg-verify-"

cleanup() {
  if [ -d "$TMPDIR" ]; then
    rm -rf "$TMPDIR"
  fi
}
trap cleanup EXIT

TMPDIR=$(mktemp -d "${TMPDIR_PREFIX}XXXXXX")

while [[ $# -gt 0 ]]; do
  case $1 in
    --project-dir)
      PROJECT_DIR="$2"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

if [ ! -d "$PROJECT_DIR" ]; then
  echo "Project directory does not exist: $PROJECT_DIR" >&2
  exit 1
fi

check_error_handling_patterns() {
  local status="fail"
  local detail="No structured error handling patterns found"
  local found=()

  if find "$PROJECT_DIR/src" -type f \( -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" \) -exec grep -lE '(try\s*\{|\.catch\(|ErrorBoundary|error\.message|error instanceof|throw new)' {} \; 2>/dev/null | head -5 | grep -q .; then
    found+=("try-catch/error-class")
  fi

  if find "$PROJECT_DIR/src" -type f \( -name "*.py" \) -exec grep -lE '(except\s+\w+Error|raise\s+\w+Error|try:)' {} \; 2>/dev/null | head -5 | grep -q .; then
    found+=("python-exceptions")
  fi

  if find "$PROJECT_DIR/src" -type f \( -name "*.go" \) -exec grep -lE '(errors\.|fmt\.Errorf|panic\(|recover\(\))' {} \; 2>/dev/null | head -5 | grep -q .; then
    found+=("go-errors")
  fi

  if [ ${#found[@]} -gt 0 ]; then
    status="pass"
    detail="Error handling patterns found: ${found[*]}"
  fi

  echo "{\"name\":\"error_handling_patterns\",\"status\":\"$status\",\"detail\":\"$detail\"}"
}

check_regression_tests() {
  local status="fail"
  local detail="No regression test files found"
  local count=0

  for dir in "$PROJECT_DIR/src" "$PROJECT_DIR/tests" "$PROJECT_DIR/test" "$PROJECT_DIR/__tests__" "$PROJECT_DIR/e2e"; do
    if [ -d "$dir" ]; then
      local found
      found=$(find "$dir" -type f \( -name "*.spec.ts" -o -name "*.spec.js" -o -name "*.test.ts" -o -name "*.test.tsx" -o -name "*.test.js" -o -name "*.test.py" -o -name "test_*.py" -o -name "*_test.go" \) 2>/dev/null | wc -l)
      count=$((count + found))
    fi
  done

  if [ "$count" -gt 0 ]; then
    status="pass"
    detail="Found $count test file(s) covering regression scenarios"
  fi

  echo "{\"name\":\"regression_tests\",\"status\":\"$status\",\"detail\":\"$detail\"}"
}

check_error_boundaries() {
  local status="fail"
  local detail="No error boundary components found"
  local found=()

  for dir in "$PROJECT_DIR/src" "$PROJECT_DIR/app" "$PROJECT_DIR/lib" "$PROJECT_DIR/components"; do
    if [ -d "$dir" ]; then
      while IFS= read -r file; do
        found+=("$file")
      done < <(find "$dir" -type f \( -name "*.tsx" -o -name "*.jsx" \) -exec grep -lE '(ErrorBoundary|componentDidCatch|errorboundary)' {} \; 2>/dev/null | head -5)
    fi
  done

  if [ ${#found[@]} -gt 0 ]; then
    status="pass"
    detail="Error boundary component(s) found: ${#found[@]} file(s)"
  fi

  echo "{\"name\":\"error_boundary_components\",\"status\":\"$status\",\"detail\":\"$detail\"}"
}

check_structured_logging() {
  local status="fail"
  local detail="No structured error logging found"
  local patterns=()

  for dir in "$PROJECT_DIR/src" "$PROJECT_DIR/lib" "$PROJECT_DIR/app" "$PROJECT_DIR/pkg"; do
    if [ -d "$dir" ]; then
      if find "$dir" -type f \( -name "*.ts" -o -name "*.js" -o -name "*.py" -o -name "*.go" \) -exec grep -lE '(logger\.(error|warn)|logging\.(error|warning)|log\.Error|console\.error|slog\.(Error|Warn)|pino|winston|bunyan)' {} \; 2>/dev/null | head -3 | grep -q .; then
        patterns+=("structured-logging")
        break
      fi
    fi
  done

  for f in "$PROJECT_DIR/src/lib/logger.ts" "$PROJECT_DIR/src/lib/logger.js" "$PROJECT_DIR/src/utils/logger.ts" "$PROJECT_DIR/src/utils/logger.js" "$PROJECT_DIR/src/logger.py" "$PROJECT_DIR/src/logging.py"; do
    if [ -f "$PROJECT_DIR/$f" ] || [ -f "$f" ]; then
      patterns+=("dedicated-logger-module")
      break
    fi
  done

  if [ ${#patterns[@]} -gt 0 ]; then
    status="pass"
    detail="Structured logging found: ${patterns[*]}"
  fi

  echo "{\"name\":\"structured_error_logging\",\"status\":\"$status\",\"detail\":\"$detail\"}"
}

check_build_success() {
  local status="fail"
  local detail="No build system detected"

  if [ -f "$PROJECT_DIR/package.json" ]; then
    if grep -q '"build"' "$PROJECT_DIR/package.json" 2>/dev/null; then
      if [ -d "$PROJECT_DIR/node_modules" ]; then
        detail="Build script found in package.json (run npm run build to verify)"
      else
        detail="Build script found but node_modules missing (run npm install first)"
      fi
    else
      detail="No build script found in package.json"
    fi
  elif [ -f "$PROJECT_DIR/Makefile" ] || [ -f "$PROJECT_DIR/pyproject.toml" ]; then
    status="pass"
    detail="Build system found (Makefile/pyproject.toml)"
  else
    detail="No build system detected"
  fi

  echo "{\"name\":\"build_system\",\"status\":\"$status\",\"detail\":\"$detail\"}"
}

echo "Checking debugging and error recovery readiness..." >&2

C1=$(check_error_handling_patterns)
C2=$(check_regression_tests)
C3=$(check_error_boundaries)
C4=$(check_structured_logging)
C5=$(check_build_success)

CHECKS="[$C1,$C2,$C3,$C4,$C5]"

OVERALL=$(echo "$CHECKS" | python3 -c "import sys,json; checks=json.load(sys.stdin); fail=len([c for c in checks if c['status']=='fail']); print('pass' if fail==0 else ('partial' if fail<len(checks) else 'fail'))" 2>/dev/null || echo "partial")

echo "{\"skill\":\"debugging-and-error-recovery\",\"status\":\"$OVERALL\",\"checks\":$CHECKS}"