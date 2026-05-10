#!/bin/bash
set -e

PROJECT_DIR="."
TMPDIR_PREFIX="/tmp/sec-verify-"

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

check_dependency_audit() {
  local status="fail"
  local detail="No dependency audit tool found"

  if [ -f "$PROJECT_DIR/package.json" ]; then
    if [ -f "$PROJECT_DIR/package-lock.json" ] || [ -f "$PROJECT_DIR/yarn.lock" ] || [ -f "$PROJECT_DIR/pnpm-lock.yaml" ]; then
      if command -v npm &>/dev/null; then
        status="partial"
        detail="npm audit available (run npm audit to check vulnerabilities)"
      else
        detail="package.json found but npm not available"
      fi
    else
      detail="package.json found but no lock file for audit"
    fi
  elif [ -f "$PROJECT_DIR/requirements.txt" ] || [ -f "$PROJECT_DIR/pyproject.toml" ] || [ -f "$PROJECT_DIR/Pipfile" ]; then
    if command -v pip-audit &>/dev/null; then
      status="partial"
      detail="pip-audit available (run pip-audit to check vulnerabilities)"
    elif command -v pip &>/dev/null; then
      status="partial"
      detail="pip available (install pip-audit for full audit)"
    else
      detail="Python dependencies found but no audit tool available"
    fi
  elif [ -f "$PROJECT_DIR/go.sum" ] || [ -f "$PROJECT_DIR/go.mod" ]; then
    if command -v govulncheck &>/dev/null; then
      status="partial"
      detail="govulncheck available (run govulncheck ./...)"
    else
      detail="Go module found but govulncheck not available"
    fi
  fi

  echo "{\"name\":\"dependency_audit\",\"status\":\"$status\",\"detail\":\"$detail\"}"
}

