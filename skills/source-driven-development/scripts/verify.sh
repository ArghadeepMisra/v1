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

echo "Checking source-driven development status in: $PROJECT_DIR" >&2

# Check 1: Source citations in code comments
check_source_citations() {
  local detail=""
  local citation_count=0
  local status="partial"

  # Look for URL citations in code comments
  # Patterns: Source:, Ref:, See:, docs:, Reference: followed by a URL
  local src_dirs=("$PROJECT_DIR/src" "$PROJECT_DIR/lib" "$PROJECT_DIR/app" "$PROJECT_DIR/pkg" "$PROJECT_DIR/components")

  for dir in "${src_dirs[@]}"; do
    if [[ -d "$dir" ]]; then
      # Count comments with source URLs
      local count=0
      count=$(grep -r \
        -E "// Source:|// Ref:|// See:|// docs:|// Reference:|# Source:|# Ref:|# See:|# docs:|# Reference:|/\*.*Source:|/\*.*Ref:" \
        "$dir" 2>/dev/null | grep -c 'https\?://' || true)

      citation_count=$((citation_count + count))
    fi
  done

  if [[ $citation_count -gt 5 ]]; then
    detail="${citation_count} source citations found in code comments"
    status="pass"
  elif [[ $citation_count -gt 0 ]]; then
    detail="${citation_count} source citations found — add citations for more framework-specific patterns"
    status="partial"
  else
    detail="No source citations found in code comments"
    status="fail"
  fi

  echo '{"name":"source_citations","status":"'"$status"'","detail":"'"$detail"'"}'
}

# Check 2: Official docs referenced
check_official_docs() {
  local detail=""
  local status="partial"
  local found=false

  # Check for docs directory with official references
  for docsdir in "docs" "doc" "documentation" ".docs" "references"; do
    if [[ -d "$PROJECT_DIR/$docsdir" ]]; then
      found=true
      detail+="Documentation directory found: $docsdir/. "
    fi
  done

  # Check for references to official documentation in markdown files
  local md_files=()
  while IFS= read -r -d '' f; do
    md_files+=("$f")
  done < <(find "$PROJECT_DIR" -name "*.md" -not -path "*/node_modules/*" -not -path "*/.git/*" -print0 2>/dev/null | head -30)

  local official_ref_count=0
  for md_file in "${md_files[@]}"; do
    # Look for links to official docs (react.dev, docs.python.org, etc.)
    if grep -qE 'https?://(react\.dev|docs\.python\.org|docs\.rs|pkg\.go\.dev|developer\.mozilla\.org|nodejs\.org/docs|docs\.google|kubernetes\.io/docs|docs\.docker\.com|docs\.aws\.amazon\.com|cloud\.google\.com/docs|msdn\.microsoft\.com|docs\.microsoft\.com|angular\.io|vuejs\.org|nextjs\.org/docs|tailwindcss\.com/docs|typescriptlang\.org/docs|docs\.stripe\.com|docs\.github\.com)' "$md_file" 2>/dev/null; then
      official_ref_count=$((official_ref_count + 1))
    fi
  done

  if [[ $official_ref_count -gt 0 ]]; then
    detail+="${official_ref_count} files reference official documentation. "
    found=true
  fi

  # Check AGENTS.md or CLAUDE.md for doc references
  for rulesfile in "AGENTS.md" "CLAUDE.md"; do
    if [[ -f "$PROJECT_DIR/$rulesfile" ]]; then
      if grep -qE 'https?://' "$PROJECT_DIR/$rulesfile" 2>/dev/null; then
        found=true
        detail+="$rulesfile contains documentation URLs. "
      fi
    fi
  done

  if $found; then
    status="pass"
    if [[ -z "$detail" ]]; then
      detail="Official documentation references found"
    fi
  else
    detail="No references to official documentation found in markdown or rules files"
    status="fail"
  fi

  echo '{"name":"official_docs","status":"'"$status"'","detail":"'"$detail"'"}'
}

