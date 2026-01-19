#!/usr/bin/env bash
# ghissue2.sh
# Qompass AI - [ ]
# Copyright (C) 2026 Qompass AI, All rights reserved
# ----------------------------------------
set -euo pipefail
REPO="$(gh repo view --json nameWithOwner -q '.nameWithOwner')"
DATE="$(date +%Y-%m-%d)"
OUTFILE="$(basename "$REPO")-open-issues-${DATE}.md"
gh issue list \
  --repo "$REPO" \
  --state open \
  --limit 500 \
  --json number,title,state,labels,url,createdAt,comments,body \
  --jq 'sort_by(.createdAt) | reverse' > /tmp/gh-issues.json

{
  printf "# Open issues for %s\n\n" "$REPO"
  printf "| # | Title | Opened | Comments | Labels | Link |\n"
  printf "|---|-------|--------|----------|--------|------|\n"
  jq -r '
    .[]
    | "| #\(.number) | \(.title) | \(.createdAt) | \((.comments // [] | length)) | \((.labels // [] | map(.name) | join(", "))) | [link](\(.url)) |"
  ' /tmp/gh-issues.json

  printf "\n\n## Full issue details\n\n"

  jq -r '
    .[]
    | "### Issue #\(.number): \(.title)\n\n" +
      "- Opened: \(.createdAt)\n" +
      "- Comments: \((.comments // [] | length))\n" +
      "- Labels: \((.labels // [] | map(.name) | join(", ")))\n" +
      "- Link: \(.url)\n\n" +
      "\((if .body == null or .body == "" then "(no description)" else .body end) | split("\n") | .[0:5] | join("\n"))\n\n"
  ' /tmp/gh-issues.json
} > "$OUTFILE"
