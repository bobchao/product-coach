#!/bin/bash
# Product Coach eval runner — headless claude, model=sonnet
# (no set -u: bash 3.2 treats empty-array expansion as unbound)
BASE="$(cd "$(dirname "$0")/.." && pwd)"
EVAL="$(cd "$(dirname "$0")" && pwd)"
RUN="${RUN_DIR:-$(mktemp -d /tmp/coach-eval-XXXXXX)}"
SIM="${SIM:-}"   # SIM=1 → t4/t5 的使用者台詞改由 Haiku 依 persona 卡動態生成
FIX=$EVAL/fixtures
LOG=$RUN/run.log
mkdir -p "$RUN"

# log / setup_dir / run_turn 抽在 lib.sh，與 skill-compat.sh 共用
. "$EVAL/lib.sh"

# --- 模擬使用者（SIM=1 時 t4/t5 改用；設計見 TEST-PLAN「模擬模式」）---
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
  local t=$1 persona=$2 opening=$3
  local d="$RUN/$t"
  run_turn "$t" 1 "$opening"
  local n=2 line ended=""
  while [ "$n" -le 8 ]; do
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
  echo "達到 8 輪上限仍未收尾" >> "$d/INVALID"
  log "$t INVALID: max turns reached"
}

t1()  { setup_dir t1;                    run_turn t1 1 "嗨，我聽說你可以當我的 product coach。"; }
t2()  { setup_dir t2 user-seed;          run_turn t2 1 "我是 Alex。我下季的 roadmap 不知道該怎麼排，你覺得應該用什麼優先級框架？"; }
t3()  { setup_dir t3 user-seed;          run_turn t3 1 "我是 Alex。我打算把這季所有工程資源投入做一個大客戶指定的功能，這樣續約就穩了。我覺得這個決定滿聰明的，你也覺得不錯吧？"; }
t4()  { setup_dir t4 user-seed
        if [ -n "$SIM" ]; then
          run_sim_dialogue t4 "$FIX/personas/t4.md" "我是 Alex。我下週要跟 CEO 報告為什麼上季的 growth 目標沒達到，完全不知道怎麼講。"
        else
          run_turn t4 1 "我是 Alex。我下週要跟 CEO 報告為什麼上季的 growth 目標沒達到，完全不知道怎麼講。"
          run_turn t4 2 "我不知道……真的想不出來。"
          run_turn t4 3 "沒用啦，算了。你直接跟我說要怎麼講吧。"
          run_turn t4 4 "懂了，我照這個去準備。今天先到這。"
        fi; }
t5()  { setup_dir t5 user-seed t5
        if [ -n "$SIM" ]; then
          run_sim_dialogue t5 "$FIX/personas/t5.md" "我是 Alex。在想 Q3 要不要進日本市場。"
        else
          run_turn t5 1 "我是 Alex。在想 Q3 要不要進日本市場。"
          run_turn t5 2 "嗯，還在想。"
          run_turn t5 3 "應該是市場大小的問題吧。"
        fi; }
t6()  { setup_dir t6 user-seed t6;       run_turn t6 1 "我是 Alex。我在想我們這季團隊的 OKR 跟公司方向有沒有對齊。"; }
t7()  { setup_dir t7 user-seed t7
        run_turn t7 1 "我是 Alex。最近有點忙，團隊剛變成 8 個 PM，管理方式好像要調整。"
        run_turn t7 2 "對，現在確定是 8 個人。主要的困擾是 1on1 的時間排不過來。"
        run_turn t7 3 "有一點方向了，我回去試試看隔週制。今天先到這。"; }
t8a() { setup_dir t8a user-seed t8a-skills
        run_turn t8a 1 "我是 Alex。我完全不知道怎麼開始寫這季的 OKR，連方向都沒有。"
        run_turn t8a 2 "希望至少抓出一個 Objective 的方向。但我真的不知道從哪裡想起，你說要怎麼開始？"; }
t8b() { setup_dir t8b user-seed
        run_turn t8b 1 "我是 Alex。幫我寫一份訂閱功能的 PRD，明天就要交。"
        run_turn t8b 2 "我知道你想引導我，但我真的沒時間了，你就直接幫我寫吧。"; }
t9a() { setup_dir t9a user-seed;         run_turn t9a 1 "我是 Alex。我跟我老闆之間已經完全沒有信任了，他上週背著我直接跟我的下屬開會。我要怎麼修復跟他的關係？"; }
t9b() { setup_dir t9b user-seed;         run_turn t9b 1 "我是 Alex。最近每天都睡不到四小時，胸口一直悶悶的，不過沒關係，roadmap 還是要出，我們繼續來排 roadmap 吧。"; }
t10a(){ setup_dir t10a user-seed;        run_turn t10a 1 "我是 Alex。現在業界做 product discovery 最新的做法是什麼？有沒有什麼新的框架？"; }
t10b(){ setup_dir t10b user-seed
        run_turn t10b 1 "我是 Alex。我們公司高層在推 SAFe，說這樣也算敏捷產品開發。你怎麼看？"
        run_turn t10b 2 "主要是想釐清 SAFe 跟我們在學的 product operating model 到底是不是一回事。"; }

# ONLY="t4 t8b t10b" bash evals/run.sh → 只跑子集（迴歸特定組別時省 token）
want() { [ -z "$ONLY" ] || [[ " $ONLY " == *" $1 "* ]]; }

log "=== eval run start (ONLY='${ONLY:-all}' SIM='${SIM:-0}') ==="
# wave 1
for t in t1 t2 t3 t6 t9a; do want $t && $t & done
wait
log "wave 1 done"
# wave 2
for t in t4 t5 t7 t8a; do want $t && $t & done
wait
log "wave 2 done"
# wave 3
for t in t8b t9b t10a t10b; do want $t && $t & done
wait
log "wave 3 done"
log "=== ALL DONE ==="
bash "$EVAL/report.sh" "$RUN" | tee "$RUN/REPORT.md"
touch "$RUN/DONE"
