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

# Check 1: Spec document existence
CHECK_spec="fail"
DETAIL_spec="No spec documents found"
SPEC_FILES=""

for dir in docs/specs docs/spec spec specs .opencode/specs; do
    if [ -d "$dir" ]; then
        FOUND=$(find "$dir" -type f -name "*.md" 2>/dev/null | head -20 || true)
        if [ -n "$FOUND" ]; then
            SPEC_FILES="${SPEC_FILES} ${FOUND}"
        fi
    fi
done

ROOT_SPECS=$(find . -maxdepth 1 -type f \( -name "SPEC*" -o -name "spec*" -o -name "*specification*" \) -name "*.md" 2>/dev/null | head -10 || true)
if [ -n "$ROOT_SPECS" ]; then
    SPEC_FILES="${SPEC_FILES} ${ROOT_SPECS}"
fi

SPEC_MDS=$(find . -maxdepth 3 -type f -name "*spec*.md" ! -path "*/node_modules/*" ! -path "*/.git/*" 2>/dev/null | head -20 || true)
if [ -n "$SPEC_MDS" ]; then
    SPEC_FILES="${SPEC_FILES} ${SPEC_MDS}"
fi

if [ -n "$SPEC_FILES" ]; then
    UNIQUE_SPECS=$(echo "$SPEC_FILES" | tr ' ' '\n' | sort -u | grep -v '^$' || true)
    SPEC_COUNT=$(echo "$UNIQUE_SPECS" | grep -c '.' 2>/dev/null || echo "0")
    if [ "$SPEC_COUNT" -gt 0 ] 2>/dev/null; then
        CHECK_spec="pass"
        DETAIL_spec="Found ${SPEC_COUNT} spec document(s)"
    else
        DETAIL_spec="No spec documents found in docs/specs, docs/spec, spec/, or project root"
    fi
fi
CHECKS="${CHECKS}{\"name\":\"spec-document-existence\",\"status\":\"$CHECK_spec\",\"detail\":\"$DETAIL_spec\"},"

# Check 2: Required sections covered (Objective, Success Criteria, Boundaries)
CHECK_sections="fail"
DETAIL_sections="No spec documents with required sections found"
SECTION_PASS=0
SECTION_TOTAL=0

REQUIRED_SECTIONS=("Objective" "Success Criteria" "Boundaries")

if [ -n "$UNIQUE_SPECS" ]; then
    for spec_file in $UNIQUE_SPECS; do
        if [ -f "$spec_file" ]; then
            CONTENT=$(cat "$spec_file" 2>/dev/null || true)
            if [ -n "$CONTENT" ]; then
                SECTION_TOTAL=$((SECTION_TOTAL + 1))
                FOUND_COUNT=0
                for section in "${REQUIRED_SECTIONS[@]}"; do
                    if echo "$CONTENT" | grep -qiE "##.*$section|^$section"; then
                        FOUND_COUNT=$((FOUND_COUNT + 1))
                    fi
                done
                if [ "$FOUND_COUNT" -eq "${#REQUIRED_SECTIONS[@]}" ]; then
                    SECTION_PASS=$((SECTION_PASS + 1))
                fi
            fi
        fi
    done
fi

if [ "$SECTION_TOTAL" -gt 0 ]; then
    if [ "$SECTION_PASS" -gt 0 ]; then
        if [ "$SECTION_PASS" -eq "$SECTION_TOTAL" ]; then
            CHECK_sections="pass"
            DETAIL_sections="All spec documents have required sections (Objective, Success Criteria, Boundaries)"
        else
            CHECK_sections="partial"
            DETAIL_sections="${SECTION_PASS}/${SECTION_TOTAL} spec documents have all required sections"
        fi
    else
        CHECK_sections="partial"
        DETAIL_sections="Spec documents found but missing required sections (Objective, Success Criteria, Boundaries)"
    fi
fi
CHECKS="${CHECKS}{\"name\":\"required-sections-covered\",\"status\":\"$CHECK_sections\",\"detail\":\"$DETAIL_sections\"},"

# Check 3: Success criteria defined and testable
CHECK_criteria="fail"
DETAIL_criteria="No testable success criteria found in specs"

if [ -n "$UNIQUE_SPECS" ]; then
    CRITERIA_FOUND=0
    for spec_file in $UNIQUE_SPECS; do
        if [ -f "$spec_file" ]; then
            CONTENT=$(cat "$spec_file" 2>/dev/null || true)
            if echo "$CONTENT" | grep -qiE '(success.?criteria|acceptance.?criteria|done.?when|definition.?of.?done)'; then
                CRITERIA_FOUND=$((CRITERIA_FOUND + 1))
            fi
        fi
    done

    if [ "$CRITERIA_FOUND" -gt 0 ]; then
        CHECK_criteria="pass"
        DETAIL_criteria="Found success/acceptance criteria in ${CRITERIA_FOUND} spec document(s)"
    fi
fi
CHECKS="${CHECKS}{\"name\":\"success-criteria-defined\",\"status\":\"$CHECK_criteria\",\"detail\":\"$DETAIL_criteria\"},"

# Check 4: Boundaries defined (Always/Ask First/Never)
CHECK_boundaries="fail"
DETAIL_boundaries="No boundaries (Always/Ask First/Never) found in specs"

if [ -n "$UNIQUE_SPECS" ]; then
    BOUNDARIES_FOUND=0
    for spec_file in $UNIQUE_SPECS; do
        if [ -f "$spec_file" ]; then
            CONTENT=$(cat "$spec_file" 2>/dev/null || true)
            if echo "$CONTENT" | grep -qiE '(always|ask.?first|never.?do|boundaries)'; then
                BOUNDARIES_FOUND=$((BOUNDARIES_FOUND + 1))
            fi
        fi
    done

    if [ "$BOUNDARIES_FOUND" -gt 0 ]; then
        CHECK_boundaries="pass"
        DETAIL_boundaries="Found boundary definitions in ${BOUNDARIES_FOUND} spec document(s)"
    fi
fi
CHECKS="${CHECKS}{\"name\":\"boundaries-defined\",\"status\":\"$CHECK_boundaries\",\"detail\":\"$DETAIL_boundaries\"}"

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

echo "{\"skill\":\"spec-driven-development\",\"status\":\"$OVERALL\",\"checks\":$CHECKS}"