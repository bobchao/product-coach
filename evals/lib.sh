#!/bin/bash
# Eval harness 共用函式：run.sh（主迴歸）與 skill-compat.sh（相容性測試）共用，
# 避免 run_turn 邏輯 drift。呼叫端需先設好 BASE / FIX / RUN / LOG。
# （沿用 run.sh 的慣例：不用 set -u，bash 3.2 會把空陣列展開當 unbound variable）

# 關掉 CLI 的自動檔案記憶（issue #21）：CLI 2.1.x 的 auto-memory 會注入一段指向
# ~/.claude/projects/<slug>/memory/ 的系統提示，跟 CLAUDE.md→AGENTS.md→SOUL.md 的
# boot sequence 競爭，導致 coach 沒 boot、記憶被寫到 harness 目錄。這是被測產品自己的
# 記憶系統（專案 memory/，由 AGENTS.md 驅動）之外的一層，評測一律關掉才 hermetic。
# 此 env var 官方定義為最高優先、覆蓋所有設定，正是給自動化環境用的。可用外部環境覆寫。
export CLAUDE_CODE_DISABLE_AUTO_MEMORY="${CLAUDE_CODE_DISABLE_AUTO_MEMORY:-1}"

# 隔離使用者層設定目錄（issue #21 第二肇因）：~/.claude/skills/ 的 user-global skill
# 會在 turn1 搶走回合（實測 colleague-bobcat），boot sequence 因此沒跑。這類 skill 掛在
# 使用者層，與 cwd 無關，setup_dir 排除專案 .claude/skills 擋不到。CLAUDE_CONFIG_DIR 會
# 把所有 ~/.claude 路徑改指到指定目錄，用一個空的 scratch 目錄即可讓評測 hermetic：
# 不吃本機掛了什麼 skill／個人設定。T8a 不受影響——它的 skill 是 fixture overlay 疊進
# 測試副本的專案層 .claude/skills/，不走使用者層。
# 做法是「鏡射」而非空目錄：把真實 config dir 的每個項目 symlink 進 scratch home，
# 唯獨 skills/ 換成空目錄。空目錄版試過會連登入態一起隔離掉（憑證在 macOS Keychain，
# 沒有 .credentials.json 可複製，整輪空跑 "Not logged in"），鏡射則保留憑證與設定。
# 這樣擋掉的是所有 user-global skills，不是只針對某一個。
if [ -z "$CLAUDE_CONFIG_DIR" ]; then
  real_cfg=""
  for c in "$HOME/.claude" "$HOME/.config/claude"; do [ -d "$c" ] && { real_cfg="$c"; break; }; done
  if [ -n "$real_cfg" ]; then
    EVAL_HOME="$RUN/.claude-home"
    mkdir -p "$EVAL_HOME"
    for entry in "$real_cfg"/* "$real_cfg"/.[!.]*; do
      [ -e "$entry" ] || continue
      name="$(basename "$entry")"
      [ "$name" = "skills" ] && continue
      [ -e "$EVAL_HOME/$name" ] || ln -s "$entry" "$EVAL_HOME/$name"
    done
    mkdir -p "$EVAL_HOME/skills"
    export CLAUDE_CONFIG_DIR="$EVAL_HOME"
  fi
fi

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
  jq -r 'select(.type=="assistant") | .message.content[]? | select(.type=="tool_use") | "turn'"$n"': " + .name + " :: " + ((.input.skill // .input.query // .input.file_path // .input.url // .input.command // "") | tostring | .[0:250])' "$raw" >> "$d/tools.log" 2>/dev/null
  log "$1 turn$n done"
}
