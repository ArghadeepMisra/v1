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

# Check 1: Rollback procedures documented
CHECK_rollback="fail"
DETAIL_rollback="No rollback procedures found"
ROLLBACK_FOUND=()

RECOVERY_DOCS=$(find . -type f \( -name "*rollback*" -o -name "*recovery*" -o -name "*deploy*" -o -name "*release*" \) ! -path "*/node_modules/*" ! -path "*/.git/*" 2>/dev/null | head -10)
if [ -n "$RECOVERY_DOCS" ]; then
    ROLLBACK_FOUND+=("recovery-docs")
fi

if [ -d ".github/workflows" ]; then
    for f in .github/workflows/*.yml .github/workflows/*.yaml; do
        if [ -f "$f" ]; then
            CONTENT=$(cat "$f")
            if echo "$CONTENT" | grep -qiE '(rollback|revert|rollback)'; then
                ROLLBACK_FOUND+=("ci-rollback")
                break
            fi
        fi
    done
fi

MAKEFILE_CONTENT=""
if [ -f "Makefile" ]; then
    MAKEFILE_CONTENT=$(cat Makefile)
    if echo "$MAKEFILE_CONTENT" | grep -qiE 'rollback|revert|undo'; then
        ROLLBACK_FOUND+=("makefile-rollback")
    fi
fi

SCRIPTS_ROLLBACK=$(find . -path "*/scripts/*" -type f \( -name "*rollback*" -o -name "*revert*" -o -name "*deploy*" \) ! -path "*/node_modules/*" 2>/dev/null | head -5)
if [ -n "$SCRIPTS_ROLLBACK" ]; then
    ROLLBACK_FOUND+=("deploy-scripts")
fi

if [ ${#ROLLBACK_FOUND[@]} -gt 0 ]; then
    CHECK_rollback="pass"
    DETAIL_rollback="Rollback/recovery procedures found: $(IFS=','; echo "${ROLLBACK_FOUND[*]}")"
else
    DETAIL_rollback="No rollback procedures, docs, or scripts found"
fi
CHECKS="${CHECKS}{\"name\":\"rollback-procedures\",\"status\":\"$CHECK_rollback\",\"detail\":\"$DETAIL_rollback\"},"

# Check 2: Monitoring configuration
CHECK_monitoring="fail"
DETAIL_monitoring="No monitoring configuration found"
MONITORING_FOUND=()

for dir in monitoring dashboards grafana prometheus config; do
    if [ -d "$dir" ]; then
        MONITORING_FOUND+=("$dir/")
    fi
done

MONITORING_FILES=$(find . -maxdepth 3 -type f \( -name "*monitor*" -o -name "*grafana*" -o -name "*prometheus*" -o -name "*datadog*" -o -name "*sentry*" -o -name "*newrelic*" \) ! -path "*/node_modules/*" ! -path "*/.git/*" 2>/dev/null | head -10)
if [ -n "$MONITORING_FILES" ]; then
    MONITORING_FOUND+=("monitoring-config-files")
fi

if [ -f "package.json" ]; then
    PKG_CONTENT=$(cat package.json)
    if echo "$PKG_CONTENT" | grep -qiE '(sentry|datadog|newrelic|prometheus|grafana|opentelemetry)'; then
        MONITORING_FOUND+=("monitoring-dependencies")
    fi
fi

if [ ${#MONITORING_FOUND[@]} -gt 0 ]; then
    CHECK_monitoring="pass"
    DETAIL_monitoring="Monitoring found: $(IFS=','; echo "${MONITORING_FOUND[*]}")"
fi
CHECKS="${CHECKS}{\"name\":\"monitoring-config\",\"status\":\"$CHECK_monitoring\",\"detail\":\"$DETAIL_monitoring\"},"

# Check 3: Feature flag setup
CHECK_flags="fail"
DETAIL_flags="No feature flag setup detected"
FLAGS_FOUND=()

if [ -f "package.json" ]; then
    PKG_CONTENT=$(cat package.json)
    if echo "$PKG_CONTENT" | grep -qiE '(launchdarkly|unleash|splitio|optimizely|flagsmith|feature.?flag|flipper)'; then
        FLAGS_FOUND+=("flag-dependency")
    fi
fi

FLAG_FILES=$(find . -maxdepth 4 -type f \( -name "*feature*flag*" -o -name "*flags*" -o -name "*feature*toggle*" \) ! -path "*/node_modules/*" ! -path "*/.git/*" 2>/dev/null | head -10)
if [ -n "$FLAG_FILES" ]; then
    FLAGS_FOUND+=("flag-files")
fi

SOURCE_FLAGS=$(grep -rl -E 'featureFlag|feature.?flag|isFeatureEnabled|toggleFeature|flagService' --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" . 2>/dev/null | head -10 || true)
if [ -n "$SOURCE_FLAGS" ]; then
    FLAGS_FOUND+=("source-flag-references")
fi

if [ ${#FLAGS_FOUND[@]} -gt 0 ]; then
    CHECK_flags="pass"
    DETAIL_flags="Feature flag setup found: $(IFS=','; echo "${FLAGS_FOUND[*]}")"
fi
CHECKS="${CHECKS}{\"name\":\"feature-flag-setup\",\"status\":\"$CHECK_flags\",\"detail\":\"$DETAIL_flags\"},"

# Check 4: Health check endpoints
CHECK_health="fail"
DETAIL_health="No health check endpoints detected"
HEALTH_FOUND=()

HEALTH_SOURCE=$(grep -rl -E '(/health|/healthz|/readiness|/liveness|health.?check|healthCheck)' --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" --include="*.py" --include="*.go" . 2>/dev/null | head -10 || true)
if [ -n "$HEALTH_SOURCE" ]; then
    HEALTH_FOUND+=("health-endpoint-in-source")
fi

if [ -f "Dockerfile" ]; then
    DOCKER_CONTENT=$(cat Dockerfile)
    if echo "$DOCKER_CONTENT" | grep -qiE 'HEALTHCHECK'; then
        HEALTH_FOUND+=("docker-healthcheck")
    fi
fi

HEALTH_ROUTES=$(grep -rl -E 'health|readiness|liveness|alive' --include="*routes*" --include="*router*" . 2>/dev/null | head -5 || true)
if [ -n "$HEALTH_ROUTES" ]; then
    HEALTH_FOUND+=("health-routes")
fi

if [ ${#HEALTH_FOUND[@]} -gt 0 ]; then
    CHECK_health="pass"
    DETAIL_health="Health check endpoints found: $(IFS=','; echo "${HEALTH_FOUND[*]}")"
fi
CHECKS="${CHECKS}{\"name\":\"health-check-endpoints\",\"status\":\"$CHECK_health\",\"detail\":\"$DETAIL_health\"},"

# Check 5: Environment variable documentation
CHECK_env="fail"
DETAIL_env="No environment variable documentation found"
ENV_FOUND=()

if [ -f ".env.example" ] || [ -f ".env.sample" ] || [ -f ".env.template" ]; then
    ENV_FOUND+=("env-example")
fi

ENV_DOCS=$(find . -maxdepth 2 -type f \( -name "*env*doc*" -o -name "*environment*" -o -name "ENV*" \) ! -path "*/node_modules/*" ! -path "*/.git/*" 2>/dev/null | head -5)
if [ -n "$ENV_DOCS" ]; then
    ENV_FOUND+=("env-doc-files")
fi

if [ -f "README.md" ]; then
    README_CONTENT=$(cat README.md)
    if echo "$README_CONTENT" | grep -qiE '(environment.?variable|\.env|env.?config)'; then
        ENV_FOUND+=("readme-env-section")
    fi
fi

if [ ${#ENV_FOUND[@]} -gt 0 ]; then
    CHECK_env="pass"
    DETAIL_env="Environment variable docs found: $(IFS=','; echo "${ENV_FOUND[*]}")"
fi
CHECKS="${CHECKS}{\"name\":\"env-variable-documentation\",\"status\":\"$CHECK_env\",\"detail\":\"$DETAIL_env\"}"

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

echo "{\"skill\":\"shipping-and-launch\",\"status\":\"$OVERALL\",\"checks\":$CHECKS}"