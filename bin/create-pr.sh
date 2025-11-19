#!/bin/bash

set -e

CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
REMOTE="origin"
REPO=$(git remote get-url origin | sed -E 's/.*github.com[:/](.*)\.git/\1/')

if [ -n "$1" ]; then
  BASE_BRANCH="$1"
else
  BASE_BRANCH=$(gh repo view "$REPO" --json defaultBranchRef -q '.defaultBranchRef.name' 2>/dev/null || echo "main")
fi

if [ "$CURRENT_BRANCH" = "$BASE_BRANCH" ]; then
  echo "Error: Cannot create PR from $BASE_BRANCH to itself"
  exit 1
fi

echo "Generating PR description for $CURRENT_BRANCH -> $BASE_BRANCH..." >&2

DIFF=$(git diff "$REMOTE/$BASE_BRANCH"..."$CURRENT_BRANCH" 2>/dev/null || git diff "$BASE_BRANCH"..."$CURRENT_BRANCH")

if [ -z "$DIFF" ]; then
  echo "Warning: No differences found between $CURRENT_BRANCH and $BASE_BRANCH"
  exit 1
fi

PROMPT="Generate PR title (first line) and description from git diff. Branch: $CURRENT_BRANCH. Title format: [ISSUE-ID] Title. Extract issue ID from branch. Blank line after title, then description with summary, bullets, and any dev-exp enhancements like test helpers, mocks, utilities, or tooling improvements."

TEMP_DIFF=$(mktemp)
echo "$DIFF" > "$TEMP_DIFF"

AGENT_STDERR=$(mktemp)
set +e
FULL_RESPONSE=$(cursor agent --print --output-format text -- "$PROMPT" < "$TEMP_DIFF" 2>"$AGENT_STDERR")
AGENT_EXIT_CODE=$?
set -e

if [ $AGENT_EXIT_CODE -eq 0 ] && [ -n "$FULL_RESPONSE" ]; then
  echo "" >&2
  echo "Generated PR description:" >&2
  echo "$FULL_RESPONSE" >&2
  echo "" >&2
elif [ $AGENT_EXIT_CODE -ne 0 ]; then
  echo "" >&2
  echo "Cursor agent failed, trying Codex CLI..." >&2
  echo "" >&2
  CODEX_STDERR=$(mktemp)
  CODEX_STDOUT=$(mktemp)
  set +e
  FULL_CONTENT="$PROMPT

