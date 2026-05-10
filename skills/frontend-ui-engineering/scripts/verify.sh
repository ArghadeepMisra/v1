#!/bin/bash
set -e

PROJECT_DIR="."
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

echo "Checking frontend UI engineering status in: $PROJECT_DIR" >&2

# Check 1: Component directory structure
check_component_structure() {
  local detail=""
  local status="partial"
  local component_dirs=0

  # Common component directories
  for cdir in "src/components" "src/components/ui" "src/ui" "components" "app/components" "lib/components" "src/lib/components" "packages/ui/src" "web/components"; do
    if [[ -d "$PROJECT_DIR/$cdir" ]]; then
      component_dirs=$((component_dirs + 1))
      local file_count
      file_count=$(find "$PROJECT_DIR/$cdir" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | wc -l)
      detail+="$cdir (${file_count} sub-components). "
    fi
  done

  # Check for colocated component files (component + test + styles in same dir)
  local colocated=0
  for tdir in "src/components" "components" "src/ui"; do
    if [[ -d "$PROJECT_DIR/$tdir" ]]; then
      while IFS= read -r -d '' compdir; do
        local has_component=false
        local has_test=false
        local has_style=false

        for ext in tsx jsx ts js; do
          if compgen -G "$compdir/*.$ext" > /dev/null 2>&1; then
            has_component=true
          fi
        done

        for testext in "test.tsx" "test.jsx" "spec.tsx" "spec.jsx" "test.ts" "test.js"; do
          if compgen -G "$compdir/*.$testext" > /dev/null 2>&1; then
            has_test=true
          fi
        done

        for styleext in "css" "module.css" "scss" "module.scss"; do
          if compgen -G "$compdir/*.$styleext" > /dev/null 2>&1; then
            has_style=true
          fi
        done

        if $has_component && ($has_test || $has_style); then
          colocated=$((colocated + 1))
        fi
      done < <(find "$PROJECT_DIR/$tdir" -maxdepth 1 -mindepth 1 -type d -print0 2>/dev/null | head -20)
    fi
  done

  if [[ $colocated -gt 0 ]]; then
    detail+="${colocated} components use colocated file structure. "
  fi

  # Check for component naming (PascalCase directories)
  local pascal_count=0
  for cdir in "src/components" "components" "src/ui"; do
    if [[ -d "$PROJECT_DIR/$cdir" ]]; then
      pascal_count=$(find "$PROJECT_DIR/$cdir" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | xargs -I{} basename {} | grep -cE '^[A-Z]' || true)
    fi
  done

  if [[ $pascal_count -gt 0 ]]; then
    detail+="${pascal_count} components use PascalCase naming. "
  fi

  if [[ $component_dirs -eq 0 ]]; then
    detail="No standard component directory structure found"
    status="fail"
  elif [[ $colocated -gt 0 ]]; then
    status="pass"
  else
    detail+="Consider organizing components with colocated files (component + test + styles)"
    status="partial"
  fi

  echo '{"name":"component_structure","status":"'"$status"'","detail":"'"$detail"'"}'
}

