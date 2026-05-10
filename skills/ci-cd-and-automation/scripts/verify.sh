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

# Check 1: CI config files exist
CHECK_ci="fail"
DETAIL_ci="No CI configuration files found"
CI_FILES=()
if [ -d ".github/workflows" ]; then
    WORKFLOW_COUNT=$(find .github/workflows -name "*.yml" -o -name "*.yaml" 2>/dev/null | wc -l)
    if [ "$WORKFLOW_COUNT" -gt 0 ]; then
        CI_FILES+=("github-actions (${WORKFLOW_COUNT} workflows)")
    fi
fi
if [ -f ".gitlab-ci.yml" ]; then
    CI_FILES+=("gitlab-ci")
fi
if [ -f "Jenkinsfile" ]; then
    CI_FILES+=("jenkins")
fi
if [ -f "circle.yml" ] || [ -d ".circleci" ]; then
    CI_FILES+=("circleci")
fi
if [ -f ".travis.yml" ]; then
    CI_FILES+=("travis")
fi
if [ ${#CI_FILES[@]} -gt 0 ]; then
    CHECK_ci="pass"
    DETAIL_ci="CI config found: $(IFS=','; echo "${CI_FILES[*]}")"
fi
CHECKS="${CHECKS}{\"name\":\"ci-config-files\",\"status\":\"$CHECK_ci\",\"detail\":\"$DETAIL_ci\"},"

# Check 2: Pipeline stages defined (lint, test, build)
CHECK_stages="fail"
DETAIL_stages="No pipeline stages detected"
STAGES_FOUND=()

if [ -d ".github/workflows" ]; then
    for f in .github/workflows/*.yml .github/workflows/*.yaml; do
        if [ -f "$f" ]; then
            CONTENT=$(cat "$f")
            if echo "$CONTENT" | grep -qiE '(lint|eslint|prettier|stylelint)'; then STAGES_FOUND+=("lint"); fi
            if echo "$CONTENT" | grep -qiE '(test|jest|vitest|mocha|pytest)'; then STAGES_FOUND+=("test"); fi
            if echo "$CONTENT" | grep -qiE '(build|compile|webpack|vite|transpil)'; then STAGES_FOUND+=("build"); fi
            if echo "$CONTENT" | grep -qiE '(typecheck|type-check|tsc.*--noEmit)'; then STAGES_FOUND+=("typecheck"); fi
        fi
    done
fi

if [ -f ".gitlab-ci.yml" ]; then
    CONTENT=$(cat ".gitlab-ci.yml")
    if echo "$CONTENT" | grep -qiE '(lint|eslint)'; then STAGES_FOUND+=("lint"); fi
    if echo "$CONTENT" | grep -qiE '(test|jest|vitest)'; then STAGES_FOUND+=("test"); fi
    if echo "$CONTENT" | grep -qiE '(build|compile)'; then STAGES_FOUND+=("build"); fi
fi

UNIQUE_STAGES=$(echo "${STAGES_FOUND[@]}" | tr ' ' '\n' | sort -u | tr '\n' ',' | sed 's/,$//')
if [ ${#STAGES_FOUND[@]} -ge 3 ]; then
    CHECK_stages="pass"
    DETAIL_stages="Pipeline stages found: $UNIQUE_STAGES"
elif [ ${#STAGES_FOUND[@]} -gt 0 ]; then
    CHECK_stages="partial"
    DETAIL_stages="Some pipeline stages found: $UNIQUE_STAGES"
fi
CHECKS="${CHECKS}{\"name\":\"pipeline-stages\",\"status\":\"$CHECK_stages\",\"detail\":\"$DETAIL_stages\"},"

# Check 3: Quality gates configured
CHECK_gates="fail"
DETAIL_gates="No quality gates detected in CI config"
GATES_FOUND=()

if [ -d ".github/workflows" ]; then
    for f in .github/workflows/*.yml .github/workflows/*.yaml; do
        if [ -f "$f" ]; then
            CONTENT=$(cat "$f")
            if echo "$CONTENT" | grep -qiE '(npm.*audit|audit-level|security)'; then GATES_FOUND+=("security-audit"); fi
            if echo "$CONTENT" | grep -qiE '(coverage|--coverage|codecov)'; then GATES_FOUND+=("coverage"); fi
            if echo "$CONTENT" | grep -qiE '(lint|eslint|prettier|stylelint)'; then GATES_FOUND+=("lint"); fi
            if echo "$CONTENT" | grep -qiE '(tsc|typecheck|type-check)'; then GATES_FOUND+=("typecheck"); fi
        fi
    done
fi

if [ ${#GATES_FOUND[@]} -ge 3 ]; then
    CHECK_gates="pass"
    DETAIL_gates="Quality gates: $(IFS=','; echo "${GATES_FOUND[*]}")"
elif [ ${#GATES_FOUND[@]} -gt 0 ]; then
    CHECK_gates="partial"
    DETAIL_gates="Some quality gates: $(IFS=','; echo "${GATES_FOUND[*]}")"
fi
CHECKS="${CHECKS}{\"name\":\"quality-gates\",\"status\":\"$CHECK_gates\",\"detail\":\"$DETAIL_gates\"},"

# Check 4: Deployment config
CHECK_deploy="fail"
DETAIL_deploy="No deployment configuration found"
DEPLOY_FOUND=()

if [ -d ".github/workflows" ]; then
    for f in .github/workflows/*.yml .github/workflows/*.yaml; do
        if [ -f "$f" ]; then
            CONTENT=$(cat "$f")
            if echo "$CONTENT" | grep -qiE '(deploy|vercel|netlify|aws|gcloud|azure|heroku)'; then
                DEPLOY_FOUND+=("github-actions-deploy")
                break
            fi
        fi
    done
fi
if [ -f "vercel.json" ] || [ -f "netlify.toml" ]; then DEPLOY_FOUND+=("platform-config"); fi
if [ -f "Dockerfile" ]; then DEPLOY_FOUND+=("docker"); fi
if [ -f "docker-compose.yml" ] || [ -f "docker-compose.yaml" ]; then DEPLOY_FOUND+=("docker-compose"); fi
if [ -d "k8s" ] || [ -d "kubernetes" ]; then DEPLOY_FOUND+=("kubernetes"); fi
if [ -f "terraform" ] || [ -d "terraform" ]; then DEPLOY_FOUND+=("terraform"); fi

if [ ${#DEPLOY_FOUND[@]} -gt 0 ]; then
    CHECK_deploy="pass"
    DETAIL_deploy="Deployment config found: $(IFS=','; echo "${DEPLOY_FOUND[*]}")"
fi
CHECKS="${CHECKS}{\"name\":\"deployment-config\",\"status\":\"$CHECK_deploy\",\"detail\":\"$DETAIL_deploy\"},"

# Check 5: Secrets not in code
CHECK_secrets="pass"
DETAIL_secrets="No secrets detected in tracked files"
if [ -d ".git" ]; then
    SECRET_FILES=$(git ls-files 2>/dev/null | while read -r f; do
        case "$f" in
            *.env|*.env.local|*.env.production|*credentials*|*secret*) echo "$f" ;;
        esac
    done || true)
    if [ -n "$SECRET_FILES" ]; then
        CHECK_secrets="fail"
        DETAIL_secrets="Potential secret files tracked: $(echo "$SECRET_FILES" | tr '\n' ', ')"
    fi
fi
if [ -f ".env" ] && [ -d ".git" ]; then
    if git ls-files --error-unmatch .env 2>/dev/null; then
        CHECK_secrets="fail"
        DETAIL_secrets=".env file is tracked in git"
    fi
fi
CHECKS="${CHECKS}{\"name\":\"secrets-not-in-code\",\"status\":\"$CHECK_secrets\",\"detail\":\"$DETAIL_secrets\"}"

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

echo "{\"skill\":\"ci-cd-and-automation\",\"status\":\"$OVERALL\",\"checks\":$CHECKS}"