#!/bin/bash
set -e

PROJECT_DIR="."
TMPDIR_PREFIX="/tmp/perf-verify-"

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

check_bundle_size_config() {
  local status="fail"
  local detail="No bundle size configuration found"
  local found=()

  for f in bundlesize.config.json .bundlesizerc bundlesize.config.js; do
    if [ -f "$PROJECT_DIR/$f" ]; then
      found+=("$f")
    fi
  done

  if [ -f "$PROJECT_DIR/package.json" ]; then
    if grep -qE '"bundlesize"' "$PROJECT_DIR/package.json" 2>/dev/null; then
      found+=("bundlesize in package.json")
    fi
    if grep -qE '"size-limit"|size-limit"' "$PROJECT_DIR/package.json" 2>/dev/null; then
      found+=("size-limit in package.json")
    fi
  fi

  for f in .lighthouserc.js .lighthouserc.json .lighthouserc.yml lighthouse.config.js; do
    if [ -f "$PROJECT_DIR/$f" ]; then
      found+=("lighthouse config")
      break
    fi
  done

  if [ -f "$PROJECT_DIR/next.config.js" ] || [ -f "$PROJECT_DIR/next.config.ts" ] || [ -f "$PROJECT_DIR/next.config.mjs" ]; then
    found+=("next.config (bundleanalyzer)")
  fi

  if [ -f "$PROJECT_DIR/vite.config.ts" ] || [ -f "$PROJECT_DIR/vite.config.js" ]; then
    if grep -qE 'rollupOptions|manualChunks|build.*chunkSizeWarningLimit' "$PROJECT_DIR/vite.config"* 2>/dev/null; then
      found+=("vite bundle config")
    fi
  fi

  if [ ${#found[@]} -gt 0 ]; then
    status="pass"
    detail="Bundle size config found: ${found[*]}"
  fi

  echo "{\"name\":\"bundle_size_config\",\"status\":\"$status\",\"detail\":\"$detail\"}"
}

check_performance_budgets() {
  local status="fail"
  local detail="No performance budgets configured"
  local found=()

  if [ -f "$PROJECT_DIR/package.json" ]; then
    if grep -qE '(budget|performance-budget|lighthouse|lhci)' "$PROJECT_DIR/package.json" 2>/dev/null; then
      found+=("performance-budget-in-package.json")
    fi
  fi

  for f in budget.json .lighthouserc.js .lighthouserc.json lighthouse.config.js budgets.json performance-budget.json; do
    if [ -f "$PROJECT_DIR/$f" ]; then
      found+=("$f")
    fi
  done

  if [ -f "$PROJECT_DIR/.github/workflows" ]; then
    if find "$PROJECT_DIR/.github/workflows" -name "*.yml" -o -name "*.yaml" 2>/dev/null | xargs grep -l 'lighthouse\|lhci' 2>/dev/null | head -1 | grep -q .; then
      found+=("CI lighthouse config")
    fi
  fi

  if [ ${#found[@]} -gt 0 ]; then
    status="pass"
    detail="Performance budget found: ${found[*]}"
  fi

  echo "{\"name\":\"performance_budgets\",\"status\":\"$status\",\"detail\":\"$detail\"}"
}

check_lazy_loading() {
  local status="fail"
  local detail="No lazy loading patterns found"
  local found=()

  for dir in "$PROJECT_DIR/src" "$PROJECT_DIR/lib" "$PROJECT_DIR/app"; do
    if [ -d "$dir" ]; then
      if find "$dir" -type f \( -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" \) -exec grep -lE '(React\.lazy|lazy\(\s*\(\)|import\s*\(\s*\)|Suspense|Loadable|next/dynamic)' {} \; 2>/dev/null | head -3 | grep -q .; then
        found+=("code-splitting")
        break
      fi
    fi
  done

  for dir in "$PROJECT_DIR/src" "$PROJECT_DIR/lib" "$PROJECT_DIR/app" "$PROJECT_DIR"; do
    if [ -d "$dir" ]; then
      if find "$dir" -type f \( -name "*.tsx" -o -name "*.jsx" -o -name "*.html" \) -exec grep -lE 'loading\s*=\s*["\x27]lazy["\x27]' {} \; 2>/dev/null | head -3 | grep -q .; then
        found+=("image-lazy-loading")
        break
      fi
    fi
  done

  for dir in "$PROJECT_DIR/src" "$PROJECT_DIR/lib" "$PROJECT_DIR/app"; do
    if [ -d "$dir" ]; then
      if find "$dir" -type f \( -name "*.tsx" -o -name "*.jsx" -o -name "*.html" \) -exec grep -lE 'decoding\s*=\s*["\x27]async["\x27]' {} \; 2>/dev/null | head -3 | grep -q .; then
        found+=("async-decoding")
        break
      fi
    fi
  done

  if [ ${#found[@]} -gt 0 ]; then
    status="pass"
    detail="Lazy loading patterns found: ${found[*]}"
  fi

  echo "{\"name\":\"lazy_loading\",\"status\":\"$status\",\"detail\":\"$detail\"}"
}

check_image_optimization() {
  local status="fail"
  local detail="No image optimization detected"
  local found=()

  if [ -f "$PROJECT_DIR/next.config.js" ] || [ -f "$PROJECT_DIR/next.config.ts" ] || [ -f "$PROJECT_DIR/next.config.mjs" ]; then
    found+=("Next.js Image component available")
  fi

  for dir in "$PROJECT_DIR/src" "$PROJECT_DIR/lib" "$PROJECT_DIR/app" "$PROJECT_DIR/components"; do
    if [ -d "$dir" ]; then
      if find "$dir" -type f \( -name "*.tsx" -o -name "*.jsx" \) -exec grep -lE '(<Image\s|<Img\s|next/image|gatsby-image|nuxt-img|nuxt-picture)' {} \; 2>/dev/null | head -3 | grep -q .; then
        found+=("optimized-image-component")
        break
      fi
    fi
  done

  if [ -d "$PROJECT_DIR/public" ]; then
    local avif_count webp_count
    avif_count=$(find "$PROJECT_DIR/public" -name "*.avif" 2>/dev/null | wc -l)
    webp_count=$(find "$PROJECT_DIR/public" -name "*.webp" 2>/dev/null | wc -l)
    if [ "$avif_count" -gt 0 ] || [ "$webp_count" -gt 0 ]; then
      found+=("modern-image-formats: ${webp_count} webp, ${avif_count} avif")
    fi
  fi

  for dir in "$PROJECT_DIR/src" "$PROJECT_DIR/lib" "$PROJECT_DIR/app"; do
    if [ -d "$dir" ]; then
      if find "$dir" -type f \( -name "*.tsx" -o -name "*.jsx" -o -name "*.html" \) -exec grep -lE '(width=\d+\s+height=\d+|width=.*height=.*<img)' {} \; 2>/dev/null | head -3 | grep -q .; then
        found+=("image-dimensions-set")
        break
      fi
    fi
  done

  for f in sharp.config.js sharp.config.ts imagemin.config.js; do
    if [ -f "$PROJECT_DIR/$f" ]; then
      found+=("image-processing-config")
    fi
  done

  if [ -f "$PROJECT_DIR/package.json" ]; then
    if grep -qE '"(sharp|imagemin|slick|@nuxt/image|next/image)"' "$PROJECT_DIR/package.json" 2>/dev/null; then
      found+=("image-optimization-dep")
    fi
  fi

  if [ ${#found[@]} -gt 0 ]; then
    status="pass"
    detail="Image optimization found: ${found[*]}"
  fi

  echo "{\"name\":\"image_optimization\",\"status\":\"$status\",\"detail\":\"$detail\"}"
}

check_n_plus_one_queries() {
  local status="pass"
  local detail="No obvious N+1 query patterns detected"
  local found=()

  for dir in "$PROJECT_DIR/src" "$PROJECT_DIR/lib" "$PROJECT_DIR/app" "$PROJECT_DIR/pkg"; do
    if [ -d "$dir" ]; then
      while IFS= read -r f; do
        if grep -qE '(for\s*\(.*await|for\s*\(.*\.(find|get|fetch|query|select)\()' "$f" 2>/dev/null; then
          found+=("$(echo "$f" | sed "s|$PROJECT_DIR/||")")
        fi
      done < <(find "$dir" -type f \( -name "*.ts" -o -name "*.js" -o -name "*.py" -o -name "*.go" \) 2>/dev/null | head -200)
    fi
  done

  if [ ${#found[@]} -gt 0 ]; then
    if [ ${#found[@]} -le 3 ]; then
      status="partial"
    else
      status="fail"
    fi
    detail="Potential N+1 patterns in ${#found[@]} file(s)"
  fi

  echo "{\"name\":\"n_plus_one_queries\",\"status\":\"$status\",\"detail\":\"$detail\"}"
}

echo "Checking performance optimization status..." >&2

C1=$(check_bundle_size_config)
C2=$(check_performance_budgets)
C3=$(check_lazy_loading)
C4=$(check_image_optimization)
C5=$(check_n_plus_one_queries)

CHECKS="[$C1,$C2,$C3,$C4,$C5]"

OVERALL=$(echo "$CHECKS" | python3 -c "import sys,json; checks=json.load(sys.stdin); fail=len([c for c in checks if c['status']=='fail']); print('pass' if fail==0 else ('partial' if fail<len(checks) else 'fail'))" 2>/dev/null || echo "partial")

echo "{\"skill\":\"performance-optimization\",\"status\":\"$OVERALL\",\"checks\":$CHECKS}"