# Check 2: Accessibility config
check_accessibility() {
  local detail=""
  local status="partial"
  local found=false

  # Check package.json for a11y tools
  if [[ -f "$PROJECT_DIR/package.json" ]]; then
    for pkg in "eslint-plugin-jsx-a11y" "eslint-plugin-vue-a11y" "@axe-core/react" "@axe-core/vue" "@axe-core/playwright" "angular-a11y" "vitest-axe" "jest-axe" "testing-library/jest-dom" "@testing-library/jest-dom" "aria-query"; do
      if grep -q "$pkg" "$PROJECT_DIR/package.json" 2>/dev/null; then
        found=true
        detail+="$pkg found. "
      fi
    done
  fi

  # Check for accessibility config in eslint config
  for eslintconf in ".eslintrc.js" ".eslintrc.json" ".eslintrc.yml" ".eslintrc" "eslint.config.js" "eslint.config.mjs" "eslint.config.ts"; do
    if [[ -f "$PROJECT_DIR/$eslintconf" ]]; then
      if grep -q "a11y\|accessibility\|jsx-a11y\|vue-a11y" "$PROJECT_DIR/$eslintconf" 2>/dev/null; then
        found=true
        detail+="Accessibility rules in $eslintconf. "
      fi
    fi
  done

  # Check for Storybook with a11y addon
  if [[ -f "$PROJECT_DIR/package.json" ]] && grep -q "@storybook/addon-a11y" "$PROJECT_DIR/package.json" 2>/dev/null; then
    found=true
    detail+="Storybook a11y addon found. "
  fi

  for storyconf in ".storybook/main.js" ".storybook/main.ts" ".storybook/main.tsx"; do
    if [[ -f "$PROJECT_DIR/$storyconf" ]]; then
      if grep -q "a11y\|addon-a11y" "$PROJECT_DIR/$storyconf" 2>/dev/null; then
        found=true
        detail+="Storybook a11y addon configured. "
      fi
    fi
  done

  # Check Python projects for a11y
  for pyfile in "requirements.txt" "pyproject.toml" "Pipfile"; do
    if [[ -f "$PROJECT_DIR/$pyfile" ]]; then
      if grep -qi "axe-core\|a11y\|accessibility\|pa11y" "$PROJECT_DIR/$pyfile" 2>/dev/null; then
        found=true
        detail+="Accessibility tool found in $pyfile. "
      fi
    fi
  done

  # Check for pa11y config
  for pa11yconf in ".pa11yci.json" ".pa11yci" "pa11y.json"; do
    if [[ -f "$PROJECT_DIR/$pa11yconf" ]]; then
      found=true
      detail+="pa11y config found: $pa11yconf. "
    fi
  done

  if $found; then
    status="pass"
  else
    detail="No accessibility tools or configuration found (eslint-plugin-jsx-a11y, @axe-core, pa11y, etc.)"
    status="fail"
  fi

  echo '{"name":"accessibility_config","status":"'"$status"'","detail":"'"$detail"'"}'
}

# Check 3: Design system / usage
check_design_system() {
  local detail=""
  local status="partial"
  local found=false

  # Check for UI framework/library in package.json
  if [[ -f "$PROJECT_DIR/package.json" ]]; then
    for ui in "tailwindcss" "@chakra-ui" "@mui/material" "@radix-ui" "shadcn" "@headlessui" "antd" "ant-design" "@carbon/react" "@primer/react" "daisyui" "@tremor/react" "@radix-ui/themes" "@nextui-org/react"; do
      if grep -q "\"$ui\"" "$PROJECT_DIR/package.json" 2>/dev/null; then
        found=true
        detail+="$ui found in dependencies. "
      fi
    done
  fi

  # Check for Tailwind config
  for twconf in "tailwind.config.js" "tailwind.config.ts" "tailwind.config.mjs" "postcss.config.js" "postcss.config.mjs"; do
    if [[ -f "$PROJECT_DIR/$twconf" ]]; then
      found=true
      detail+="$twconf found. "
    fi
  done

  # Check for design tokens / theme files
  for themefile in "src/theme" "src/styles/theme" "src/design-tokens" "src/tokens" "theme" "tokens" "styles/tokens" "styles/theme"; do
    if [[ -d "$PROJECT_DIR/$themefile" ]] || [[ -f "$PROJECT_DIR/$themefile" ]]; then
      found=true
      detail+="Theme/design tokens found: $themefile. "
    fi
  done

  for tokentype in "design-tokens.json" "tokens.json" "theme.json" "theme.ts" "theme.tsx" "theme.js" "colors.ts" "colors.json" "spacing.ts"; do
    for searchdir in "src" "lib" "styles" "config"; do
      if compgen -G "$PROJECT_DIR/$searchdir/**/$tokentype" > /dev/null 2>&1; then
        found=true
        detail+="Design token file found: $tokentype. "
      fi
    done
  done

  # Check for CSS custom properties (design system indicators)
  for cssfile in "$PROJECT_DIR/src/index.css" "$PROJECT_DIR/src/styles/globals.css" "$PROJECT_DIR/src/app/globals.css" "$PROJECT_DIR/app/globals.css" "$PROJECT_DIR/styles/global.css"; do
    if [[ -f "$cssfile" ]]; then
      local var_count
      var_count=$(grep -c "^--[a-z]" "$cssfile" 2>/dev/null || echo "0")
      if [[ "$var_count" -gt 5 ]]; then
        found=true
        detail+="${var_count} CSS custom properties in $(basename "$cssfile"). "
      fi
    fi
  done

  # Check for shadcn/ui components directory
  if [[ -d "$PROJECT_DIR/src/components/ui" ]] || [[ -d "$PROJECT_DIR/components/ui" ]]; then
    found=true
    local shadcn_dir
    if [[ -d "$PROJECT_DIR/src/components/ui" ]]; then
      shadcn_dir="$PROJECT_DIR/src/components/ui"
    else
      shadcn_dir="$PROJECT_DIR/components/ui"
    fi
    local ui_count
    ui_count=$(find "$shadcn_dir" -maxdepth 1 -type f -name "*.tsx" -o -name "*.ts" 2>/dev/null | wc -l)
    detail+="UI component library (${ui_count} components). "
  fi

  if $found; then
    status="pass"
  else
    detail="No design system or UI library detected"
    status="fail"
  fi

  echo '{"name":"design_system","status":"'"$status"'","detail":"'"$detail"'"}'
}

