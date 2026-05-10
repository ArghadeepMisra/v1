#!/bin/bash
set -e

PROJECT_DIR="."
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

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

echo "Checking test-driven development status in: $PROJECT_DIR" >&2

# Check 1: Test framework config
check_test_framework() {
  local detail=""
  local status="fail"
  local framework=""

  if [[ -f "$PROJECT_DIR/package.json" ]]; then
    for fw in "jest" "vitest" "mocha" "ava" "jasmine" "cypress" "playwright"; do
      if grep -q "\"$fw\"" "$PROJECT_DIR/package.json" 2>/dev/null; then
        framework="$fw"
        detail+="$fw detected in package.json. "
        status="pass"
        break
      fi
    done
  fi

  if [[ -f "$PROJECT_DIR/vitest.config."* ]] || [[ -f "$PROJECT_DIR/vite.config."* ]]; then
    if grep -rl "vitest" "$PROJECT_DIR/vite.config."* > /dev/null 2>&1; then
      framework="vitest"
      detail+="vitest detected in vite config. "
      status="pass"
    fi
  fi

  if [[ -f "$PROJECT_DIR/pytest.ini" ]] || [[ -f "$PROJECT_DIR/pyproject.toml" ]]; then
    framework="pytest"
    detail+="pytest detected. "
    status="pass"
  fi

  if [[ -f "$PROJECT_DIR/Cargo.toml" ]]; then
    framework="cargo-test"
    detail+="Rust test framework (cargo test) detected. "
    status="pass"
  fi

  if [[ -f "$PROJECT_DIR/go.mod" ]]; then
    framework="go-test"
    detail+="Go test framework detected. "
    status="pass"
  fi

  for config in "jest.config.*" "vitest.config.*" "karma.conf.*" "cypress.config.*" "playwright.config.*" ".mocharc.*"; do
    if compgen -G "$PROJECT_DIR/$config" > /dev/null 2>&1; then
      detail+="Test config file found: $(compgen -G "$PROJECT_DIR/$config" | head -1). "
      status="pass"
    fi
  done

  if [[ -z "$framework" && "$status" == "fail" ]]; then
    detail="No test framework configuration found"
  fi

  echo '{"name":"test_framework","status":"'"$status"'","detail":"'"$detail"'"}'
}

# Check 2: Test files exist
check_test_files() {
  local detail=""
  local count=0

  count=$(find "$PROJECT_DIR" -type f \( \
    -name "*.test.ts" -o -name "*.test.tsx" -o -name "*.test.js" -o -name "*.test.jsx" \
    -o -name "*.spec.ts" -o -name "*.spec.tsx" -o -name "*.spec.js" -o -name "*.spec.jsx" \
    -o -name "*_test.go" -o -name "test_*.py" -o -name "*_test.py" \
    -o -name "*Test.java" -o -name "*Tests.java" \
    -o -name "*Test.scala" -o -name "*Spec.scala" \
    -o -name "*.rb" -path "*/test/*" -o -name "*_test.rs" \
  \) 2>/dev/null | grep -v node_modules | grep -v ".git" | wc -l)

  if [[ "$count" -gt 0 ]]; then
    detail="${count} test files found"
    status="pass"
  else
    detail="No test files found"
    status="fail"
  fi

  echo '{"name":"test_files","status":"'"$status"'","detail":"'"$detail"'"}'
}

# Check 3: Test names describe behavior
check_test_names() {
  local detail=""
  local total=0
  local good=0
  local bad_names=""

  # Look for test files and extract test names
  while IFS= read -r testfile; do
    [[ -z "$testfile" ]] && continue

    # Extract it()/test() names from JS/TS
    local names
    names=$(grep -oP '(?:it|test)\s*\(\s*['\''"](.*?)['\''"]' "$testfile" 2>/dev/null | sed "s/.*['\"]\(.*\)['\"].*/\1/" | head -50 || true)

    while IFS= read -r name; do
      [[ -z "$name" ]] && continue
      total=$((total + 1))

      # Bad test names: vague or generic
      case "$name" in
        "works"|"works correctly"|"test"|"test 1"|"test"*|"handles errors"|"returns"*|"basic"|"default"|"success"|"failure"|"ok"|"pass"|"fail"|"it works")
          bad_names+="$name, "
          ;;
        *)
          good=$((good + 1))
          ;;
      esac
    done < <(echo "$names")

    # Extract pytest-style names (def test_...)
    local py_names
    py_names=$(grep -oP 'def test_(\w+)' "$testfile" 2>/dev/null | sed 's/def test_//' || true)

    while IFS= read -r name; do
      [[ -z "$name" ]] && continue
      total=$((total + 1))
      case "$name" in
        "works"|"test"*|"basic"|"main"|"default"|"success"|"failure"|"ok"|"pass"|"fail")
          bad_names+="$name, "
          ;;
        *)
          good=$((good + 1))
          ;;
      esac
    done < <(echo "$py_names")

  done < <(find "$PROJECT_DIR" -type f \( \
    -name "*.test.ts" -o -name "*.test.tsx" -o -name "*.test.js" -o -name "*.test.jsx" \
    -o -name "*.spec.ts" -o -name "*.spec.tsx" -o -name "*.spec.js" -o -name "*.spec.jsx" \
    -o -name "test_*.py" -o -name "*_test.py" \
  \) 2>/dev/null | grep -v node_modules | grep -v ".git" | head -20)

  if [[ $total -eq 0 ]]; then
    detail="No test names could be extracted for analysis"
    status="partial"
  elif [[ $good -eq $total ]]; then
    detail="All ${total} test names describe behavior clearly"
    status="pass"
  else
    local bad_count=$((total - good))
    detail="${bad_count} of ${total} test names are vague (e.g., ${bad_names%, })"
    if [[ $bad_count -gt $((total / 2)) ]]; then
      status="fail"
    else
      status="partial"
    fi
  fi

  echo '{"name":"test_names","status":"'"$status"'","detail":"'"$detail"'"}'
}

