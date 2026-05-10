#!/bin/bash
set -e

PROJECT_DIR="."
TMPDIR_PREFIX="/tmp/bt-verify-"

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

CHECKS="[]"

check_browser_test_config() {
  local status="fail"
  local detail="No browser test configuration found"
  local found=""

  for f in playwright.config.ts playwright.config.js playwright.config.mts \
           cypress.config.ts cypress.config.js cypress.json \
           puppeteer.config.ts puppeteer.config.js \
           jest.config.ts jest.config.js jest.config.mjs; do
    if [ -f "$PROJECT_DIR/$f" ]; then
      found="$f"
      break
    fi
  done

  if [ -n "$found" ]; then
    status="pass"
    detail="Found browser test config: $found"
  fi

  echo "{\"name\":\"browser_test_config\",\"status\":\"$status\",\"detail\":\"$detail\"}"
}

check_test_runner_setup() {
  local status="fail"
  local detail="No browser test runner dependency found"
  local runners=""

  if [ -f "$PROJECT_DIR/package.json" ]; then
    if grep -qE '"(playwright|@playwright/test)"' "$PROJECT_DIR/package.json" 2>/dev/null; then
      runners="playwright"
    fi
    if grep -qE '"cypress"' "$PROJECT_DIR/package.json" 2>/dev/null; then
      if [ -n "$runners" ]; then
        runners="$runners, cypress"
      else
        runners="cypress"
      fi
    fi
    if grep -qE '"(puppeteer|@puppeteer)"' "$PROJECT_DIR/package.json" 2>/dev/null; then
      if [ -n "$runners" ]; then
        runners="$runners, puppeteer"
      else
        runners="puppeteer"
      fi
    fi
  fi

  if [ -f "$PROJECT_DIR/requirements.txt" ]; then
    if grep -qE 'selenium|playwright|pytest-playwright' "$PROJECT_DIR/requirements.txt" 2>/dev/null; then
      if [ -n "$runners" ]; then
        runners="$runners, python-playwright/selenium"
      else
        runners="python-playwright/selenium"
      fi
    fi
  fi

  if [ -n "$runners" ]; then
    status="pass"
    detail="Browser test runner(s): $runners"
  fi

  echo "{\"name\":\"test_runner_setup\",\"status\":\"$status\",\"detail\":\"$detail\"}"
}

check_browser_test_files() {
  local status="fail"
  local detail="No browser test files found"
  local count=0

  local search_dirs="$PROJECT_DIR/e2e $PROJECT_DIR/tests $PROJECT_DIR/test $PROJECT_DIR/cypress $PROJECT_DIR/__tests__ $PROJECT_DIR/spec $PROJECT_DIR/src"

  for dir in $search_dirs; do
    if [ -d "$dir" ]; then
      local found
      found=$(find "$dir" -type f \( -name "*.spec.ts" -o -name "*.spec.js" -o -name "*.test.ts" -o -name "*.test.js" -o -name "*.cy.ts" -o -name "*.cy.js" \) 2>/dev/null | head -20 | wc -l)
      count=$((count + found))
    fi
  done

  if [ "$count" -gt 0 ]; then
    status="pass"
    detail="Found $count browser test file(s)"
  fi

  echo "{\"name\":\"browser_test_files\",\"status\":\"$status\",\"detail\":\"$detail\"}"
}

check_devtools_mcp_config() {
  local status="fail"
  local detail="No Chrome DevTools MCP configuration found"

  for f in .mcp.json .claude/mcp.json mcp-config.json; do
    if [ -f "$PROJECT_DIR/$f" ]; then
      if grep -qE 'chrome-devtools|devtools' "$PROJECT_DIR/$f" 2>/dev/null; then
        status="pass"
        detail="Chrome DevTools MCP config found in $f"
        break
      fi
    fi
  done

  echo "{\"name\":\"devtools_mcp_config\",\"status\":\"$status\",\"detail\":\"$detail\"}"
}

echo "Checking browser testing setup..." >&2

C1=$(check_browser_test_config)
C2=$(check_test_runner_setup)
C3=$(check_browser_test_files)
C4=$(check_devtools_mcp_config)

CHECKS=$(echo "[$C1,$C2,$C3,$C4]" | python3 -c "import sys,json; checks=json.load(sys.stdin); fail=len([c for c in checks if c['status']=='fail']); partial=len([c for c in checks if c['status']=='partial']); print('pass' if fail==0 else ('partial' if fail<len(checks) else 'fail'))" 2>/dev/null || echo "partial")

OVERALL=$(echo "[$C1,$C2,$C3,$C4]" | python3 -c "import sys,json; checks=json.load(sys.stdin); fail=len([c for c in checks if c['status']=='fail']); print('pass' if fail==0 else ('partial' if fail<len(checks) else 'fail'))" 2>/dev/null || echo "partial")

echo "{\"skill\":\"browser-testing-with-devtools\",\"status\":\"$OVERALL\",\"checks\":[$C1,$C2,$C3,$C4]}"