# Plan — Issue #9：定期回顧提醒（排程 check-in）

> 對應 issue：[#9 Idea: 定期回顧提醒（排程 check-in），幫助養成持續 coaching 的習慣](https://github.com/bobchao/product-coach/issues/9)（milestone v0.3）
>
> ⚠️ 命名注意：`evals/assert.sh:27`、`evals/TEST-PLAN.md:86,115` 裡既有的「issue #9」
> 指的是**收尾記憶紀律**的設計（編號撞號），與本 issue 無關。本計畫的新增內容
> 一律以 issue 標題或 URL 指稱，不用裸編號；既有引用不動。

## Context

目前的使用模式是使用者想到才開 session，教練不會主動找回使用者。教練的核心
賣點是跨 session 的累積（`memory/sessions/` 的 open threads、`insights/` 的
觀察），但使用者忘了回來，累積就浪費了。本計畫加入**選擇加入（opt-in）的
定期回顧提醒**：以固定週期主動開個頭，內容從 session log 的 open threads 撈，
不強迫互動、隨時可退出。

## 架構決策：誰觸發、在哪跑（回答待釐清 #1）

教練本體是一組 Markdown 指示，跑在使用者自己的 Claude Code／Cowork 環境，
**session 之間沒有常駐程序**（`AGENTS.md:93`「Session boundary = one
conversation」）。所以提醒不可能由教練自己在閒置時發出，只能靠**執行環境的
排程機制**開一個新 session。設計成兩層：

1. **主要路徑（環境有排程工具時）**：使用者同意後，教練先**盤點目前環境有
   哪幾類排程機制**（同一環境可能不只一種：Cowork scheduled task——先例見
   `DESIGN.md:248`、Claude Code 的排程工具——`.gitignore:3` 的
   `.claude/scheduled_tasks.lock` 證實這層設施存在、或其他 runtime 提供的
   triggers），挑最適合的；不確定哪個合適時問使用者（收斂型選擇題）。
   排程的 prompt 是獨立完整指示：以本資料夾為工作目錄跑 boot sequence →
   讀 `MEMORY.md` 與最近的 `memory/sessions/*.md` → 從 open threads 組一句
   簡短開場。

   **排程機制 recipes（免除重複探索）**：比照 SKILLS.md「準則進版控、
   快取進 memory」的既有模式——repo 內建 `references/check-in-scheduling.md`，
   收錄已知環境的建立範例（Cowork scheduled task、Claude Code 排程工具等：
   怎麼建、怎麼列出、怎麼取消）。環境與範例相符就直接照做，免除探索；
   無相符時教練自行探索挑一個用，**用完把經驗記回 memory**
   （`memory/check-in.md` 的機制欄位＋一段可重用的操作筆記），日後同環境
   直接複用。累積驗證過的新環境經驗，可回流進 references 的 recipes
   （進版控，讓所有使用者受益）。
2. **退化路徑（沒有排程工具時）**：純 pull 模式，複用 pm-growth-coach 的
   checkpoint 模式（`.claude/skills/pm-growth-coach/references/follow-up.md:53-58`）：
   把下次 check-in 日期記在 memory，boot sequence 發現過期時，在下一次使用者
   自己開的 session 裡順勢帶起。

兩層都遵守 `AGENTS.md:126-129` 已有的「環境工具條件式使用」慣例
（AskUserQuestion 先例）：有工具就用、沒有就退化、**絕不虛構工具呼叫**。
記憶檔跨入口共用（README「以上入口共用同一份 memory/」），但排程只存在於
建立它的那個環境——`memory/check-in.md` 要記下是在哪個環境、用什麼機制建的。

## 行為設計（回答待釐清 #2、#3）

- **Opt-in only**：教練絕不擅自建排程。時機是 session 收尾時、且條件成立
  （已累積 ≥2 篇含 open threads 的 session log、之前沒拒絕過）才**提一次**。
  頻率選項：每週／每兩週／不用了——收斂型選擇題，可用 AskUserQuestion 呈現
  （`AGENTS.md:126-129` 既有規則）。
- **頻率可改、隨時退出**：使用者任何時候說「不要再提醒」→ 刪除排程（或把
  memory 標成 從不）並一句話確認。拒絕過就不再推銷。
- **提醒內容**：從最近 session logs 撈 open threads／上次說「下次想處理」的
  事；若 `MEMORY.md` Growth 索引顯示成長 checkpoint 已過期，一併帶到。
  **沒東西可撈就不發**——寧可沉默，不硬找話題。
- **語氣**：一則、精簡（SOUL Voice `SOUL.md:36`）、是邀請不是議程，
  而且**像人在關心，不講系統語彙**（不出現「session」「排程」這類機制詞）：
  「上次聊到 X，目前狀況如何，想聊聊嗎？」。不催促、不愧疚施壓。
  使用者不理會就算了，不追發。
- **防騷擾退避**：連續兩次提醒都沒有帶出 session → 自動暫停提醒，下次使用者
  自己開 session 時問一次要不要繼續。
- **議程歸屬不變**：提醒只是開場邀請；使用者帶著別的議題回來，議題優先
  （`SOUL.md:16-17` 已有規則，只引用不重述）。

## 檔案變更

分層依 `AGENTS.md:74-89`：這是「環境怎麼運作」的機制，整段放 AGENTS.md；
**SOUL.md 不動**（議程歸屬、精簡語氣既有條文已足夠治理，重述會違反
「each rule lives in exactly one layer」）。

1. **`AGENTS.md`** — 「Memory operations」之後新增 `## Check-in reminders`
   一節（約 25–30 行）：提議時機與條件、`memory/check-in.md` 的維護、排程
   建立／更新／取消的條件式機制、退化路徑、退避規則。並在 boot sequence
   加第 4 步：`memory/check-in.md` 存在、模式為 passive 且日期過期時，
   於恰當時點（使用者議程優先，收尾輕帶）提起。
2. **`references/check-in-scheduling.md`** — 新增：排程機制 recipes。
   已知環境的建立／列出／取消範例（Cowork scheduled task、Claude Code
   排程工具），加上「無相符時怎麼探索、驗證後回流 recipes」的準則。
   放 references/ 符合分層規則（`AGENTS.md:80-82`）：低頻行為、有明確
   tool moment（建排程當下）可掛，hook 留在 AGENTS.md 的 Check-in 節。
3. **`memory/check-in.md.example`** — 新模板，欄位：狀態（active／paused／
   never）、頻率、機制（所用排程機制與所在環境／passive）、機制操作筆記
   （探索出的可重用經驗）、下次 check-in 日期、連續未回應次數、
   `last-verified`。
4. **`memory/MEMORY.md.example`** — 新增 `## Check-in` 索引區段
   （（尚未建立）），與既有各區段同格式。fixtures 內各自的 MEMORY.md
   不需回填（assert 只查 t7 的 sessions 行，不受影響）。
5. **`README.md`** — 「幾件值得先知道的事」加一條：可選的定期回顧提醒，
   opt-in、怎麼關掉。
6. **`evals/TEST-PLAN.md` + `evals/assert.sh`** — 新增 T12 組（現有組別到
   T11 為止）：
   - **T12a 提議與同意**：seed 兩篇含 open threads 的 session log；模擬
     使用者收尾。通過 = 教練只在收尾提一次、把選擇寫進
     `memory/check-in.md` 並更新 MEMORY.md 索引；fixture 變體（先前已拒絕）
     = 不再提。程式斷言：檔案存在且含頻率欄位。
   - **T12b 提醒組稿**：直接用排程 prompt 起一個 session（手動觸發即可，
     `DESIGN.md:248` 先例），seed 含 open threads 的 log。通過 = 單則簡短
     開場、引用真實存在的 open thread、無捏造、無愧疚語氣、發完即收
     （語氣交給 judge，比照三層判定 `TEST-PLAN.md:365-371`）。
   - 依「判準回流」紀律（`evals/README.md:212-215`），判準先寫進
     TEST-PLAN.md 再動手。

## 驗證

- 新增 T12 組照 runbook 跑 3–5 輪、通過率 ≥80%（`evals/README.md:206`）。
- 手動端到端：在 Claude Code 以 fixtures seed memory → 走一次收尾，確認
  提議與寫檔；再手動以排程 prompt 開 session，確認開場內容與單則即止。
- 回歸：跑 T4、T7（session log 相關組），確認收尾流程沒被影響。

## 不做的事（本輪範圍外）

- 不做趨勢掃描排程（`DESIGN.md:248` 的另一件事，維持 deferred）。
- 不新增 `sessions/*.md.example` 模板——open threads 目前是自由格式
  （欄位清單在 `AGENTS.md:59-63`），LLM 讀取足夠；若 T12b 顯示撈取不穩，
  再回頭補模板。
- 不動 pm-growth-coach skill 本體——它維持環境中立；成長 checkpoint 只是
  提醒內容的其中一個來源。
