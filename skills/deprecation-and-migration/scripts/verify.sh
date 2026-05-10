#!/bin/bash
set -e

PROJECT_DIR="."
TMP_DIR=""

cleanup() {
    if [ -n "$TMP_DIR" ] && [ -d "$TMP_DIR" ]; then
        rm -rf "$TMP_DIR"
    fi
}
trap cleanup EXIT

TMP_DIR=$(mktemp -d)

while [ $# -gt 0 ]; do
    case "$1" in
        --project-dir)
            PROJECT_DIR="$2"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

cd "$PROJECT_DIR"

CHECKS='['

# Check 1: Deprecation markers in code
CHECK_markers="fail"
DETAIL_markers="No deprecation markers found in codebase"
MARKER_COUNT=0

DEPRECATED_FILES=$(grep -rl '@deprecated' --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" --include="*.py" --include="*.go" --include="*.java" . 2>/dev/null | head -20 || true)
TODO_DEPRECATION=$(grep -rl 'TODO.*deprecat' --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" --include="*.py" --include="*.md" . 2>/dev/null | head -20 || true)
DEPRECATED_COMMENTS=$(grep -rl 'DEPRECATED' --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" --include="*.py" --include="*.md" . 2>/dev/null | head -20 || true)

if [ -n "$DEPRECATED_FILES" ]; then
    MARKER_COUNT=$((MARKER_COUNT + $(echo "$DEPRECATED_FILES" | wc -l)))
fi
if [ -n "$TODO_DEPRECATION" ]; then
    MARKER_COUNT=$((MARKER_COUNT + $(echo "$TODO_DEPRECATION" | wc -l)))
fi
if [ -n "$DEPRECATED_COMMENTS" ]; then
    MARKER_COUNT=$((MARKER_COUNT + $(echo "$DEPRECATED_COMMENTS" | wc -l)))
fi

if [ "$MARKER_COUNT" -gt 0 ]; then
    CHECK_markers="pass"
    DETAIL_markers="Found ${MARKER_COUNT} files with deprecation markers"
fi
CHECKS="${CHECKS}{\"name\":\"deprecation-markers\",\"status\":\"$CHECK_markers\",\"detail\":\"$DETAIL_markers\"},"

# Check 2: Migration guides exist
CHECK_migration="fail"
DETAIL_migration="No migration guides found"
MIGRATION_FILES=()

for dir in docs doc documentation migrations migration; do
    if [ -d "$dir" ]; then
        MIGRATION_GUIDES=$(find "$dir" -type f -iname "*migrat*" 2>/dev/null | head -10)
        if [ -n "$MIGRATION_GUIDES" ]; then
            MIGRATION_FILES+=("$MIGRATION_GUIDES")
        fi
    fi
done

ROOT_MIGRATION=$(find . -maxdepth 1 -type f -iname "*migrat*" 2>/dev/null | head -5)
if [ -n "$ROOT_MIGRATION" ]; then
    MIGRATION_FILES+=("$ROOT_MIGRATION")
fi

if [ ${#MIGRATION_FILES[@]} -gt 0 ]; then
    CHECK_migration="pass"
    DETAIL_migration="Migration guides found: $(echo "${MIGRATION_FILES[@]}" | tr '\n' ', ')"
fi
CHECKS="${CHECKS}{\"name\":\"migration-guides\",\"status\":\"$CHECK_migration\",\"detail\":\"$DETAIL_migration\"},"

# Check 3: Sunset notices
CHECK_sunset="fail"
DETAIL_sunset="No sunset or removal notices found"
SUNSET_FILES=()

for dir in docs doc documentation; do
    if [ -d "$dir" ]; then
        SUNSET=$(find "$dir" -type f \( -iname "*sunset*" -o -iname "*deprecat*" -o -iname "*removal*" -o -iname "*eol*" \) 2>/dev/null | head -10)
        if [ -n "$SUNSET" ]; then
            SUNSET_FILES+=("$SUNSET")
        fi
    fi
done

SUNSET_ROOT=$(find . -maxdepth 1 -type f \( -iname "*sunset*" -o -iname "*deprecat*" -o -iname "*eol*" \) 2>/dev/null | head -5)
if [ -n "$SUNSET_ROOT" ]; then
    SUNSET_FILES+=("$SUNSET_ROOT")
fi

if [ ${#SUNSET_FILES[@]} -gt 0 ]; then
    CHECK_sunset="pass"
    DETAIL_sunset="Sunset/deprecation notices found: $(echo "${SUNSET_FILES[@]}" | tr '\n' ', ')"
fi
CHECKS="${CHECKS}{\"name\":\"sunset-notices\",\"status\":\"$CHECK_sunset\",\"detail\":\"$DETAIL_sunset\"},"

# Check 4: Compatibility layers (adapters, shims, polyfills)
CHECK_compat="fail"
DETAIL_compat="No compatibility layers found"
COMPAT_FILES=()

ADAPTERS=$(grep -rl -E '(adapter|shim|polyfill|compat|backward|legacy|wrapper)' --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" --include="*.py" --include="*.go" --include="*.java" . 2>/dev/null | head -15 || true)
if [ -n "$ADAPTERS" ]; then
    COMPAT_COUNT=$(echo "$ADAPTERS" | wc -l)
    CHECK_compat="partial"
    DETAIL_compat="Found ${COMPAT_COUNT} files with compatibility patterns (review for relevance)"
fi

if [ -n "$DEPRECATED_FILES" ] && [ -n "$ADAPTERS" ]; then
    CHECK_compat="pass"
    DETAIL_compat="Found deprecation markers AND compatibility layers"
fi
CHECKS="${CHECKS}{\"name\":\"compatibility-layers\",\"status\":\"$CHECK_compat\",\"detail\":\"$DETAIL_compat\"}"

CHECKS="${CHECKS}]"

# Determine overall status
PASS_COUNT=$(echo "$CHECKS" | grep -o '"status":"pass"' | wc -l)
FAIL_COUNT=$(echo "$CHECKS" | grep -o '"status":"fail"' | wc -l)
PARTIAL_COUNT=$(echo "$CHECKS" | grep -o '"status":"partial"' | wc -l)

if [ "$FAIL_COUNT" -gt 0 ]; then
    OVERALL="fail"
elif [ "$PARTIAL_COUNT" -gt 0 ]; then
    OVERALL="partial"
else
    OVERALL="pass"
fi

echo "{\"skill\":\"deprecation-and-migration\",\"status\":\"$OVERALL\",\"checks\":$CHECKS}"