check_secrets_detection() {
  local status="pass"
  local detail="No secrets detected in source files"
  local found=()

  local secret_patterns='(password\s*=\s*["\x27][^"\x27]{4,}|api_key\s*=\s*["\x27][^"\x27]{8,}|secret_key\s*=\s*["\x27][^"\x27]{8,}|token\s*=\s*["\x27][^"\x27]{8,}|PRIVATE_KEY|BEGIN RSA PRIVATE KEY|BEGIN PGP PRIVATE KEY)'

  for dir in "$PROJECT_DIR/src" "$PROJECT_DIR/lib" "$PROJECT_DIR/app" "$PROJECT_DIR/pkg" "$PROJECT_DIR/config" "$PROJECT_DIR"; do
    if [ -d "$dir" ]; then
      while IFS= read -r match; do
        if [ -n "$match" ]; then
          found+=("$match")
        fi
      done < <(grep -rE "$secret_patterns" "$dir" --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" --include="*.py" --include="*.go" --include="*.env.example" --include="*.json" 2>/dev/null | head -10 || true)
    fi
  done

  if [ ${#found[@]} -gt 0 ]; then
    status="fail"
    detail="Potential secrets found in ${#found[@]} location(s)"
  fi

  local gitignore_secrets="true"
  if [ -f "$PROJECT_DIR/.gitignore" ]; then
    for pattern in ".env" "*.key" "*.pem"; do
      if ! grep -q "$pattern" "$PROJECT_DIR/.gitignore" 2>/dev/null; then
        gitignore_secrets="false"
      fi
    done
  else
    gitignore_secrets="false"
  fi

  if [ "$gitignore_secrets" = "false" ]; then
    if [ "$status" = "pass" ]; then
      status="partial"
      detail=".gitignore missing secret patterns (.env, *.key, *.pem)"
    fi
  fi

  echo "{\"name\":\"secrets_detection\",\"status\":\"$status\",\"detail\":\"$detail\"}"
}

check_auth_patterns() {
  local status="fail"
  local detail="No authentication/authorization patterns found"
  local found=()

  for dir in "$PROJECT_DIR/src" "$PROJECT_DIR/lib" "$PROJECT_DIR/app" "$PROJECT_DIR/pkg"; do
    if [ -d "$dir" ]; then
      if find "$dir" -type f \( -name "*.ts" -o -name "*.js" -o -name "*.py" -o -name "*.go" \) -exec grep -lE '(authenticate|authMiddleware|requireAuth|isAuthenticated|@authenticated|jwt|passport|bcrypt|argon2)' {} \; 2>/dev/null | head -3 | grep -q .; then
        found+=("auth-middleware")
        break
      fi
    fi
  done

  for dir in "$PROJECT_DIR/src" "$PROJECT_DIR/lib" "$PROJECT_DIR/app" "$PROJECT_DIR/pkg"; do
    if [ -d "$dir" ]; then
      if find "$dir" -type f \( -name "*.ts" -o -name "*.js" -o -name "*.py" -o -name "*.go" \) -exec grep -lE '(authorize|authorization|isAuthorized|@authorized|@requiresRole|canAccess|hasPermission|checkPermission)' {} \; 2>/dev/null | head -3 | grep -q .; then
        found+=("authorization-checks")
        break
      fi
    fi
  done

  for f in "$PROJECT_DIR/src/middleware/auth"* "$PROJECT_DIR/src/auth"* "$PROJECT_DIR/src/routes/auth"* "$PROJECT_DIR/app/middleware/auth"*; do
    if ls $f* 2>/dev/null | grep -q .; then
      found+=("auth-module")
      break
    fi
  done

  if [ ${#found[@]} -gt 0 ]; then
    status="pass"
    detail="Auth patterns found: ${found[*]}"
  fi

  echo "{\"name\":\"auth_patterns\",\"status\":\"$status\",\"detail\":\"$detail\"}"
}

check_security_headers() {
  local status="fail"
  local detail="No security headers configuration found"
  local found=()

  for dir in "$PROJECT_DIR/src" "$PROJECT_DIR/lib" "$PROJECT_DIR/app" "$PROJECT_DIR/config" "$PROJECT_DIR"; do
    if [ -d "$dir" ]; then
      if find "$dir" -maxdepth 1 -type f \( -name "*.ts" -o -name "*.js" -o -name "*.py" -o -name "*.go" \) -exec grep -lE '(helmet|contentSecurityPolicy|csp|x-frame-options|X-Content-Type-Options|strict-transport-security|HSTS|cors\(|CORS)' {} \; 2>/dev/null | head -3 | grep -q .; then
        found+=("security-headers-config")
        break
      fi
    fi
  done

  if find "$PROJECT_DIR" -maxdepth 3 -name "next.config"* -o -name "nuxt.config"* -o -name "_headers" -o -name "vercel.json" 2>/dev/null | head -3 | grep -q .; then
    found+=("framework-security-config")
  fi

  for f in "$PROJECT_DIR/src/middleware"* "$PROJECT_DIR/app/middleware"*; do
    if ls "$f"* 2>/dev/null | head -3 | grep -q .; then
      if grep -rlE '(helmet|security|cors|Content-Security-Policy)' "$f"* 2>/dev/null | head -1 | grep -q .; then
        found+=("middleware-security")
        break
      fi
    fi
  done

  if [ ${#found[@]} -gt 0 ]; then
    status="pass"
    detail="Security headers found: ${found[*]}"
  fi

  echo "{\"name\":\"security_headers\",\"status\":\"$status\",\"detail\":\"$detail\"}"
}

check_input_validation() {
  local status="fail"
  local detail="No input validation patterns found"
  local found=()

  for dir in "$PROJECT_DIR/src" "$PROJECT_DIR/lib" "$PROJECT_DIR/app" "$PROJECT_DIR/pkg"; do
    if [ -d "$dir" ]; then
      if find "$dir" -type f \( -name "*.ts" -o -name "*.js" \) -exec grep -lE '(zod|joi|yup|class-validator|ajv|schema\.parse|schema\.safeParse|validate\(|validationResult)' {} \; 2>/dev/null | head -3 | grep -q .; then
        found+=("schema-validation")
        break
      fi
    fi
  done

  for dir in "$PROJECT_DIR/src" "$PROJECT_DIR/lib" "$PROJECT_DIR/app"; do
    if [ -d "$dir" ]; then
      if find "$dir" -type f \( -name "*.py" \) -exec grep -lE '(pydantic|marshmallow|cerberus|validators\.|@validate|InputValidation)' {} \; 2>/dev/null | head -3 | grep -q .; then
        found+=("python-validation")
        break
      fi
    fi
  done

  for dir in "$PROJECT_DIR/src" "$PROJECT_DIR/lib" "$PROJECT_DIR/app" "$PROJECT_DIR/pkg"; do
    if [ -d "$dir" ]; then
      if find "$dir" -type f \( -name "*.ts" -o -name "*.js" -o -name "*.py" -o -name "*.go" \) -exec grep -lE '(sanitize|escape|encodeURI|encodeURIComponent|DOMPurify|xss|parametrize|parameterized)' {} \; 2>/dev/null | head -3 | grep -q .; then
        found+=("sanitization")
        break
      fi
    fi
  done

  if [ ${#found[@]} -gt 0 ]; then
    status="pass"
    detail="Input validation found: ${found[*]}"
  fi

  echo "{\"name\":\"input_validation\",\"status\":\"$status\",\"detail\":\"$detail\"}"
}

echo "Checking security and hardening..." >&2

C1=$(check_dependency_audit)
C2=$(check_secrets_detection)
C3=$(check_auth_patterns)
C4=$(check_security_headers)
C5=$(check_input_validation)

CHECKS="[$C1,$C2,$C3,$C4,$C5]"

OVERALL=$(echo "$CHECKS" | python3 -c "import sys,json; checks=json.load(sys.stdin); fail=len([c for c in checks if c['status']=='fail']); print('pass' if fail==0 else ('partial' if fail<len(checks) else 'fail'))" 2>/dev/null || echo "partial")

echo "{\"skill\":\"security-and-hardening\",\"status\":\"$OVERALL\",\"checks\":$CHECKS}"