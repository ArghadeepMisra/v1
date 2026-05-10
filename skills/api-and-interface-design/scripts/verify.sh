#!/bin/bash
set -e

PROJECT_DIR="."
SCHEMA_FILES=()
CHECKS=()
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

echo "Checking API and interface design in: $PROJECT_DIR" >&2

# Check 1: Typed schema files (OpenAPI/Swagger/GraphQL)
check_typed_schemas() {
  local found=false
  local detail=""

  # OpenAPI / Swagger
  if compgen -G "$PROJECT_DIR/{openapi,swagger}.{json,yaml,yml}" > /dev/null 2>&1; then
    found=true
    detail+="OpenAPI/Swagger spec found. "
  fi

  # GraphQL schema
  if compgen -G "$PROJECT_DIR/**/*.graphql" > /dev/null 2>&1; then
    found=true
    detail+="GraphQL schema found. "
  fi

  # Check common schema directories
  for dir in "schemas" "schema" "api" "specs" "spec" "docs"; do
    if [[ -d "$PROJECT_DIR/$dir" ]]; then
      for ext in json yaml yml graphql gql; do
        if compgen -G "$PROJECT_DIR/$dir/*.$ext" > /dev/null 2>&1; then
          found=true
          detail+="Schema files found in $dir/. "
          break 2
        fi
      done
    fi
  done

  # Check for Zod/Joi/Pydantic/etc. validation schemas in source
  if grep -rl "z\.object\|z\.string\|z\.number\|Joi\.object\|Joi\.string\|pydantic\|BaseModel\|Schema<" "$PROJECT_DIR/src" "$PROJECT_DIR/lib" "$PROJECT_DIR/app" > /dev/null 2>&1; then
    found=true
    detail+="Validation schema library in use. "
  fi

  if $found; then
    echo '{"name":"typed_schemas","status":"pass","detail":"'"$detail"'"}'
  else
    echo '{"name":"typed_schemas","status":"fail","detail":"No typed schema files (OpenAPI/Swagger/GraphQL) or validation schemas found"}'
  fi
}

# Check 2: Consistent error response format
check_error_format() {
  local found=false
  local detail=""

  # Look for centralized error handling patterns
  for pattern in "APIError\|AppError\|HttpError\|ErrorResponse\|errorResponse\|ErrorHandler\|errorHandler\|error.*middleware\|errorHandlerMiddleware"; do
    if grep -rl "$pattern" "$PROJECT_DIR/src" "$PROJECT_DIR/lib" "$PROJECT_DIR/app" > /dev/null 2>&1; then
      found=true
      detail+="Centralized error class/handler found matching: $pattern. "
      break
    fi
  done

  # Check for consistent error response shape in code
  if grep -rl '"code".*:.*"message"\|"error".*:.*{"code"\|"status".*:.*"error"\|ErrorResponse\|ApiException' "$PROJECT_DIR/src" "$PROJECT_DIR/lib" "$PROJECT_DIR/app" > /dev/null 2>&1; then
    found=true
    detail+="Consistent error response shape detected. "
  fi

  if $found; then
    echo '{"name":"consistent_error_format","status":"pass","detail":"'"$detail"'"}'
  else
    echo '{"name":"consistent_error_format","status":"fail","detail":"No centralized error response format detected"}'
  fi
}

# Check 3: Boundary validation patterns
check_boundary_validation() {
  local found=false
  local detail=""

  # Check for validation at API boundaries (route handlers, controllers)
  for dir in "src/routes" "src/api" "src/controllers" "lib/routes" "app/routes" "app/controllers" "src/handlers"; do
    if [[ -d "$PROJECT_DIR/$dir" ]]; then
      # Check for validation calls in route/controller files
      if grep -rl "validate\|safeParse\|parse\|schema\.validate\|check\|assert\|verify" "$PROJECT_DIR/$dir" > /dev/null 2>&1; then
        found=true
        detail+="Validation at boundary in $dir/. "
        break
      fi
    fi
  done

  # Check for middleware-based validation
  if grep -rl "validation.*middleware\|validate.*middleware\|schema.*middleware\|body.*parser" "$PROJECT_DIR/src" "$PROJECT_DIR/lib" "$PROJECT_DIR/app" > /dev/null 2>&1; then
    found=true
    detail+="Validation middleware detected. "
  fi

  if $found; then
    echo '{"name":"boundary_validation","status":"pass","detail":"'"$detail"'"}'
  else
    echo '{"name":"boundary_validation","status":"fail","detail":"No boundary validation patterns detected in routes/controllers"}'
  fi
}

# Check 4: Backward-compatible field additions (additive changes)
check_backward_compatibility() {
  local detail=""
  local status="partial"

  if [[ ! -d "$PROJECT_DIR/.git" ]]; then
    detail="Not a git repository; cannot check for breaking changes"
    status="partial"
  else
    # Check recent commits for API-related changes
    local breaking_count=0
    local additive_count=0

    # Check for field removals or type changes in recent commits
    if git -C "$PROJECT_DIR" log --oneline -20 2>/dev/null | grep -i "remove.*field\|delete.*field\|breaking\|rename.*field\|change.*type" > /dev/null 2>&1; then
      breaking_count=$((breaking_count + 1))
      detail+="Recent commits mention potentially breaking changes. "
    fi

    # Check for optional field additions (good pattern)
    if git -C "$PROJECT_DIR" log --oneline -20 2>/dev/null | grep -i "add.*optional\|add.*field\|new.*optional" > /dev/null 2>&1; then
      additive_count=$((additive_count + 1))
      detail+="Recent commits show additive (optional) field additions. "
    fi

    if [[ $breaking_count -eq 0 && $additive_count -gt 0 ]]; then
      status="pass"
      detail="No breaking changes detected; additive patterns found"
    elif [[ $breaking_count -eq 0 ]]; then
      status="partial"
      detail="No recent breaking changes detected, but no additive patterns confirmed either"
    else
      status="fail"
      detail="Recent commits mention potentially breaking API changes"
    fi
  fi

  echo '{"name":"backward_compat","status":"'"$status"'","detail":"'"$detail"'"}'
}

echo "Running API and interface design checks..." >&2

c1=$(check_typed_schemas)
c2=$(check_error_format)
c3=$(check_boundary_validation)
c4=$(check_backward_compatibility)

# Determine overall status
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

# Build JSON array of checks
checks_json="[$c1,$c2,$c3,$c4]"

printf '{"skill":"api-and-interface-design","status":"%s","checks":%s}\n' "$overall" "$checks_json"