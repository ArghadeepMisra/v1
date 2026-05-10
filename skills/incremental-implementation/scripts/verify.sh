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

echo "Checking incremental implementation status in: $PROJECT_DIR" >&2

# Check 1: Uncommitted changes
check_uncommitted() {
  local detail=""
  local status="pass"

  if [[ ! -d "$PROJECT_DIR/.git" ]]; then
    echo '{"name":"uncommitted_changes","status":"partial","detail":"Not a git repository; cannot check uncommitted changes"}'
    return
  fi

  local staged
  staged=$(git -C "$PROJECT_DIR" diff --cached --stat 2>/dev/null | tail -1 || echo "")
  local unstaged
  unstaged=$(git -C "$PROJECT_DIR" diff --stat 2>/dev/null | tail -1 || echo "")
  local untracked
  untracked=$(git -C "$PROJECT_DIR" ls-files --others --exclude-standard "$PROJECT_DIR" 2>/dev/null | head -20 || echo "")

  local has_changes=false

  if [[ -n "$staged" ]]; then
    detail+="Staged changes present. "
    has_changes=true
  fi
  if [[ -n "$unstaged" ]]; then
    detail+="Unstaged changes present. "
    has_changes=true
  fi
  if [[ -n "$untracked" ]]; then
    local untracked_count
    untracked_count=$(echo "$untracked" | wc -l)
    detail+="${untracked_count} untracked files. "
    has_changes=true
  fi

  if $has_changes; then
    status="fail"
  else
    detail="Working tree clean — no uncommitted changes"
    status="pass"
  fi

  echo '{"name":"uncommitted_changes","status":"'"$status"'","detail":"'"$detail"'"}'
}

# Check 2: Feature flags
check_feature_flags() {
  local found=false
  local detail=""

  # Common feature flag patterns
  for pattern in "FEATURE_.*=.*true\|FEATURE_.*=.*false\|feature.*flag\|featureFlag\|feature_flag\|env.*FEATURE\|FF_\|LAUNCH_DARKLY\|unleash\|splitio\|flagsmith"; do
    if grep -rl "$pattern" "$PROJECT_DIR/src" "$PROJECT_DIR/lib" "$PROJECT_DIR/app" "$PROJECT_DIR/config" > /dev/null 2>&1; then
      found=true
      detail+="Feature flag pattern detected. "
      break
    fi
  done

  # Check .env files for feature flags
  for envfile in .env .env.local .env.development .env.production; do
    if [[ -f "$PROJECT_DIR/$envfile" ]] && grep -qi "FEATURE\|FF_\|FLAG" "$PROJECT_DIR/$envfile" 2>/dev/null; then
      found=true
      detail+="Feature flags found in $envfile. "
      break
    fi
  done

  # Check for feature flag config files
  for ffdir in "features" "feature-flags" "flags"; do
    if [[ -d "$PROJECT_DIR/$ffdir" ]]; then
      found=true
      detail+="Feature flag directory found: $ffdir/. "
    fi
  done

  if $found; then
    echo '{"name":"feature_flags","status":"pass","detail":"'"$detail"'"}'
  else
    echo '{"name":"feature_flags","status":"partial","detail":"No feature flag patterns found — consider using them for incomplete features"}'
  fi
}

# Check 3: Incremental commits (recent git history)
check_incremental_commits() {
  if [[ ! -d "$PROJECT_DIR/.git" ]]; then
    echo '{"name":"incremental_commits","status":"partial","detail":"Not a git repository; cannot check commit history"}'
    return
  fi

  local detail=""
  local status="pass"

  local recent_count
  recent_count=$(git -C "$PROJECT_DIR" log --oneline -7 --since="24 hours ago" 2>/dev/null | wc -l)

  if [[ "$recent_count" -ge 3 ]]; then
    detail+="${recent_count} commits in the last 24 hours — good incremental cadence"
    status="pass"
  elif [[ "$recent_count" -ge 1 ]]; then
    detail+="${recent_count} commits in the last 24 hours — could be more granular"
    status="partial"
  else
    detail="No recent commits found — consider committing increments more frequently"
    status="partial"
  fi

  # Check for large commits (legacy-style big bang)
  local large_commits=0
  while IFS= read -r line; do
    local files_changed
    files_changed=$(echo "$line" | awk '{print $1}')
    if [[ -n "$files_changed" ]] && [[ "$files_changed" -gt 10 ]] 2>/dev/null; then
      large_commits=$((large_commits + 1))
    fi
  done < <(git -C "$PROJECT_DIR" log --format="" --shortstat -10 2>/dev/null | grep -o '[0-9]* files changed' | grep -o '[0-9]*' || true)

  if [[ $large_commits -gt 2 ]]; then
    detail+=". $large_commits of last 10 commits changed >10 files — consider smaller increments"
    status="partial"
  fi

  echo '{"name":"incremental_commits","status":"'"$status"'","detail":"'"$detail"'"}'
}

