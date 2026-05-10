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

# Check 1: Skills directory structure
CHECK_structure="fail"
DETAIL_structure="No skills directory found"
SKILLS_DIR=""

for dir in skills .opencode/skills; do
    if [ -d "$dir" ]; then
        SKILLS_DIR="$dir"
        break
    fi
done

if [ -n "$SKILLS_DIR" ]; then
    SKILL_COUNT=$(find "$SKILLS_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l)
    if [ "$SKILL_COUNT" -gt 0 ]; then
        CHECK_structure="pass"
        DETAIL_structure="Skills directory found with ${SKILL_COUNT} skills at ${SKILLS_DIR}/"
    else
        CHECK_structure="partial"
        DETAIL_structure="Skills directory exists but is empty"
    fi
fi
CHECKS="${CHECKS}{\"name\":\"skills-directory-structure\",\"status\":\"$CHECK_structure\",\"detail\":\"$DETAIL_structure\"},"

# Check 2: SKILL.md frontmatter validity
CHECK_frontmatter="fail"
DETAIL_frontmatter="No SKILL.md files with valid frontmatter found"
VALID_COUNT=0
INVALID_COUNT=0

if [ -n "$SKILLS_DIR" ]; then
    for skill_dir in "$SKILLS_DIR"/*/; do
        SKILL_FILE="${skill_dir}SKILL.md"
        if [ -f "$SKILL_FILE" ]; then
            FIRST_LINE=$(head -1 "$SKILL_FILE")
            if [ "$FIRST_LINE" = "---" ]; then
                HAS_NAME=$(grep -c '^name:' "$SKILL_FILE" 2>/dev/null || echo "0")
                HAS_DESC=$(grep -c '^description:' "$SKILL_FILE" 2>/dev/null || echo "0")
                if [ "$HAS_NAME" -gt 0 ] && [ "$HAS_DESC" -gt 0 ]; then
                    VALID_COUNT=$((VALID_COUNT + 1))
                else
                    INVALID_COUNT=$((INVALID_COUNT + 1))
                fi
            else
                INVALID_COUNT=$((INVALID_COUNT + 1))
            fi
        fi
    done
fi

if [ "$VALID_COUNT" -gt 0 ]; then
    if [ "$INVALID_COUNT" -eq 0 ]; then
        CHECK_frontmatter="pass"
        DETAIL_frontmatter="All ${VALID_COUNT} SKILL.md files have valid frontmatter"
    else
        CHECK_frontmatter="partial"
        DETAIL_frontmatter="${VALID_COUNT} valid, ${INVALID_COUNT} invalid SKILL.md frontmatter"
    fi
fi
CHECKS="${CHECKS}{\"name\":\"skill-frontmatter-validity\",\"status\":\"$CHECK_frontmatter\",\"detail\":\"$DETAIL_frontmatter\"},"

# Check 3: Required sections in SKILL.md files
CHECK_sections="fail"
DETAIL_sections="No SKILL.md files with required sections found"
SECTION_PASS=0
SECTION_FAIL=0

REQUIRED_SECTIONS=("Overview" "When to Use" "Verification")

if [ -n "$SKILLS_DIR" ]; then
    for skill_dir in "$SKILLS_DIR"/*/; do
        SKILL_FILE="${skill_dir}SKILL.md"
        if [ -f "$SKILL_FILE" ]; then
            SECTIONS_FOUND=0
            CONTENT=$(cat "$SKILL_FILE")
            for section in "${REQUIRED_SECTIONS[@]}"; do
                if echo "$CONTENT" | grep -qiE "##.*$section|^$section"; then
                    SECTIONS_FOUND=$((SECTIONS_FOUND + 1))
                fi
            done
            if [ "$SECTIONS_FOUND" -eq "${#REQUIRED_SECTIONS[@]}" ]; then
                SECTION_PASS=$((SECTION_PASS + 1))
            else
                SECTION_FAIL=$((SECTION_FAIL + 1))
            fi
        fi
    done
fi

if [ "$SECTION_PASS" -gt 0 ]; then
    if [ "$SECTION_FAIL" -eq 0 ]; then
        CHECK_sections="pass"
        DETAIL_sections="All ${SECTION_PASS} SKILL.md files have required sections (Overview, When to Use, Verification)"
    else
        CHECK_sections="partial"
        DETAIL_sections="${SECTION_PASS} SKILL.md files have all sections, ${SECTION_FAIL} are missing sections"
    fi
fi
CHECKS="${CHECKS}{\"name\":\"required-sections-present\",\"status\":\"$CHECK_sections\",\"detail\":\"$DETAIL_sections\"},"

# Check 4: Scripts directory exists for each skill
CHECK_scripts="fail"
DETAIL_scripts="No skills with scripts directories found"
SCRIPTS_COUNT=0
NO_SCRIPTS_COUNT=0

if [ -n "$SKILLS_DIR" ]; then
    for skill_dir in "$SKILLS_DIR"/*/; do
        if [ -d "${skill_dir}scripts" ]; then
            SCRIPT_COUNT=$(find "${skill_dir}scripts" -type f 2>/dev/null | wc -l)
            if [ "$SCRIPT_COUNT" -gt 0 ]; then
                SCRIPTS_COUNT=$((SCRIPTS_COUNT + 1))
            else
                NO_SCRIPTS_COUNT=$((NO_SCRIPTS_COUNT + 1))
            fi
        else
            NO_SCRIPTS_COUNT=$((NO_SCRIPTS_COUNT + 1))
        fi
    done
fi

if [ "$SCRIPTS_COUNT" -gt 0 ]; then
    TOTAL=$((SCRIPTS_COUNT + NO_SCRIPTS_COUNT))
    if [ "$NO_SCRIPTS_COUNT" -eq 0 ]; then
        CHECK_scripts="pass"
        DETAIL_scripts="All ${TOTAL} skills have scripts directories"
    else
        CHECK_scripts="partial"
        DETAIL_scripts="${SCRIPTS_COUNT}/${TOTAL} skills have scripts directories, ${NO_SCRIPTS_COUNT} missing"
    fi
fi
CHECKS="${CHECKS}{\"name\":\"scripts-directory-exists\",\"status\":\"$CHECK_scripts\",\"detail\":\"$DETAIL_scripts\"}"

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

echo "{\"skill\":\"using-agent-skills\",\"status\":\"$OVERALL\",\"checks\":$CHECKS}"