# Check 4: Responsive / layout patterns
check_responsive() {
  local detail=""
  local status="partial"
  local found=false

  # Check for responsive CSS patterns
  for src_dir in "src" "app" "lib" "components" "pages"; do
    if [[ -d "$PROJECT_DIR/$src_dir" ]]; then
      # Tailwind responsive classes
      local tw_responsive
      tw_responsive=$(grep -rlE "sm:|md:|lg:|xl:|2xl:" "$PROJECT_DIR/$src_dir" 2>/dev/null | grep -v node_modules | grep -v ".git" | head -5 | wc -l)
      if [[ "$tw_responsive" -gt 0 ]]; then
        found=true
        detail+="Responsive Tailwind classes found in ${tw_responsive} files. "
        break
      fi

      # CSS media queries
      local media_count
      media_count=$(grep -rl "@media" "$PROJECT_DIR/$src_dir" 2>/dev/null | grep -v node_modules | grep -v ".git" | head -5 | wc -l)
      if [[ "$media_count" -gt 0 ]]; then
        found=true
        detail+="CSS media queries found in ${media_count} files. "
        break
      fi
    fi
  done

  # Check for viewport meta tag
  for htmlfile in "index.html" "public/index.html" "src/index.html" "app/index.html"; do
    if [[ -f "$PROJECT_DIR/$htmlfile" ]] && grep -q "viewport" "$PROJECT_DIR/$htmlfile" 2>/dev/null; then
      found=true
      detail+="Viewport meta tag found in $htmlfile. "
    fi
  done

  # Check for responsive testing config
  for rtconf in "playwright.config.*" "cypress.config.*"; do
    if compgen -G "$PROJECT_DIR/$rtconf" > /dev/null 2>&1; then
      local configfile
      configfile=$(compgen -G "$PROJECT_DIR/$rtconf" | head -1)
      if grep -qi "viewport\|mobile\|responsive\|devices" "$configfile" 2>/dev/null; then
        found=true
        detail+="Responsive testing config in $(basename "$configfile"). "
      fi
    fi
  done

  if $found; then
    status="pass"
  else
    detail="No responsive design patterns detected (media queries, responsive classes, or viewport config)"
    status="partial"
  fi

  echo '{"name":"responsive_patterns","status":"'"$status"'","detail":"'"$detail"'"}'
}

echo "Running frontend UI engineering checks..." >&2

c1=$(check_component_structure)
c2=$(check_accessibility)
c3=$(check_design_system)
c4=$(check_responsive)

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

checks_json="[$c1,$c2,$c3,$c4]"

printf '{"skill":"frontend-ui-engineering","status":"%s","checks":%s}\n' "$overall" "$checks_json"