# Check 4: No skipped/disabled tests
check_skipped_tests() {
  local detail=""
  local count=0

  # Common skip/disable patterns across frameworks
  count=$(grep -rl \
    "xit\b\|xdescribe\|xcontext\|\.skip\|\.only\|@skip\|@ignore\|@disabled\|@pytest\.mark\.skip\|pending(\|@pending\|\.todo(" \
    "$PROJECT_DIR/src" "$PROJECT_DIR/test" "$PROJECT_DIR/tests" "$PROJECT_DIR/__tests__" "$PROJECT_DIR/spec" \
    2>/dev/null | grep -v node_modules | grep -v ".git" | wc -l)

  # Also try broader search
  if [[ "$count" -eq 0 ]]; then
    count=$(find "$PROJECT_DIR" -type f \( \
      -name "*.test.*" -o -name "*.spec.*" -o -name "test_*.py" -o -name "*_test.*" \
    \) 2>/dev/null | grep -v node_modules | grep -v ".git" | head -50 | xargs grep -l \
      "xit\b\|\.skip\|\.only\|@skip\|@pytest\.mark\.skip\|pending(" \
      2>/dev/null | wc -l)
  fi

  if [[ "$count" -eq 0 ]]; then
    detail="No skipped or disabled tests found"
    status="pass"
  else
    detail="${count} files contain skipped or disabled tests (.skip, xit, @skip, etc.)"
    status="fail"
  fi

  echo '{"name":"no_skipped_tests","status":"'"$status"'","detail":"'"$detail"'"}'
}

# Check 5: Coverage data available
check_coverage() {
  local detail=""
  local status="partial"

  # Check for coverage config in package.json
  if [[ -f "$PROJECT_DIR/package.json" ]]; then
    if grep -q "coverage\|c8\|nyc\|istanbul" "$PROJECT_DIR/package.json" 2>/dev/null; then
      detail+="Coverage tool found in package.json. "
      status="pass"
    fi
  fi

  # Check for coverage config files
  for covfile in ".nycrc" ".nycrc.json" "nyc.config.js" "istanbul.yml" ".c8rc" ".c8rc.json" "coverage.config.js"; do
    if [[ -f "$PROJECT_DIR/$covfile" ]]; then
      detail+="Coverage config found: $covfile. "
      status="pass"
    fi
  done

  # Check for coverage thresholds in config
  for cfgfile in "vitest.config.ts" "vitest.config.js" "jest.config.ts" "jest.config.js"; do
    if [[ -f "$PROJECT_DIR/$cfgfile" ]]; then
      if grep -q "coverage\|threshold" "$PROJECT_DIR/$cfgfile" 2>/dev/null; then
        detail+="Coverage thresholds found in $cfgfile. "
        status="pass"
      fi
    fi
  done

  # Check for existing coverage reports
  for covdir in "coverage" ".coverage" "coveragereport" "htmlcov" ".pytest_cache"; do
    if [[ -d "$PROJECT_DIR/$covdir" ]]; then
      detail+="Coverage report directory found: $covdir/. "
      if [[ "$status" != "pass" ]]; then status="partial"; fi
    fi
  done

  # Check for Python coverage
  if [[ -f "$PROJECT_DIR/setup.cfg" ]] || [[ -f "$PROJECT_DIR/pyproject.toml" ]]; then
    if grep -q "coverage\|pytest-cov" "$PROJECT_DIR/setup.cfg" "$PROJECT_DIR/pyproject.toml" 2>/dev/null; then
      detail+="pytest-cov coverage tool detected. "
      status="pass"
    fi
  fi

  # Check for Go coverage
  if [[ -f "$PROJECT_DIR/go.mod" ]]; then
    detail+="Go has built-in coverage (go test -cover). "
    if [[ "$status" == "partial" ]]; then status="pass"; fi
  fi

  if [[ -z "$detail" ]]; then
    detail="No coverage configuration found"
    status="fail"
  fi

  echo '{"name":"coverage","status":"'"$status"'","detail":"'"$detail"'"}'
}

echo "Running test-driven development checks..." >&2

c1=$(check_test_framework)
c2=$(check_test_files)
c3=$(check_test_names)
c4=$(check_skipped_tests)
c5=$(check_coverage)

fail_count=0
pass_count=0
partial_count=0

for check_json in "$c1" "$c2" "$c3" "$c4" "$c5"; do
  s=$(echo "$check_json" | sed 's/.*"status":"\([^"]*\)".*/\1/')
  if [[ "$s" == "fail" ]]; then fail_count=$((fail_count + 1)); fi
  if [[ "$s" == "pass" ]]; then pass_count=$((pass_count + 1)); fi
  if [[ "$s" == "partial" ]]; then partial_count=$((partial_count + 1)); fi
done

if [[ $fail_count -gt 0 ]]; then
  overall="fail"
elif [[ $partial_count -gt 0 ]]; then
  overall="partial"
else
  overall="pass"
fi

checks_json="[$c1,$c2,$c3,$c4,$c5]"

printf '{"skill":"test-driven-development","status":"%s","checks":%s}\n' "$overall" "$checks_json"