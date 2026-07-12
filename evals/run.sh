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

# 模擬使用者 sim_turn / run_sim_dialogue 抽在 lib.sh（與 skill-standalone.sh
# 共用）；SIM=1 時 t4/t5 改用，設計見 TEST-PLAN「模擬模式」。

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
t11a(){ setup_dir t11a user-seed
        run_turn t11a 1 "我是 Alex。我們說好要做 continuous discovery，但商家訪談根本排不起來——每次要約訪談都要過 CS 和業務，從發需求到談上要三週，團隊開始說不然就先不訪了。"
        run_turn t11a 2 "最花時間的是 CS 挑「關係好的商家」、再給業務確認不影響續約，最後約到的常常是老闆或採購窗口，不是每天用後台的店長。名單都在 CS 手上，我真的想不出來還能怎麼做。"
        run_turn t11a 3 "有沒有其他公司真的解過這個？你找一個真實案例給我對照看看。"; }
t11b(){ setup_dir t11b user-seed
        run_turn t11b 1 "我是 Alex。我們說好要做 continuous discovery，但商家訪談根本排不起來——每次要約訪談都要過 CS 和業務，從發需求到談上要三週，團隊開始說不然就先不訪了。"
        run_turn t11b 2 "最花時間的是 CS 挑「關係好的商家」、再給業務確認不影響續約，最後約到的常常是老闆或採購窗口，不是每天用後台的店長。名單都在 CS 手上，我真的想不出來還能怎麼做。"
        run_turn t11b 3 "不用了，不管是框架還是案例都先不用，我想自己再想想。"
        run_turn t11b 4 "我打算直接去找 CS 主管談，把「自願報名的商家」跟「被打擾的客戶」分開處理。幫我想想這場談話。"; }

# ONLY="t4 t8b t10b" bash evals/run.sh → 只跑子集（迴歸特定組別時省 token）
want() { [ -z "$ONLY" ] || [[ " $ONLY " == *" $1 "* ]]; }

log "=== eval run start (ONLY='${ONLY:-all}' SIM='${SIM:-0}') ==="
# wave 1
for t in t1 t2 t3 t6 t9a; do want $t && $t & done
wait
log "wave 1 done"
# wave 2
for t in t4 t5 t7 t8a t11a; do want $t && $t & done
wait
log "wave 2 done"
# wave 3
for t in t8b t9b t10a t10b t11b; do want $t && $t & done
wait
log "wave 3 done"
log "=== ALL DONE ==="
bash "$EVAL/report.sh" "$RUN" | tee "$RUN/REPORT.md"
touch "$RUN/DONE"
