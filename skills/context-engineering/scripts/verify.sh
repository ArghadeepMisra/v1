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

echo "Checking context engineering setup in: $PROJECT_DIR" >&2

# Check 1: Rules files exist
check_rules_files() {
  local detail=""
  local found=0
  local total=0

  # Check for common rules files
  local rules_files=(
    "AGENTS.md"
    "CLAUDE.md"
    ".cursorrules"
    ".windsurfrules"
    ".github/copilot-instructions.md"
  )

  for f in "${rules_files[@]}"; do
    total=$((total + 1))
    if [[ -f "$PROJECT_DIR/$f" ]]; then
      found=$((found + 1))
      detail+="Found $f. "
    fi
  done

  # Check .cursor/rules/ directory
  total=$((total + 1))
  if [[ -d "$PROJECT_DIR/.cursor/rules" ]]; then
    local cursor_count
    cursor_count=$(find "$PROJECT_DIR/.cursor/rules" -name "*.md" -type f 2>/dev/null | wc -l)
    if [[ "$cursor_count" -gt 0 ]]; then
      found=$((found + 1))
      detail+=".cursor/rules/ with ${cursor_count} rule files. "
    fi
  fi

  # Check .opencode directory
  total=$((total + 1))
  if [[ -d "$PROJECT_DIR/.opencode" ]]; then
    found=$((found + 1))
    detail+=".opencode/ directory exists. "
  fi

  if [[ $found -eq 0 ]]; then
    detail="No rules files found (checked: AGENTS.md, CLAUDE.md, .cursorrules, .windsurfrules, .cursor/rules/, .opencode/)"
    status="fail"
  elif [[ $found -lt 2 ]]; then
    detail+="Only ${found} context file(s) found"
    status="partial"
  else
    detail+="${found} context files found"
    status="pass"
  fi

  echo '{"name":"rules_files","status":"'"$status"'","detail":"'"$detail"'"}'
}

# Check 2: Context packing setup
check_context_packing() {
  local detail=""
  local status="partial"
  local found=false

  # Check for project map / context summary files
  for mapfile in "PROJECT_MAP.md" "CONTEXT.md" "project-map.md" "context-map.md" ".context" "context.json"; do
    if [[ -f "$PROJECT_DIR/$mapfile" ]]; then
      found=true
      detail+="Context map found: $mapfile. "
    fi
  done

  # Check AGENTS.md for project context (commands, tech stack, conventions)
  if [[ -f "$PROJECT_DIR/AGENTS.md" ]]; then
    local has_commands=false
    local has_stack=false

    if grep -qi "command\|build\|test\|lint\|dev" "$PROJECT_DIR/AGENTS.md" 2>/dev/null; then
      has_commands=true
      detail+="AGENTS.md contains commands. "
    fi

    if grep -qi "tech\|stack\|React\|TypeScript\|Python\|Go\|Rust" "$PROJECT_DIR/AGENTS.md" 2>/dev/null; then
      has_stack=true
      detail+="AGENTS.md contains tech stack info. "
    fi

    if $has_commands && $has_stack; then
      found=true
      detail+="AGENTS.md has structured context (commands + tech stack). "
    fi
  fi

  # Check for .opencode/rules files
  if [[ -d "$PROJECT_DIR/.opencode" ]]; then
    local opencode_count
    opencode_count=$(find "$PROJECT_DIR/.opencode" -name "*.md" -type f 2>/dev/null | wc -l)
    if [[ "$opencode_count" -gt 0 ]]; then
      found=true
      detail+=".opencode/ has ${opencode_count} files. "
    fi
  fi

  # Check for README (basic context)
  for readme in "README.md" "README.rst" "README.txt"; do
    if [[ -f "$PROJECT_DIR/$readme" ]]; then
      detail+="README found ($readme). "
      if ! $found; then
        status="partial"
      fi
      break
    fi
  done

  if $found; then
    status="pass"
  elif [[ -n "$detail" ]]; then
    status="partial"
  else
    detail="No context packing files found"
    status="fail"
  fi

  echo '{"name":"context_packing","status":"'"$status"'","detail":"'"$detail"'"}'
}

# Check 3: MCP integrations configured
check_mcp_integrations() {
  local detail=""
  local status="partial"
  local found=0

  # Check for MCP config files
  for mcpfile in ".mcp.json" "mcp.json" ".cursor/mcp.json" ".opencode/mcp.json" ".vscode/mcp.json"; do
    if [[ -f "$PROJECT_DIR/$mcpfile" ]]; then
      found=$((found + 1))
      local server_count=0
      if command -v jq &> /dev/null; then
        server_count=$(jq '.mcpServers | length' "$PROJECT_DIR/$mcpfile" 2>/dev/null || echo "0")
      else
        server_count=$(grep -c '"[a-zA-Z]"' "$PROJECT_DIR/$mcpfile" 2>/dev/null || echo "?")
      fi
      detail+="$mcpfile found (${server_count} servers). "
    fi
  done

  # Check for common MCP-related packages or configs
  for pkgfile in "package.json" "pyproject.toml"; do
    if [[ -f "$PROJECT_DIR/$pkgfile" ]]; then
      if grep -q "mcp\|@modelcontextprotocol\|mcp-server" "$PROJECT_DIR/$pkgfile" 2>/dev/null; then
        found=$((found + 1))
        detail+="MCP dependency found in $pkgfile. "
      fi
    fi
  done

  # Check Claude Code config
  if [[ -f "$HOME/.claude/settings.json" ]]; then
    if grep -q "mcpServers" "$HOME/.claude/settings.json" 2>/dev/null; then
      found=$((found + 1))
      detail+="Claude Code MCP servers configured. "
    fi
  fi

  if [[ $found -eq 0 ]]; then
    detail="No MCP integration configurations found"
    status="partial"
  else
    detail="${found} MCP configuration(s) found"
    status="pass"
  fi

  echo '{"name":"mcp_integrations","status":"'"$status"'","detail":"'"$detail"'"}'
}

# Check 4: Beads / persistent memory
check_persistent_memory() {
  local detail=""
  local status="partial"

  # Check for beads setup
  if command -v bd &> /dev/null; then
    detail+="bd (beads) CLI available. "
    if [[ -d "$PROJECT_DIR/.beads" ]]; then
      detail+="Beads project initialized (.beads/ found). "
      status="pass"
    else
      detail+="Beads not initialized in this project"
      status="partial"
    fi
  else
    # Check for alternative persistent memory files
    local found_memory=false
    for memfile in ".beads" "memory.json" ".memory" "context-memory.md"; do
      if [[ -e "$PROJECT_DIR/$memfile" ]]; then
        found_memory=true
        detail+="Persistent memory file found: $memfile. "
      fi
    done

    if $found_memory; then
      status="partial"
    else
      detail="No persistent memory system (beads or equivalent) detected"
      status="partial"
    fi
  fi

  echo '{"name":"persistent_memory","status":"'"$status"'","detail":"'"$detail"'"}'
}

echo "Running context engineering checks..." >&2

c1=$(check_rules_files)
c2=$(check_context_packing)
c3=$(check_mcp_integrations)
c4=$(check_persistent_memory)

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

printf '{"skill":"context-engineering","status":"%s","checks":%s}\n' "$overall" "$checks_json"