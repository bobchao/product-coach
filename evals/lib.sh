#!/bin/bash
# Eval harness 共用函式：run.sh（主迴歸）與 skill-compat.sh（相容性測試）共用，
# 避免 run_turn 邏輯 drift。呼叫端需先設好 BASE / FIX / RUN / LOG。
# （沿用 run.sh 的慣例：不用 set -u，bash 3.2 會把空陣列展開當 unbound variable）

log() { echo "[$(date '+%H:%M:%S')] $*" >> "$LOG"; }

setup_dir() { # $1=testname, $2...=fixture overlays (dir names under FIX)
  local d="$RUN/$1"; shift
  rm -rf "$d"; mkdir -p "$d"
  # 排除 .claude/skills：本機掛載的 skill 不得漏進測試副本（主迴歸要 hermetic，
  # 不隨本機掛了什麼而變）；需要 skill 的測試用 fixture overlay 明確疊進去。
  rsync -a --exclude .git --exclude evals --exclude .DS_Store \
    --exclude .claude/skills "$BASE/" "$d/"
  for f in "$@"; do rsync -a "$FIX/$f/" "$d/"; done
}

run_turn() { # $1=testdir $2=turn_no $3=message
  local d="$RUN/$1" n=$2 msg=$3
  local raw="$d/turn$n.jsonl" sfile="$d/.session"
  local extra=()
  [ -s "$sfile" ] && extra=(--resume "$(cat "$sfile")")
  ( cd "$d" && claude -p "$msg" \
      --model sonnet \
      --output-format stream-json --verbose \
      --permission-mode acceptEdits \
      --allowedTools "WebSearch,WebFetch" \
      --max-turns 30 \
      "${extra[@]}" ) > "$raw" 2>> "$d/err.log"
  jq -r 'select(.type=="result") | .session_id' "$raw" | tail -1 > "$sfile"
  {
    echo "### USER (turn $n)"
    echo "$msg"
    echo
    echo "### COACH (turn $n)"
    jq -r 'select(.type=="result") | .result' "$raw"
    echo
  } >> "$d/transcript.md"
  jq -r 'select(.type=="assistant") | .message.content[]? | select(.type=="tool_use") | "turn'"$n"': " + .name + " :: " + ((.input.skill // .input.query // .input.file_path // .input.command // "") | tostring | .[0:120])' "$raw" >> "$d/tools.log" 2>/dev/null
  log "$1 turn$n done"
}