# Check 3: Dependency versions identified (version awareness)
check_dependency_versions() {
  local detail=""
  local status="partial"
  local dep_files=0

  # Check for dependency files and whether versions are pinned
  for depfile in "package.json" "package-lock.json" "yarn.lock" "pnpm-lock.yaml" "composer.json" "requirements.txt" "Pipfile.lock" "pyproject.toml" "go.mod" "go.sum" "Cargo.toml" "Cargo.lock" "Gemfile" "Gemfile.lock" "pom.xml" "build.gradle" "build.gradle.kts"; do
    if [[ -f "$PROJECT_DIR/$depfile" ]]; then
      dep_files=$((dep_files + 1))
      detail+="$depfile found. "
    fi
  done

  # Check if lock files exist (pinned versions)
  local has_lock=false
  for lockfile in "package-lock.json" "yarn.lock" "pnpm-lock.yaml" "Pipfile.lock" "Cargo.lock" "go.sum" "Gemfile.lock"; do
    if [[ -f "$PROJECT_DIR/$lockfile" ]]; then
      has_lock=true
    fi
  done

  if $has_lock; then
    detail+="Lock file present (pinned versions). "
  fi

  if [[ $dep_files -eq 0 ]]; then
    detail="No dependency files found — cannot verify version awareness"
    status="fail"
  elif $has_lock; then
    status="pass"
  else
    detail+="No lock file found — versions may not be pinned"
    status="partial"
  fi

  echo '{"name":"dependency_versions","status":"'"$status"'","detail":"'"$detail"'"}'
}

# Check 4: Unverified claims flagged
check_unverified_claims() {
  local detail=""
  local status="partial"
  local unverified_count=0

  # Search for UNVERIFIED markers in code (as recommended by the skill)
  for src_dir in "src" "lib" "app" "pkg" "components"; do
    if [[ -d "$PROJECT_DIR/$src_dir" ]]; then
      local count=0
      count=$(grep -rE "UNVERIFIED:|UNVERIFIED |FIXME.*verify|TODO.*verify|HACK:|XXX:" \
        "$PROJECT_DIR/$src_dir" 2>/dev/null | wc -l || true)
      unverified_count=$((unverified_count + count))
    fi
  done

  if [[ $unverified_count -gt 0 ]]; then
    detail="${unverified_count} UNVERIFIED/FIXME/TODO-verify markers found in source — these need verification against official docs"
    status="partial"
  else
    # Also check if there are source URL comments (good practice)
    local src_citations=0
    for src_dir in "src" "lib" "app" "pkg" "components"; do
      if [[ -d "$PROJECT_DIR/$src_dir" ]]; then
        local count=0
        count=$(grep -rE "// Source:|# Source:|// Ref:|# Ref:|// See:|# See:" \
          "$PROJECT_DIR/$src_dir" 2>/dev/null | wc -l || true)
        src_citations=$((src_citations + count))
      fi
    done

    if [[ $src_citations -gt 0 ]]; then
      detail="No unverified claims flagged; ${src_citations} source citations present"
      status="pass"
    else
      detail="No UNVERIFIED markers found, but no source citations either — hard to verify claims without citations"
      status="partial"
    fi
  fi

  echo '{"name":"unverified_claims","status":"'"$status"'","detail":"'"$detail"'"}'
}

echo "Running source-driven development checks..." >&2

c1=$(check_source_citations)
c2=$(check_official_docs)
c3=$(check_dependency_versions)
c4=$(check_unverified_claims)

fail_count=0
pass_count=0
partial_count=0

for check_json in "$c1" "$c2" "$c3" "$c4"; do
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

checks_json="[$c1,$c2,$c3,$c4]"

printf '{"skill":"source-driven-development","status":"%s","checks":%s}\n' "$overall" "$checks_json"