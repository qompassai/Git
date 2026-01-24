#!/usr/bin/env bash
# ghissue-graphql-debug.sh
# Qompass AI - [ ]
# ----------------------------------------
set -euo pipefail
log()
{
  printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*" >&2
}
log "Detecting current GitHub repository..."
REPO_FULL="$(gh repo view --json nameWithOwner -q '.nameWithOwner' 2> /dev/null || true)"
if [ -z "${REPO_FULL:-}" ]; then
  log "ERROR: Could not detect GitHub repository."
  log "Run this script inside a git repo that has a GitHub remote."
  exit 1
fi
OWNER="${REPO_FULL%%/*}"
REPO="${REPO_FULL##*/}"
log "Using repository: $REPO_FULL (owner='$OWNER', repo='$REPO')"
DATE="$(date +%Y-%m-%d)"
OUTFILE="${REPO}-open-issues-${DATE}.md"
TMP_RAW="$(mktemp)"
TMP_ISSUES="$(mktemp)"
cleanup()
{
  rm -f "$TMP_RAW" "$TMP_ISSUES"
}
trap cleanup EXIT

log "Step 1: Fetching open issues via GraphQL..."

gh api graphql --paginate -f query='
query($owner:String!, $repo:String!, $cursor:String) {
  repository(owner:$owner, name:$repo) {
    issues(
      first: 50,
      after: $cursor,
      states: OPEN,
      orderBy: { field: CREATED_AT, direction: DESC }
    ) {
      pageInfo {
        hasNextPage
        endCursor
      }
      nodes {
        number
        title
        url
        createdAt
        body
        labels(first: 20) {
          nodes { name }
        }
        comments(first: 50) {
          totalCount
          nodes {
            author { login }
            createdAt
            body
          }
        }
      }
    }
  }
}
' -F owner="$OWNER" -F repo="$REPO" \
  --jq '.data.repository.issues.nodes[]' > "$TMP_RAW" || {
  log "ERROR: gh api graphql failed."
  log "Try running the gh api command manually to see the exact error."
  exit 1
}

log "GraphQL fetch completed."
log "Raw JSON size: $(wc -c < "$TMP_RAW") bytes"

if ! [ -s "$TMP_RAW" ]; then
  log "No open issues found for $REPO_FULL"
  exit 0
fi
log "Step 2: Normalizing JSON with jq..."
jq '
  . as $i
  | {
      number:         $i.number,
      title:          $i.title,
      url:            $i.url,
      createdAt:      $i.createdAt,
      body:           $i.body,
      labels:         ($i.labels.nodes | map(.name)),
      comments:       $i.comments.nodes,
      comments_count: $i.comments.totalCount
    }
' "$TMP_RAW" > "$TMP_ISSUES" || {
  log "ERROR: jq normalization failed."
  exit 1
}
log "Normalization done. Issue count: $(jq 'length' "$TMP_ISSUES")"
log "Step 3: Generating markdown -> $OUTFILE"
{
  printf "# Open issues for %s\n\n" "$REPO_FULL"
  printf "| # | Title | Opened | Comments | Labels | Link |\n"
  printf "|---|-------|--------|----------|--------|------|\n"
  jq -r '
    .[]
    | "| #\(.number) | \(.title) | \(.createdAt) | \(.comments_count) | \((.labels // [] | join(", "))) | [link](\(.url)) |"
  ' "$TMP_ISSUES"
  printf "\n\n## Full issue details\n\n"
  idx=0

  jq -c '.[]' "$TMP_ISSUES" | while read -r issue; do
    idx=$((idx + 1))
    if ((idx % 10 == 1)); then
      log "Processing issue $idx..."
    fi

    number=$(printf '%s\n' "$issue" | jq -r '.number')
    title=$(printf '%s\n' "$issue" | jq -r '.title')
    createdAt=$(printf '%s\n' "$issue" | jq -r '.createdAt')
    url=$(printf '%s\n' "$issue" | jq -r '.url')
    labels=$(printf '%s\n' "$issue" | jq -r '.labels | join(", ")')
    comments_count=$(printf '%s\n' "$issue" | jq -r '.comments_count')
    body=$(printf '%s\n' "$issue" | jq -r '
      .body
      | (if . == null or . == "" then "(no description)" else . end)
      | split("\n") | .[0:5] | join("\n")
    ')
    printf "### Issue #%s: %s\n\n" "$number" "$title"
    printf "- Opened: %s\n" "$createdAt"
    printf "- Comments: %s\n" "$comments_count"
    printf "- Labels: %s\n" "${labels:-""}"
    printf "- Link: %s\n\n" "$url"
    printf "%s\n\n" "$body"
    if [ "$comments_count" -gt 0 ]; then
      printf "#### Comments\n\n"
      printf '%s\n' "$issue" | jq -r '
        .comments[]
        | "##### Comment by \(.author.login) at \(.createdAt)\n\n\(.body)\n"
      '
      printf "\n"
    fi

    printf "\n"
  done
} > "$OUTFILE" || {
  log "ERROR: Failed writing markdown to $OUTFILE"
  exit 1
}
log "Done."
echo "Wrote $OUTFILE"
