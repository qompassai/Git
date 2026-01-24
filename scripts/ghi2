#!/usr/bin/env bash
# /qompassai/git/scripts/ghissue.sh
# Qompass AI Github Issue Script
# Copyright (C) 2026 Qompass AI, All rights reserved
# ----------------------------------------
REPO="$(gh repo view --json nameWithOwner -q '.nameWithOwner')"
DATE="$(date +%Y-%m-%d)"
OUTFILE="$(basename "$REPO")-open-issues-${DATE}.md"
gh issue list \
  --repo "$REPO" \
  --state open \
  --limit 200 \
  --json number,title,state,labels,url,createdAt,comments \
  --template "
# Open issues for $REPO

| # | Title | Opened | Comments | Labels | Link |
|---|-------|--------|----------|--------|------|
{{- range . }}
| #{{.number}} | {{.title}} | {{.createdAt}} | {{.comments}} | {{range \$i, \$l := .labels}}{{if \$i}}, {{end}}{{.name}}{{end}} | [link]({{.url}}) |
{{- end }}
" > "$OUTFILE"
