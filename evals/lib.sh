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

# --- 模擬使用者（SIM=1 時改用；設計見 TEST-PLAN「模擬模式」）---
# 模擬者用 Haiku 演使用者：無狀態（每次餵 persona 卡＋transcript 全文），
# 在測試副本外的空目錄執行（避免載入 CLAUDE.md/SOUL.md 變成第二個 coach）。

sim_turn() { # $1=testname $2=sim_no $3=persona-file → stdout: 下一句台詞（失敗時為空）
  local d="$RUN/$1" n=$2 persona=$3
  local raw="$d/sim$n.jsonl"
  mkdir -p "$d/.sim"
  local prompt
  prompt="$(cat "$persona")

---
以下是目前為止的對話逐字稿（### USER 是你，### COACH 是教練）：

$(cat "$d/transcript.md")

---
現在輪到你（使用者）發言。只輸出你的下一句話本身，不要任何說明、引號或角色前綴。若走位已完成，在句尾附上 <<END>>。"
  ( cd "$d/.sim" && claude -p "$prompt" \
      --model haiku \
      --output-format json \
      --allowedTools "" \
      --max-turns 2 ) > "$raw" 2>> "$d/err.log"
  jq -r 'select(.type=="result") | .result // empty' "$raw"
}

run_sim_dialogue() { # $1=testname $2=persona-file $3=開場白（與 scripted 模式同句，維持可比性）
  # 輪數上限吃 SIM_MAX_TURNS（預設 8，t4/t5 的歷史基準用這個值；
  # 較長的流程如 skill-standalone 的成長盤點可調高）
  local t=$1 persona=$2 opening=$3 max="${SIM_MAX_TURNS:-8}"
  local d="$RUN/$t"
  run_turn "$t" 1 "$opening"
  local n=2 line ended=""
  while [ "$n" -le "$max" ]; do
    line=$(sim_turn "$t" $((n-1)) "$persona")
    if [ -z "$line" ]; then
      echo "sim turn $((n-1)) 沒有產出台詞" >> "$d/INVALID"
      log "$t INVALID: sim turn$((n-1)) empty"
      return
    fi
    case "$line" in *"<<END>>"*) ended=1 ;; esac
    line="${line//<<END>>/}"
    line="$(printf '%s' "$line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
    run_turn "$t" "$n" "$line"
    [ -n "$ended" ] && return
    n=$((n+1))
  done
  echo "達到 $max 輪上限仍未收尾" >> "$d/INVALID"
  log "$t INVALID: max turns ($max) reached"
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
