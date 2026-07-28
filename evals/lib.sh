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

# issue #21 第二肇因（user-global skills 在 turn1 搶走回合，boot sequence 因此沒跑）：
# 用 `--setting-sources project,local` 解——不載入使用者層設定，`~/.claude/skills/`
# 底下的 skill 因此不進 session（實測 slash_commands 少掉那批），fixture 疊進測試副本的
# 專案層 `.claude/skills/`（T8a 的 okr skills）不受影響。這條路**不動認證邊界**：
# 憑證與 CLAUDE_CONFIG_DIR 無關，登入態照舊。
#
# 不要再用 CLAUDE_CONFIG_DIR 去解這件事——已實測失敗三次：憑證不在檔案系統裡，
# macOS Keychain 的 service name 綁 config dir 路徑的 hash（`Claude Code-credentials-<hash>`），
# 所以無論用空目錄或鏡射，只要改 CLAUDE_CONFIG_DIR 登入態就一定掉（整輪空跑
# "Not logged in"、$0）。鏡射版還會產生 symlink 回寫穿透，把 CLI 對 scratch 的寫入導回
# 使用者真實的 ~/.claude/——比它想解的問題更危險。
# 呼叫端仍可自行預設 CLAUDE_CONFIG_DIR（harness 尊重外部值，但請自負登入態風險）。
# SETTING_SOURCES="" 可關掉這層隔離（跑舊行為對照用）。
SETTING_SOURCES="${SETTING_SOURCES-project,local}"

# issue #21 第三肇因（沒有污染源，模型單純不去讀 CLAUDE.md 指的 AGENTS.md，
# tools.log 全空、退化成素模型）：turn 1 用 `--append-system-prompt` 把 boot 指示
# 從專案檔案搬到系統提示。實測（sonnet，t3／t9b 開場白）：
#   - 對照組（現行 harness）：0/2 boot
#   - CLAUDE.md 原句放進系統提示：0/1 boot（軟指示搬通道沒用）
#   - CLAUDE.md 改成強制語氣、不動系統提示：0/2 boot，且模型當場把它判成
#     prompt injection、在對話裡跟使用者講明「我不會照做」——比沒 boot 更糟
#   - 系統提示放同一句強制指示（本檔）：4/4 boot
# 判讀：決定性的是**通道**不是**措辭**。專案檔案的指示模型可以自行否決，系統提示不會。
# 這只把「要不要讀」的選擇拿掉，被讀的還是同一批檔案（boot 仍走 Read/Bash，
# assert.sh 的 boot 斷言照舊成立），不注入任何教練內容。
# BOOT_PREAMBLE=0 關閉（跑舊行為做 A/B 對照）；裸環境的 harness（skill-standalone）
# 沒有 AGENTS.md，一律關掉。
BOOT_PREAMBLE_FILE="${BOOT_PREAMBLE_FILE:-${EVAL:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}/boot-preamble.txt}"
if [ -z "${BOOT_PREAMBLE+set}" ]; then
  BOOT_PREAMBLE="$(cat "$BOOT_PREAMBLE_FILE" 2>/dev/null)"
elif [ "$BOOT_PREAMBLE" = "0" ]; then
  BOOT_PREAMBLE=""
fi

# 旗標支援度前檢（純本機，不呼叫 API）：舊版 CLI 遇到不認得的旗標會直接退出，
# 整輪空跑才發現太貴——寧可退回舊行為並在終端機出聲。
_claude_help="$(claude --help 2>/dev/null)"
case "$_claude_help" in *--setting-sources*) ;; *)
  [ -n "$SETTING_SOURCES" ] && echo "⚠️  這版 claude CLI 不支援 --setting-sources：改用 CLI 預設，使用者層 skill 可能搶走 turn 1（見 evals/README.md，跑之前先 mv ~/.claude/skills）" >&2
  SETTING_SOURCES="" ;;
esac
case "$_claude_help" in *--append-system-prompt*) ;; *)
  [ -n "$BOOT_PREAMBLE" ] && echo "⚠️  這版 claude CLI 不支援 --append-system-prompt：boot preamble 停用，boot 率會掉回 issue #21 的水準" >&2
  BOOT_PREAMBLE="" ;;
esac

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
  local ss=(); [ -n "$SETTING_SOURCES" ] && ss=(--setting-sources "$SETTING_SOURCES")
  ( cd "$d/.sim" && claude -p "$prompt" \
      --model haiku \
      --output-format json \
      --allowedTools "" \
      --max-turns 2 \
      "${ss[@]}" ) > "$raw" 2>> "$d/err.log"
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
  if [ -s "$sfile" ]; then
    extra=(--resume "$(cat "$sfile")")
  elif [ -n "$BOOT_PREAMBLE" ]; then
    # 只在 turn 1（尚無 session id）注入：往後的 turn 是 --resume，SOUL 已在對話脈絡裡，
    # 再注一次只會誘發重讀、平白改變成本與 tools.log。
    extra=(--append-system-prompt "$BOOT_PREAMBLE")
  fi
  [ -n "$SETTING_SOURCES" ] && extra=("${extra[@]}" --setting-sources "$SETTING_SOURCES")
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
