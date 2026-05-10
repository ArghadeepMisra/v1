#!/bin/bash
set -e

PROJECT_DIR="."
TMPDIR_PREFIX="/tmp/crq-verify-"

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

check_linting_config() {
  local status="fail"
  local detail="No linting configuration found"
  local found=()

  for f in .eslintrc.js .eslintrc.json .eslintrc.yml .eslintrc .eslintrc.cjs \
           eslint.config.js eslint.config.mjs eslint.config.ts \
           .stylelintrc.js .stylelintrc.json .stylelintrc.yml; do
    if [ -f "$PROJECT_DIR/$f" ]; then
      found+=("$f")
    fi
  done

  if [ -f "$PROJECT_DIR/package.json" ]; then
    if grep -qE '"eslintConfig"' "$PROJECT_DIR/package.json" 2>/dev/null; then
      found+=("eslintConfig in package.json")
    fi
  fi

  for f in pyproject.toml setup.cfg .ruff.toml ruff.toml .flake8; do
    if [ -f "$PROJECT_DIR/$f" ]; then
      found+=("$f")
    fi
  done

  for f in golangci.yml .golangci.yml .golangci.yaml; do
    if [ -f "$PROJECT_DIR/$f" ]; then
      found+=("$f")
    fi
  done

  if [ ${#found[@]} -gt 0 ]; then
    status="pass"
    detail="Linting config found: ${found[*]}"
  fi

  echo "{\"name\":\"linting_config\",\"status\":\"$status\",\"detail\":\"$detail\"}"
}

check_test_results() {
  local status="fail"
  local detail="No test runner detected"
  local runners=()

  if [ -f "$PROJECT_DIR/package.json" ]; then
    if grep -qE '"test"' "$PROJECT_DIR/package.json" 2>/dev/null; then
      runners+=("npm test")

      if grep -qE '(jest|vitest|mocha|cypress|@playwright/test)' "$PROJECT_DIR/package.json" 2>/dev/null; then
        local runner
        runner=$(grep -oE '(jest|vitest|mocha|cypress|@playwright/test)' "$PROJECT_DIR/package.json" | head -1)
        [ -n "$runner" ] && runners+=("($runner)")
      fi
    fi
  fi

  if [ -f "$PROJECT_DIR/pytest.ini" ] || [ -f "$PROJECT_DIR/setup.cfg" ] || [ -f "$PROJECT_DIR/pyproject.toml" ] && grep -qE 'pytest' "$PROJECT_DIR/pyproject.toml" 2>/dev/null; then
    runners+=("pytest")
  fi

  if [ -f "$PROJECT_DIR/go.mod" ]; then
    runners+=("go test")
  fi

  if [ ${#runners[@]} -gt 0 ]; then
    status="pass"
    detail="Test runner available: ${runners[*]}"
  fi

  echo "{\"name\":\"test_runner\",\"status\":\"$status\",\"detail\":\"$detail\"}"
}

check_build_status() {
  local status="fail"
  local detail="No build system detected"

  if [ -f "$PROJECT_DIR/package.json" ]; then
    if grep -qE '"(build|compile|tsc|webpack|vite)"' "$PROJECT_DIR/package.json" 2>/dev/null; then
      status="pass"
      detail="Build script found in package.json"
    else
      detail="package.json found but no build script"
    fi
  elif [ -f "$PROJECT_DIR/Makefile" ]; then
    status="pass"
    detail="Makefile found"
  elif [ -f "$PROJECT_DIR/pyproject.toml" ]; then
    status="pass"
    detail="pyproject.toml found"
  elif [ -f "$PROJECT_DIR/go.mod" ]; then
    status="pass"
    detail="go.mod found (go build)"
  elif [ -f "$PROJECT_DIR/Cargo.toml" ]; then
    status="pass"
    detail="Cargo.toml found (cargo build)"
  fi

  echo "{\"name\":\"build_system\",\"status\":\"$status\",\"detail\":\"$detail\"}"
}

check_code_size() {
  local status="fail"
  local detail="No source files found"
  local search_dirs="$PROJECT_DIR/src $PROJECT_DIR/lib $PROJECT_DIR/app $PROJECT_DIR/pkg"

  local total_lines=0
  local file_count=0

  for dir in $search_dirs; do
    if [ -d "$dir" ]; then
      while IFS= read -r f; do
        local lines
        lines=$(wc -l < "$f" 2>/dev/null || echo 0)
        total_lines=$((total_lines + lines))
        file_count=$((file_count + 1))
      done < <(find "$dir" -type f \( -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" -o -name "*.py" -o -name "*.go" -o -name "*.rs" -o -name "*.java" \) 2>/dev/null | head -500)
    fi
  done

  if [ "$file_count" -gt 0 ]; then
    local avg=$((total_lines / file_count))
    if [ "$avg" -le 300 ]; then
      status="pass"
      detail="Average $avg lines/file across $file_count files (healthy size)"
    elif [ "$avg" -le 500 ]; then
      status="partial"
      detail="Average $avg lines/file across $file_count files (moderately large)"
    else
      status="fail"
      detail="Average $avg lines/file across $file_count files (files too large)"
    fi
  fi

  echo "{\"name\":\"code_size\",\"status\":\"$status\",\"detail\":\"$detail\"}"
}

check_common_quality_issues() {
  local status="pass"
  local detail="No common quality issues detected"
  local issues=()

  for dir in "$PROJECT_DIR/src" "$PROJECT_DIR/lib" "$PROJECT_DIR/app"; do
    if [ -d "$dir" ]; then
      local todo_count
      todo_count=$(grep -rE '(TODO|FIXME|HACK|XXX)' "$dir" --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" --include="*.py" --include="*.go" 2>/dev/null | wc -l || echo 0)
      if [ "$todo_count" -gt 10 ]; then
        issues+=("$todo_count TODO/FIXME/HACK comments")
      fi
    fi
  done

  local console_errors=0
  for dir in "$PROJECT_DIR/src" "$PROJECT_DIR/lib" "$PROJECT_DIR/app"; do
    if [ -d "$dir" ]; then
      local found
      found=$(grep -rE 'console\.(log|warn|error)' "$dir" --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" 2>/dev/null | wc -l || echo 0)
      console_errors=$((console_errors + found))
    fi
  done
  if [ "$console_errors" -gt 20 ]; then
    issues+=("$console_errors console statements")
  fi

  local any_files=0
  for dir in "$PROJECT_DIR/src" "$PROJECT_DIR/lib" "$PROJECT_DIR/app"; do
    if [ -d "$dir" ]; then
      while IFS= read -r f; do
        local lines
        lines=$(wc -l < "$f" 2>/dev/null || echo 0)
        if [ "$lines" -gt 500 ]; then
          issues+=("$(basename "$f") is ${lines} lines")
        fi
        any_files=$((any_files + 1))
      done < <(find "$dir" -type f \( -name "*.ts" -o -name "*.tsx" -o -name "*.py" -o -name "*.go" \) 2>/dev/null | head -200)
    fi
  done

  if [ ${#issues[@]} -gt 0 ]; then
    if [ ${#issues[@]} -le 3 ]; then
      status="partial"
    else
      status="fail"
    fi
    detail="Issues: ${issues[*]}"
  fi

  echo "{\"name\":\"common_quality_issues\",\"status\":\"$status\",\"detail\":\"$detail\"}"
}

echo "Checking code review and quality..." >&2

C1=$(check_linting_config)
C2=$(check_test_results)
C3=$(check_build_status)
C4=$(check_code_size)
C5=$(check_common_quality_issues)

CHECKS="[$C1,$C2,$C3,$C4,$C5]"

OVERALL=$(echo "$CHECKS" | python3 -c "import sys,json; checks=json.load(sys.stdin); fail=len([c for c in checks if c['status']=='fail']); partial=len([c for c in checks if c['status']=='partial']); print('pass' if fail==0 and partial==0 else ('partial' if fail<len(checks) else 'fail'))" 2>/dev/null || echo "partial")

echo "{\"skill\":\"code-review-and-quality\",\"status\":\"$OVERALL\",\"checks\":$CHECKS}"