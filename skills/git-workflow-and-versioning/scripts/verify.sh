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

# Check 1: Git repo initialized
CHECK_git_repo="fail"
DETAIL_git_repo="No git repository found"
if [ -d ".git" ]; then
    CHECK_git_repo="pass"
    DETAIL_git_repo="Git repository initialized"
fi
CHECKS="${CHECKS}{\"name\":\"git-repo-initialized\",\"status\":\"$CHECK_git_repo\",\"detail\":\"$DETAIL_git_repo\"},"

# Check 2: Commit message conventions
CHECK_conv="fail"
DETAIL_conv="No conventional commit messages found"
if [ -d ".git" ]; then
    CONVENTIONAL_COUNT=$(git log --oneline -20 2>/dev/null | grep -cE '^(feat|fix|refactor|test|docs|chore|perf|ci|build|style)(\(.+\))?:' || echo "0")
    TOTAL_COUNT=$(git log --oneline -20 2>/dev/null | wc -l || echo "0")
    if [ "$TOTAL_COUNT" -gt 0 ] && [ "$CONVENTIONAL_COUNT" -gt 0 ]; then
        RATIO=$((CONVENTIONAL_COUNT * 100 / TOTAL_COUNT))
        if [ "$RATIO" -ge 50 ]; then
            CHECK_conv="pass"
            DETAIL_conv="Conventional commits used in ${CONVENTIONAL_COUNT}/${TOTAL_COUNT} recent commits (${RATIO}%)"
        else
            CHECK_conv="partial"
            DETAIL_conv="Conventional commits used in ${CONVENTIONAL_COUNT}/${TOTAL_COUNT} recent commits (${RATIO}%)"
        fi
    fi
fi
CHECKS="${CHECKS}{\"name\":\"commit-message-conventions\",\"status\":\"$CHECK_conv\",\"detail\":\"$DETAIL_conv\"},"

# Check 3: Branch naming conventions
CHECK_branch="fail"
DETAIL_branch="No feature/fix/chore branches found"
if [ -d ".git" ]; then
    BRANCHES=$(git branch -a 2>/dev/null | grep -v '^\*' | grep -v 'HEAD' | sed 's/^[[:space:]]*//' | sed 's|remotes/origin/||' || true)
    CONVENTIONAL_BRANCHES=$(echo "$BRANCHES" | grep -cE '^(feature/|fix/|chore/|refactor/|main|master|develop|release/|hotfix/)' || echo "0")
    TOTAL_BRANCHES=$(echo "$BRANCHES" | grep -cE '.' || echo "0")
    if [ "$TOTAL_BRANCHES" -gt 0 ] && [ "$CONVENTIONAL_BRANCHES" -gt 0 ]; then
        CHECK_branch="pass"
        DETAIL_branch="Conventional branch naming used in ${CONVENTIONAL_BRANCHES}/${TOTAL_BRANCHES} branches"
    elif [ "$TOTAL_BRANCHES" -eq 0 ]; then
        CHECK_branch="partial"
        DETAIL_branch="Only default branch exists, no branch naming to verify"
    fi
fi
CHECKS="${CHECKS}{\"name\":\"branch-naming-conventions\",\"status\":\"$CHECK_branch\",\"detail\":\"$DETAIL_branch\"},"

# Check 4: Atomic commits (no commits > 1000 lines)
CHECK_atomic="pass"
DETAIL_atomic="Recent commits are reasonably sized"
if [ -d ".git" ]; then
    LARGE_COMMITS=$(git log --oneline -10 2>/dev/null | while read -r hash msg; do
        LINES=$(git diff-tree --no-commit-id -r "$hash" 2>/dev/null | wc -l || echo "0")
        if [ "$LINES" -gt 1000 ]; then
            echo "large"
        fi
    done | grep -c "large" || echo "0")
    if [ "$LARGE_COMMITS" -gt 0 ] 2>/dev/null; then
        CHECK_atomic="partial"
        DETAIL_atomic="${LARGE_COMMITS} of last 10 commits touch >1000 lines"
    fi
fi
CHECKS="${CHECKS}{\"name\":\"atomic-commits-pattern\",\"status\":\"$CHECK_atomic\",\"detail\":\"$DETAIL_atomic\"},"

# Check 5: No large binary files tracked
CHECK_binary="pass"
DETAIL_binary="No large binary files detected in git tracking"
if [ -d ".git" ]; then
    LARGE_FILES=$(git ls-files 2>/dev/null | while read -r f; do
        if [ -f "$f" ]; then
            SIZE=$(wc -c < "$f" 2>/dev/null || echo "0")
            if [ "$SIZE" -gt 1048576 ]; then
                echo "$f"
            fi
        fi
    done | head -5 || true)
    if [ -n "$LARGE_FILES" ]; then
        CHECK_binary="fail"
        DETAIL_binary="Large files found: $(echo "$LARGE_FILES" | tr '\n' ', ')"
    fi
fi
CHECKS="${CHECKS}{\"name\":\"no-large-binary-files\",\"status\":\"$CHECK_binary\",\"detail\":\"$DETAIL_binary\"},"

# Check 6: .gitignore exists and covers standard exclusions
CHECK_gitignore="fail"
DETAIL_gitignore="No .gitignore file found"
if [ -f ".gitignore" ]; then
    IGNORE_CONTENT=$(cat .gitignore)
    MISSING=()
    for pattern in "node_modules" ".env"; do
        if ! echo "$IGNORE_CONTENT" | grep -q "$pattern"; then
            MISSING+=("$pattern")
        fi
    done
    if [ ${#MISSING[@]} -eq 0 ]; then
        CHECK_gitignore="pass"
        DETAIL_gitignore=".gitignore covers standard exclusions"
    else
        CHECK_gitignore="partial"
        DETAIL_gitignore=".gitignore exists but missing: ${MISSING[*]}"
    fi
fi
CHECKS="${CHECKS}{\"name\":\"gitignore-standards\",\"status\":\"$CHECK_gitignore\",\"detail\":\"$DETAIL_gitignore\"}"

CHECKS="${CHECKS}]"

# Determine overall status
PASS_COUNT=$(echo "$CHECKS" | grep -o '"status":"pass"' | wc -l)
FAIL_COUNT=$(echo "$CHECKS" | grep -o '"status":"fail"' | wc -l)
PARTIAL_COUNT=$(echo "$CHECKS" | grep -o '"status":"partial"' | wc -l)
TOTAL=$((PASS_COUNT + FAIL_COUNT + PARTIAL_COUNT))

if [ "$FAIL_COUNT" -gt 0 ]; then
    OVERALL="fail"
elif [ "$PARTIAL_COUNT" -gt 0 ]; then
    OVERALL="partial"
else
    OVERALL="pass"
fi

echo "{\"skill\":\"git-workflow-and-versioning\",\"status\":\"$OVERALL\",\"checks\":$CHECKS}"