# Check 4: Test suite status
check_test_suite() {
  local detail=""
  local status="partial"
  local test_cmd=""

  # Detect test runner
  if [[ -f "$PROJECT_DIR/package.json" ]]; then
    if grep -q '"test"' "$PROJECT_DIR/package.json" 2>/dev/null; then
      test_cmd="npm test"
    fi
  fi

  if [[ -f "$PROJECT_DIR/pytest.ini" ]] || [[ -f "$PROJECT_DIR/pyproject.toml" ]] || [[ -f "$PROJECT_DIR/setup.cfg" ]]; then
    test_cmd="pytest"
  fi

  if [[ -f "$PROJECT_DIR/Cargo.toml" ]]; then
    test_cmd="cargo test"
  fi

  if [[ -f "$PROJECT_DIR/go.mod" ]]; then
    test_cmd="go test ./..."
  fi

  if [[ -z "$test_cmd" ]]; then
    detail="No test runner detected"
    status="partial"
  else
    detail="Test command detected: $test_cmd. "
    # Just check if tests exist — don't run them
    local test_file_count=0
    test_file_count=$(find "$PROJECT_DIR" -type f \( -name "*.test.*" -o -name "*_test.*" -o -name "*.spec.*" -o -name "test_*.py" -o -name "*Test*.java" \) 2>/dev/null | grep -v node_modules | grep -v ".git" | wc -l)

    if [[ "$test_file_count" -gt 0 ]]; then
      detail+="${test_file_count} test files found"
      status="pass"
    else
      detail+="No test files found"
      status="fail"
    fi
  fi

  echo '{"name":"test_suite","status":"'"$status"'","detail":"'"$detail"'"}'
}

# Check 5: Clean build
check_clean_build() {
  local detail=""
  local status="partial"

  # Check if build artifacts exist
  for build_dir in "dist" "build" ".next" "out" "target" "bin"; do
    if [[ -d "$PROJECT_DIR/$build_dir" ]]; then
      detail+="Build output directory found: $build_dir/. "
    fi
  done

  # Check for build script
  local has_build=false
  if [[ -f "$PROJECT_DIR/package.json" ]] && grep -q '"build"' "$PROJECT_DIR/package.json" 2>/dev/null; then
    has_build=true
    detail+="Build script found in package.json"
  fi

  if [[ -f "$PROJECT_DIR/Makefile" ]]; then
    has_build=true
    detail+="Makefile found"
  fi

  if [[ -f "$PROJECT_DIR/Cargo.toml" ]]; then
    has_build=true
    detail+="Cargo.toml build configuration found"
  fi

  if $has_build; then
    # Check for TypeScript errors without running build
    if [[ -f "$PROJECT_DIR/tsconfig.json" ]]; then
      detail+=". TypeScript project detected (run npx tsc --noEmit to verify)"
    fi
    status="partial"
  else
    detail="No build configuration detected"
    status="partial"
  fi

  echo '{"name":"clean_build","status":"'"$status"'","detail":"'"$detail"'"}'
}

echo "Running incremental implementation checks..." >&2

c1=$(check_uncommitted)
c2=$(check_feature_flags)
c3=$(check_incremental_commits)
c4=$(check_test_suite)
c5=$(check_clean_build)

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

printf '{"skill":"incremental-implementation","status":"%s","checks":%s}\n' "$overall" "$checks_json"