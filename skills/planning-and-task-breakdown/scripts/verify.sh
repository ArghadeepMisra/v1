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

# Collect plan/task documents
PLAN_FILES=""

for dir in docs/plans docs/tasks docs/plan docs/task plans tasks; do
    if [ -d "$dir" ]; then
        FOUND=$(find "$dir" -type f -name "*.md" 2>/dev/null | head -20 || true)
        if [ -n "$FOUND" ]; then
            PLAN_FILES="${PLAN_FILES} ${FOUND}"
        fi
    fi
done

ROOT_PLANS=$(find . -maxdepth 1 -type f \( -name "*plan*" -o -name "*task*breakdown*" -o -name "*implementation*plan*" \) -name "*.md" 2>/dev/null | head -10 || true)
if [ -n "$ROOT_PLANS" ]; then
    PLAN_FILES="${PLAN_FILES} ${ROOT_PLANS}"
fi

DEEPER_PLANS=$(find . -maxdepth 3 -type f \( -name "*plan*.md" -o -name "*task*.md" \) ! -path "*/node_modules/*" ! -path "*/.git/*" ! -path "*/docs/specs/*" 2>/dev/null | head -20 || true)
if [ -n "$DEEPER_PLANS" ]; then
    PLAN_FILES="${PLAN_FILES} ${DEEPER_PLANS}"
fi

# Deduplicate
UNIQUE_PLANS=""
if [ -n "$PLAN_FILES" ]; then
    UNIQUE_PLANS=$(echo "$PLAN_FILES" | tr ' ' '\n' | sort -u | grep -v '^$' || true)
fi

PLAN_COUNT=0
if [ -n "$UNIQUE_PLANS" ]; then
    PLAN_COUNT=$(echo "$UNIQUE_PLANS" | wc -l)
fi

# Check 1: Task breakdown documents exist
CHECK_breakdown="fail"
DETAIL_breakdown="No task breakdown or plan documents found"

if [ "$PLAN_COUNT" -gt 0 ]; then
    CHECK_breakdown="pass"
    DETAIL_breakdown="Found ${PLAN_COUNT} task/plan document(s)"
fi
CHECKS="${CHECKS}{\"name\":\"task-breakdown-documents\",\"status\":\"$CHECK_breakdown\",\"detail\":\"$DETAIL_breakdown\"},"

# Check 2: Acceptance criteria present
CHECK_acceptance="fail"
DETAIL_acceptance="No acceptance criteria found in plan documents"

if [ -n "$UNIQUE_PLANS" ]; then
    ACCEPTANCE_COUNT=0
    for plan_file in $UNIQUE_PLANS; do
        if [ -f "$plan_file" ]; then
            CONTENT=$(cat "$plan_file" 2>/dev/null || true)
            if echo "$CONTENT" | grep -qiE '(acceptance.?criteria|done.?when|definition.?of.?done|verify|verification)'; then
                ACCEPTANCE_COUNT=$((ACCEPTANCE_COUNT + 1))
            fi
        fi
    done

    if [ "$ACCEPTANCE_COUNT" -gt 0 ]; then
        CHECK_acceptance="pass"
        DETAIL_acceptance="Found acceptance criteria in ${ACCEPTANCE_COUNT} document(s)"
    fi
fi
CHECKS="${CHECKS}{\"name\":\"acceptance-criteria\",\"status\":\"$CHECK_acceptance\",\"detail\":\"$DETAIL_acceptance\"},"

# Check 3: Dependency ordering present
CHECK_deps="fail"
DETAIL_deps="No dependency ordering found in plan documents"

if [ -n "$UNIQUE_PLANS" ]; then
    DEPS_COUNT=0
    for plan_file in $UNIQUE_PLANS; do
        if [ -f "$plan_file" ]; then
            CONTENT=$(cat "$plan_file" 2>/dev/null || true)
            if echo "$CONTENT" | grep -qiE '(depend|phase|order|prerequisite|before|after|must.?be|sequential)'; then
                DEPS_COUNT=$((DEPS_COUNT + 1))
            fi
        fi
    done

    if [ "$DEPS_COUNT" -gt 0 ]; then
        CHECK_deps="pass"
        DETAIL_deps="Found dependency ordering in ${DEPS_COUNT} document(s)"
    fi
fi
CHECKS="${CHECKS}{\"name\":\"dependency-ordering\",\"status\":\"$CHECK_deps\",\"detail\":\"$DETAIL_deps\"},"

# Check 4: Reasonable task sizes
CHECK_sizes="fail"
DETAIL_sizes="No task size information found in plan documents"

if [ -n "$UNIQUE_PLANS" ]; then
    SIZED_COUNT=0
    UNSIZED_COUNT=0
    for plan_file in $UNIQUE_PLANS; do
        if [ -f "$plan_file" ]; then
            CONTENT=$(cat "$plan_file" 2>/dev/null || true)
            SIZE_LABELS=$(echo "$CONTENT" | grep -ciE '(small|medium|large|XS|XL|scope|files)' 2>/dev/null || echo "0")
            if [ "$SIZE_LABELS" -gt 0 ]; then
                SIZED_COUNT=$((SIZED_COUNT + 1))
            else
                TASK_BLOCKS=$(echo "$CONTENT" | grep -ciE '(task|phase|step|slice)' 2>/dev/null || echo "0")
                if [ "$TASK_BLOCKS" -gt 0 ]; then
                    SIZED_COUNT=$((SIZED_COUNT + 1))
                else
                    UNSIZED_COUNT=$((UNSIZED_COUNT + 1))
                fi
            fi
        fi
    done

    if [ "$SIZED_COUNT" -gt 0 ]; then
        if [ "$UNSIZED_COUNT" -eq 0 ]; then
            CHECK_sizes="pass"
            DETAIL_sizes="Plan documents include task sizing information"
        else
            CHECK_sizes="partial"
            DETAIL_sizes="${SIZED_COUNT} document(s) have sizing, ${UNSIZED_COUNT} lack sizing info"
        fi
    fi
fi
CHECKS="${CHECKS}{\"name\":\"reasonable-task-sizes\",\"status\":\"$CHECK_sizes\",\"detail\":\"$DETAIL_sizes\"}"

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

echo "{\"skill\":\"planning-and-task-breakdown\",\"status\":\"$OVERALL\",\"checks\":$CHECKS}"