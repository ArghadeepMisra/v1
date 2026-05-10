#!/bin/bash
set -e

PROJECT_DIR="."
TMPDIR_PREFIX="/tmp/cs-verify-"

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

check_large_files() {
  local status="pass"
  local detail="No files exceed 500 lines"
  local large_files=()

  local threshold=500

  for dir in "$PROJECT_DIR/src" "$PROJECT_DIR/lib" "$PROJECT_DIR/app" "$PROJECT_DIR/pkg" "$PROJECT_DIR/internal"; do
    if [ -d "$dir" ]; then
      while IFS= read -r f; do
        local lines
        lines=$(wc -l < "$f" 2>/dev/null || echo 0)
        if [ "$lines" -gt "$threshold" ]; then
          large_files+=("$(echo "$f" | sed "s|$PROJECT_DIR/||"):${lines}L")
        fi
      done < <(find "$dir" -type f \( -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" -o -name "*.py" -o -name "*.go" -o -name "*.rs" -o -name "*.java" -o -name "*.rb" \) 2>/dev/null | head -500)
    fi
  done

  if [ ${#large_files[@]} -gt 0 ]; then
    if [ ${#large_files[@]} -le 5 ]; then
      status="partial"
    else
      status="fail"
    fi
    detail="${#large_files[@]} file(s) exceed ${threshold} lines: ${large_files[*]}"
  fi

  echo "{\"name\":\"large_files\",\"status\":\"$status\",\"detail\":\"$detail\"}"
}

check_deep_nesting() {
  local status="pass"
  local detail="No deeply nested code detected"
  local deeply_nested=()

  local max_depth=4

  for dir in "$PROJECT_DIR/src" "$PROJECT_DIR/lib" "$PROJECT_DIR/app" "$PROJECT_DIR/pkg"; do
    if [ -d "$dir" ]; then
      while IFS= read -r f; do
        local nest_count=0
        local max_nest=0
        local ext="${f##*.}"

        if [ "$ext" = "py" ]; then
          while IFS= read -r line; do
            local indent=${line%%[! ]*}
            local level=$(((${#indent} / 4) + 1))
            if [ "$level" -gt "$max_nest" ]; then
              max_nest=$level
            fi
          done < <(grep -v '^\s*#' "$f" 2>/dev/null || true)
        else
          while IFS= read -r line; do
            if echo "$line" | grep -qE '^\s*(if|for|while|switch|try|catch|else|elif|function|def|class)\b'; then
              nest_count=$((nest_count + 1))
            fi
          done < <(head -200 "$f" 2>/dev/null || true)
          max_nest=$nest_count
        fi

        if [ "$max_nest" -ge "$max_depth" ]; then
          deeply_nested+=("$(echo "$f" | sed "s|$PROJECT_DIR/||"):depth~${max_nest}")
        fi
      done < <(find "$dir" -type f \( -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" -o -name "*.py" -o -name "*.go" \) 2>/dev/null | head -200)
    fi
  done

  if [ ${#deeply_nested[@]} -gt 0 ]; then
    status="partial"
    detail="${#deeply_nested[@]} file(s) with nesting depth >= ${max_depth}: ${deeply_nested[*]}"
  fi

  echo "{\"name\":\"deep_nesting\",\"status\":\"$status\",\"detail\":\"$detail\"}"
}

check_function_complexity() {
  local status="pass"
  local detail="No high-complexity functions detected"
  local complex_files=()

  for dir in "$PROJECT_DIR/src" "$PROJECT_DIR/lib" "$PROJECT_DIR/app" "$PROJECT_DIR/pkg"; do
    if [ -d "$dir" ]; then
      while IFS= read -r f; do
        local branch_count=0
        branch_count=$(grep -cE '(if\s|else\s|elif\s|case\s|&&|\|\||\?\?|\?.*:)' "$f" 2>/dev/null || echo 0)
        if [ "$branch_count" -gt 20 ]; then
          complex_files+=("$(echo "$f" | sed "s|$PROJECT_DIR/||"):${branch_count} branches")
        fi
      done < <(find "$dir" -type f \( -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" -o -name "*.py" -o -name "*.go" \) 2>/dev/null | head -200)
    fi
  done

  if [ ${#complex_files[@]} -gt 0 ]; then
    if [ ${#complex_files[@]} -le 3 ]; then
      status="partial"
    else
      status="fail"
    fi
    detail="${#complex_files[@]} file(s) with high branching: ${complex_files[*]}"
  fi

  echo "{\"name\":\"function_complexity\",\"status\":\"$status\",\"detail\":\"$detail\"}"
}

check_duplication() {
  local status="pass"
  local detail="No significant code duplication detected"
  local dup_count=0

  for dir in "$PROJECT_DIR/src" "$PROJECT_DIR/lib" "$PROJECT_DIR/app"; do
    if [ -d "$dir" ]; then
      local file_count
      file_count=$(find "$dir" -type f \( -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" -o -name "*.py" \) 2>/dev/null | wc -l)
      if [ "$file_count" -gt 5 ]; then
        local similar
        similar=$(grep -rl 'import' "$dir" 2>/dev/null | head -50 | xargs grep -hE '^\s*import ' 2>/dev/null | sed 's/.*from.*//' | sort | uniq -c | sort -rn | awk '$1 > 3 {print}' | wc -l)
        dup_count=$((dup_count + similar))
      fi
    fi
  done

  if [ "$dup_count" -gt 5 ]; then
    status="partial"
    detail="$dup_count potential duplication indicator(s) found (shared import patterns)"
  fi

  echo "{\"name\":\"duplication_indicators\",\"status\":\"$status\",\"detail\":\"$detail\"}"
}

check_tests_pass() {
  local status="fail"
  local detail="Cannot verify test status"

  if [ -f "$PROJECT_DIR/package.json" ] && [ -d "$PROJECT_DIR/node_modules" ]; then
    detail="Run npm test to verify tests pass"
    status="partial"
  elif [ -f "$PROJECT_DIR/pytest.ini" ] || [ -f "$PROJECT_DIR/pyproject.toml" ]; then
    detail="Run pytest to verify tests pass"
    status="partial"
  else
    detail="No test runner detected"
  fi

  echo "{\"name\":\"tests_verification\",\"status\":\"$status\",\"detail\":\"$detail\"}"
}

echo "Checking code simplification status..." >&2

C1=$(check_large_files)
C2=$(check_deep_nesting)
C3=$(check_function_complexity)
C4=$(check_duplication)
C5=$(check_tests_pass)

CHECKS="[$C1,$C2,$C3,$C4,$C5]"

OVERALL=$(echo "$CHECKS" | python3 -c "import sys,json; checks=json.load(sys.stdin); fail=len([c for c in checks if c['status']=='fail']); partial=len([c for c in checks if c['status']=='partial']); print('pass' if fail==0 and partial==0 else ('partial' if fail<len(checks) else 'fail'))" 2>/dev/null || echo "partial")

echo "{\"skill\":\"code-simplification\",\"status\":\"$OVERALL\",\"checks\":$CHECKS}"