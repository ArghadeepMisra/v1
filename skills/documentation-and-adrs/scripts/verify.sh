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

# Check 1: ADR directory exists
CHECK_adr="fail"
DETAIL_adr="No ADR directory found"
ADR_DIRS=""

for dir in docs/adr docs/decisions docs/adrs adr decisions .opencode/decisions; do
    if [ -d "$dir" ]; then
        ADR_DIRS="$ADR_DIRS $dir"
    fi
done

if [ -n "$ADR_DIRS" ]; then
    ADR_COUNT=$(find $ADR_DIRS -type f -name "*.md" 2>/dev/null | wc -l || echo "0")
    if [ "$ADR_COUNT" -gt 0 ]; then
        CHECK_adr="pass"
        DETAIL_adr="ADR directory found with ${ADR_COUNT} decision records"
    else
        CHECK_adr="partial"
        DETAIL_adr="ADR directory exists but contains no decision records"
    fi
fi
CHECKS="${CHECKS}{\"name\":\"adr-directory\",\"status\":\"$CHECK_adr\",\"detail\":\"$DETAIL_adr\"},"

# Check 2: README files
CHECK_readme="fail"
DETAIL_readme="No README.md found in project root"
if [ -f "README.md" ]; then
    README_CONTENT=$(cat README.md)
    README_SECTIONS=0
    echo "$README_CONTENT" | grep -qiE 'quick.?start' && README_SECTIONS=$((README_SECTIONS + 1))
    echo "$README_CONTENT" | grep -qiE 'command' && README_SECTIONS=$((README_SECTIONS + 1))
    echo "$README_CONTENT" | grep -qiE 'architect|overview|structure' && README_SECTIONS=$((README_SECTIONS + 1))
    echo "$README_CONTENT" | grep -qiE 'install|setup|getting.?started' && README_SECTIONS=$((README_SECTIONS + 1))
    echo "$README_CONTENT" | grep -qiE 'contribut' && README_SECTIONS=$((README_SECTIONS + 1))

    if [ "$README_SECTIONS" -ge 3 ]; then
        CHECK_readme="pass"
        DETAIL_readme="README.md found with ${README_SECTIONS}/5 key sections"
    else
        CHECK_readme="partial"
        DETAIL_readme="README.md found but only ${README_SECTIONS}/5 key sections (quick start, commands, architecture, install, contributing)"
    fi
fi
CHECKS="${CHECKS}{\"name\":\"readme-files\",\"status\":\"$CHECK_readme\",\"detail\":\"$DETAIL_readme\"},"

# Check 3: API documentation
CHECK_api="fail"
DETAIL_api="No API documentation found"
API_DOCS=()

for dir in docs/api api docs/swagger; do
    if [ -d "$dir" ]; then
        API_DOC_FILES=$(find "$dir" -type f 2>/dev/null | head -10)
        if [ -n "$API_DOC_FILES" ]; then
            API_DOCS+=("$dir")
        fi
    fi
done

OPENAPI_FILES=$(find . -maxdepth 2 -type f \( -name "openapi.*" -o -name "swagger.*" -o -name "api-spec.*" \) 2>/dev/null | head -5)
if [ -n "$OPENAPI_FILES" ]; then
    API_DOCS+=("openapi-spec")
fi

TYPED_DOC=$(grep -rl -E '@param|@returns|@throws|@example' --include="*.ts" --include="*.tsx" --include="*.js" . 2>/dev/null | head -5 || true)
if [ -n "$TYPED_DOC" ]; then
    API_DOCS+=("inline-typedoc")
fi

if [ ${#API_DOCS[@]} -gt 0 ]; then
    CHECK_api="pass"
    DETAIL_api="API documentation found: $(IFS=','; echo "${API_DOCS[*]}")"
fi
CHECKS="${CHECKS}{\"name\":\"api-documentation\",\"status\":\"$CHECK_api\",\"detail\":\"$DETAIL_api\"},"

# Check 4: Inline doc coverage
CHECK_inline="fail"
DETAIL_inline="No JSDoc/TSDoc coverage detected"
SOURCE_FILES=$(find . -type f \( -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" \) ! -path "*/node_modules/*" ! -path "*/dist/*" ! -path "*/.next/*" 2>/dev/null | head -50 || true)

if [ -n "$SOURCE_FILES" ]; then
    TOTAL_SRC=$(echo "$SOURCE_FILES" | wc -l)
    DOC_COMMENT_COUNT=0
    for f in $SOURCE_FILES; do
        if [ -f "$f" ]; then
            HAS_DOC=$(grep -cE '/\*\*' "$f" 2>/dev/null || echo "0")
            DOC_COMMENT_COUNT=$((DOC_COMMENT_COUNT + HAS_DOC))
        fi
    done

    if [ "$DOC_COMMENT_COUNT" -gt 0 ]; then
        if [ "$TOTAL_SRC" -gt 0 ]; then
            RATIO=$((DOC_COMMENT_COUNT * 100 / (TOTAL_SRC * 5)))
        else
            RATIO=0
        fi
        if [ "$RATIO" -ge 50 ]; then
            CHECK_inline="pass"
            DETAIL_inline="Good inline doc coverage (${DOC_COMMENT_COUNT} doc blocks across ${TOTAL_SRC} source files)"
        else
            CHECK_inline="partial"
            DETAIL_inline="Some inline documentation (${DOC_COMMENT_COUNT} doc blocks across ${TOTAL_SRC} source files)"
        fi
    fi
fi
CHECKS="${CHECKS}{\"name\":\"inline-doc-coverage\",\"status\":\"$CHECK_inline\",\"detail\":\"$DETAIL_inline\"}"

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

echo "{\"skill\":\"documentation-and-adrs\",\"status\":\"$OVERALL\",\"checks\":$CHECKS}"