Git diff:
\`\`\`
$(cat "$TEMP_DIFF")
\`\`\`"
  echo "$FULL_CONTENT" | codex exec 2>"$CODEX_STDERR" >"$CODEX_STDOUT"
  CODEX_EXIT_CODE=$?
  FULL_RESPONSE=$(cat "$CODEX_STDOUT" | grep -v "^OpenAI Codex" | grep -v "^--------" | grep -v "^workdir:" | grep -v "^model:" | grep -v "^provider:" | grep -v "^approval:" | grep -v "^sandbox:" | grep -v "^reasoning" | grep -v "^session id:" | sed '/^$/d' | head -100)
  set -e
  rm "$CODEX_STDOUT"
  
  if [ $CODEX_EXIT_CODE -eq 0 ] && [ -n "$FULL_RESPONSE" ]; then
    echo "Generated PR description:" >&2
    echo "$FULL_RESPONSE" >&2
    echo "" >&2
  else
    if [ -s "$CODEX_STDERR" ]; then
      CODEX_ERROR=$(grep -i "Error:" "$CODEX_STDERR" | head -1)
      if [ -n "$CODEX_ERROR" ]; then
        echo "Codex error: $CODEX_ERROR" >&2
        echo "" >&2
      fi
    fi
    FULL_RESPONSE=""
  fi
  
  rm "$CODEX_STDERR"
else
  FULL_RESPONSE=""
fi

rm "$AGENT_STDERR"

rm "$TEMP_DIFF"

if [ -z "$FULL_RESPONSE" ]; then
  echo "" >&2
  echo "Warning: Failed to generate PR description. Creating PR with empty description." >&2
  echo "" >&2
  ISSUE_ID=$(echo "$CURRENT_BRANCH" | grep -oE '[A-Z]+-[0-9]+' | head -1)
  BRANCH_TITLE=$(echo "$CURRENT_BRANCH" | sed -E 's/^[^/]+\///' | sed -E 's/^[a-z]+-[0-9]+-//' | sed 's/-/ /g' | awk '{for(i=1;i<=NF;i++)sub(/./,toupper(substr($i,1,1)),$i)}1')
  
  if [ -n "$ISSUE_ID" ]; then
    PR_TITLE="[$ISSUE_ID] $BRANCH_TITLE"
  else
    PR_TITLE="$BRANCH_TITLE"
  fi
  DESCRIPTION=""
else
  PR_TITLE=$(echo "$FULL_RESPONSE" | head -1 | sed 's/^#* *//' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  DESCRIPTION=$(echo "$FULL_RESPONSE" | sed -n '2,$p' | sed '/^[[:space:]]*$/d' | sed -n '/./,$p')
  
  if [ -z "$DESCRIPTION" ] || [ "$DESCRIPTION" = "$PR_TITLE" ]; then
    DESCRIPTION=""
  fi
fi

set +e
EXISTING_PR=$(gh pr list --head "$CURRENT_BRANCH" --json number,url,title -q '.[0].number // empty' 2>/dev/null)
set -e

if [ -n "$EXISTING_PR" ]; then
  EXISTING_PR_URL=$(gh pr list --head "$CURRENT_BRANCH" --json url -q '.[0].url // empty' 2>/dev/null)
  EXISTING_PR_TITLE=$(gh pr list --head "$CURRENT_BRANCH" --json title -q '.[0].title // empty' 2>/dev/null)
  echo "" >&2
  echo "PR already exists: $EXISTING_PR_URL" >&2
  echo "Current title: $EXISTING_PR_TITLE" >&2
  echo "New title: $PR_TITLE" >&2
  echo "" >&2
  echo -n "Update existing PR? (y/N): " >&2
  if [ -t 0 ]; then
    read -n 1 -r REPLY
  else
    read -n 1 -r REPLY </dev/tty 2>/dev/null || REPLY="n"
  fi
  echo "" >&2
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled." >&2
    exit 0
  fi
  
  PR_OUTPUT=$(gh pr edit "$EXISTING_PR" --title "$PR_TITLE" --body "$DESCRIPTION" 2>&1)
  if [ $? -ne 0 ]; then
    echo "Error updating PR: $PR_OUTPUT"
    exit 1
  fi
  
  echo "" >&2
  echo "PR updated: $EXISTING_PR_URL"
  if command -v open >/dev/null 2>&1; then
    open "$EXISTING_PR_URL"
  elif command -v xdg-open >/dev/null 2>&1; then
    xdg-open "$EXISTING_PR_URL"
  fi
else
  echo "" >&2
  echo "Title: $PR_TITLE" >&2
  echo "Description preview:" >&2
  echo "$DESCRIPTION" | head -10 >&2
  echo "" >&2
  echo -n "Create PR? (y/N): " >&2
  if [ -t 0 ]; then
    read -n 1 -r REPLY
  else
    read -n 1 -r REPLY </dev/tty 2>/dev/null || REPLY="n"
  fi
  echo "" >&2
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled." >&2
    exit 0
  fi
  
  PR_OUTPUT=$(gh pr create --base "$BASE_BRANCH" --head "$CURRENT_BRANCH" --title "$PR_TITLE" --body "$DESCRIPTION" 2>&1)
  
  if [ $? -ne 0 ]; then
    echo "Error creating PR: $PR_OUTPUT"
    exit 1
  fi
  
  PR_URL=$(echo "$PR_OUTPUT" | grep -oE 'https://[^ ]+' | head -1)
  if [ -z "$PR_URL" ]; then
    PR_NUMBER=$(echo "$PR_OUTPUT" | grep -oE '[0-9]+' | head -1)
    if [ -n "$PR_NUMBER" ]; then
      PR_URL="https://github.com/$REPO/pull/$PR_NUMBER"
    fi
  fi
  
  if [ -n "$PR_URL" ]; then
    echo "PR created: $PR_URL"
    if command -v open >/dev/null 2>&1; then
      open "$PR_URL"
    elif command -v xdg-open >/dev/null 2>&1; then
      xdg-open "$PR_URL"
    fi
  else
    echo "PR created, but could not extract URL. Please check manually."
  fi
fi
