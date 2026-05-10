#!/bin/bash
set -e

SKILLS_DIR="skills"
MIRROR_DIR=".opencode/skills"

cleanup() {
  if [ -n "$TEMP_DIR" ] && [ -d "$TEMP_DIR" ]; then
    rm -rf "$TEMP_DIR"
  fi
}
trap cleanup EXIT

TEMP_DIR=$(mktemp -d)

usage() {
  cat <<EOF >&2
Usage: bash scripts/skill-sync.sh [--check | --sync]

  --check  Compare skills/ and .opencode/skills/ for drift.
           Outputs JSON report to stdout. Exits 0 if matched, 1 if drift found.

  --sync   Mirror skills/ into .opencode/skills/.
           Creates missing directories, copies changed files,
           removes stale files. Outputs JSON report to stdout.
EOF
  exit 1
}

if [ $# -ne 1 ]; then
  usage
fi

MODE="$1"

if [ "$MODE" != "--check" ] && [ "$MODE" != "--sync" ]; then
  usage
fi

if [ ! -d "$SKILLS_DIR" ]; then
  echo "Error: $SKILLS_DIR directory not found" >&2
  echo '{"status":"error","message":"skills/ directory not found"}'
  exit 1
fi

check_drift() {
  local mismatches=()
  local missing_in_mirror=()
  local stale_in_mirror=()
  local content_diffs=()

  while IFS= read -r -d '' skill_dir; do
    local skill_name
    skill_name=$(basename "$skill_dir")

    if [ ! -d "$MIRROR_DIR/$skill_name" ]; then
      missing_in_mirror+=("$skill_name")
      continue
    fi

    while IFS= read -r -d '' src_file; do
      local rel_path
      rel_path="${src_file#$SKILLS_DIR/}"
      local mirror_file="$MIRROR_DIR/$rel_path"

      if [ ! -f "$mirror_file" ]; then
        missing_in_mirror+=("$rel_path")
      elif ! diff -q "$src_file" "$mirror_file" > /dev/null 2>&1; then
        content_diffs+=("$rel_path")
      fi
    done < <(find "$skill_dir" -type f -print0)
  done < <(find "$SKILLS_DIR" -mindepth 1 -maxdepth 1 -type d -print0)

  while IFS= read -r -d '' mirror_dir; do
    local skill_name
    skill_name=$(basename "$mirror_dir")

    if [ ! -d "$SKILLS_DIR/$skill_name" ]; then
      stale_in_mirror+=("$skill_name")
      continue
    fi

    while IFS= read -r -d '' mirror_file; do
      local rel_path
      rel_path="${mirror_file#$MIRROR_DIR/}"
      local src_file="$SKILLS_DIR/$rel_path"

      if [ ! -f "$src_file" ]; then
        stale_in_mirror+=("$rel_path")
      fi
    done < <(find "$mirror_dir" -type f -print0)
  done < <(find "$MIRROR_DIR" -mindepth 1 -maxdepth 1 -type d -print0)

  local total_issues=$(( ${#missing_in_mirror[@]} + ${#stale_in_mirror[@]} + ${#content_diffs[@]} ))

  if [ "$total_issues" -eq 0 ]; then
    echo '{"status":"ok","message":"skills/ and .opencode/skills/ are in sync"}'
    return 0
  else
    local json_file="$TEMP_DIR/drift_report.json"
    {
      echo -n '{"status":"mismatch","total_issues":'$total_issues',"details":{'
      echo -n '"missing_in_source_mirror":['
      local first=true
      for item in "${missing_in_mirror[@]}"; do
        if [ "$first" = true ]; then echo -n "\"$item\""; first=false; else echo -n ",\"$item\""; fi
      done
      echo -n '],'
      echo -n '"stale_in_mirror":['
      first=true
      for item in "${stale_in_mirror[@]}"; do
        if [ "$first" = true ]; then echo -n "\"$item\""; first=false; else echo -n ",\"$item\""; fi
      done
      echo -n '],'
      echo -n '"content_diffs":['
      first=true
      for item in "${content_diffs[@]}"; do
        if [ "$first" = true ]; then echo -n "\"$item\""; first=false; else echo -n ",\"$item\""; fi
      done
      echo -n ']}}'
    } > "$json_file"
    cat "$json_file"
    return 1
  fi
}

sync_mirror() {
  local synced=()
  local removed=()
  local created=()

  mkdir -p "$MIRROR_DIR"

  while IFS= read -r -d '' skill_dir; do
    local skill_name
    skill_name=$(basename "$skill_dir")
    local target_dir="$MIRROR_DIR/$skill_name"

    if [ ! -d "$target_dir" ]; then
      mkdir -p "$target_dir"
      created+=("$skill_name/")
    fi

    while IFS= read -r -d '' src_file; do
      local rel_path
      rel_path="${src_file#$SKILLS_DIR/$skill_name/}"
      local target_file="$target_dir/$rel_path"
      local target_subdir
      target_subdir=$(dirname "$target_file")

      if [ ! -d "$target_subdir" ]; then
        mkdir -p "$target_subdir"
      fi

      if [ ! -f "$target_file" ] || ! diff -q "$src_file" "$target_file" > /dev/null 2>&1; then
        cp "$src_file" "$target_file"
        synced+=("$skill_name/$rel_path")
      fi
    done < <(find "$skill_dir" -type f -print0)
  done < <(find "$SKILLS_DIR" -mindepth 1 -maxdepth 1 -type d -print0)

  while IFS= read -r -d '' mirror_dir; do
    local skill_name
    skill_name=$(basename "$mirror_dir")

    if [ ! -d "$SKILLS_DIR/$skill_name" ]; then
      rm -rf "$mirror_dir"
      removed+=("$skill_name/")
      continue
    fi

    while IFS= read -r -d '' mirror_file; do
      local rel_path
      rel_path="${mirror_file#$MIRROR_DIR/$skill_name/}"
      local src_file="$SKILLS_DIR/$skill_name/$rel_path"

      if [ ! -f "$src_file" ]; then
        rm "$mirror_file"
        removed+=("$skill_name/$rel_path")
      fi
    done < <(find "$mirror_dir" -type f -print0)
  done < <(find "$MIRROR_DIR" -mindepth 1 -maxdepth 1 -type d -print0)

  local json_file="$TEMP_DIR/sync_report.json"
  {
    echo -n '{"status":"synced","synced":['
    local first=true
    for item in "${synced[@]}"; do
      if [ "$first" = true ]; then echo -n "\"$item\""; first=false; else echo -n ",\"$item\""; fi
    done
    echo -n '],"removed":['
    first=true
    for item in "${removed[@]}"; do
      if [ "$first" = true ]; then echo -n "\"$item\""; first=false; else echo -n ",\"$item\""; fi
    done
    echo -n '],"created":['
    first=true
    for item in "${created[@]}"; do
      if [ "$first" = true ]; then echo -n "\"$item\""; first=false; else echo -n ",\"$item\""; fi
    done
    echo -n ']}'
  } > "$json_file"
  cat "$json_file"
  return 0
}

if [ "$MODE" = "--check" ]; then
  echo "Checking skills/ and .opencode/skills/ for drift..." >&2
  check_drift
elif [ "$MODE" = "--sync" ]; then
  echo "Syncing skills/ to .opencode/skills/..." >&2
  sync_mirror
  echo "Sync complete." >&2
fi