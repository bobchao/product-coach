# 評測 Runbook

給任何一台機器（或任何一個 Claude Code session）照做的完整流程。
測試**設計**與各組通過標準在 `TEST-PLAN.md`；本檔只講**怎麼執行與判定**，
照做即可，不需要重新設計。

## 前置條件

1. `claude` CLI 已安裝**且已登入**——先跑一次煙霧測試確認，不要跳過：
   ```bash
   claude -p "只回覆：OK" --model sonnet --output-format json | jq -r '.result'
   ```
   若回傳含 `authentication_error` / `401`，表示 OAuth token 過期（曾發生過，
   token 過期後所有測試會「跑完」但全是錯誤訊息）。解法：終端機執行
   `claude` → `/login` 重新登入。
2. `jq`、`rsync` 可用（macOS 內建 rsync 即可）。
3. 模型：`--model sonnet`（寫死在 run.sh；成本考量，勿改成 opus 級）。
4. T8a 需要 okr-coach skill——已內建在 `fixtures/t8a-skills/`，runner 會
   自動裝進測試副本，不需另外安裝。

## 模型分工

整套評測有三個會耗 token 的角色，不要全部套同一個 tier：

1. **被測 coach**（`run.sh` 實際跑對話的 `claude -p ... --model sonnet`）
   ——維持 Sonnet，不要升級成 opus。這是正在測的東西本身，模型必須跟正式
   環境一致，換掉就是測了另一個產品，所有歷史通過率基準也會失去對照意義。
2. **模擬使用者**（已實作，`SIM=1` 時 T4/T5 的使用者台詞改由模型依
   `fixtures/personas/*.md` 的走位動態生成；其餘組別仍是寫死腳本台詞）
   ——預設用 **Haiku 4.5**（`run.sh` 的 `--model haiku`）。這個角色只是
   照劇本走位不需要前沿推理能力，且是逐輪呼叫、跟對話輪數等比放大，是三個
   角色裡最適合下放到最便宜 tier 的地方。實作細節：模擬者在測試副本外的
   空目錄執行（避免載入 SOUL 變成第二個 coach）、無狀態（每輪餵 persona
   卡＋transcript 全文）、上限 8 輪，走位完成用 `<<END>>` 收尾；脫稿或
   未收尾的 run 由 runner 標 `INVALID`（判定規則見 TEST-PLAN 的
   「模擬模式」段落）。
3. **LLM judge**（第二層判定，見下）——預設用 **Opus**，刻意跟被測 coach
   不同 tier。judge 是逐份 transcript 判定（一輪最多 13 次），輸入內容遠比
   被測 coach session 短，用 Opus 只占整輪成本一小塊；同時滿足下方「避免
   同源偏誤」原則，也呼應歷史基準裡本來就較不穩、屬於語氣/姿態質性判定的
   組別（T4 L4 收尾、T6 過期求證、T10b 典範標註）。如果之後想再省，可以做
   兩段式：先用 Haiku 對每份 transcript 快速初判，只有 FAIL 或不確定的才
   送進 Opus 覆核；目前 judge 仍是人工執行，兩段式留給未來自動化時再做。

## 執行

```bash
bash evals/run.sh                      # 結果在 mktemp 目錄（路徑見輸出）
RUN_DIR=/tmp/coach-eval-r2 bash evals/run.sh   # 或自訂輸出目錄
ONLY="t4 t8b t10b" bash evals/run.sh   # 只跑子集（迴歸特定組別時省 token）
SKIP="t11a" bash evals/run.sh          # 全套但排除指定組（見下方 T11a 注意事項）
SIM=1 ONLY="t4 t5" bash evals/run.sh   # T4/T5 用 Haiku 模擬使用者（見「模型分工」2）
```

**T11a 每次都要刻意決定跑不跑**——它是最貴的一組（$0.65–0.9/run，含完整
搜尋查證迴圈，且成本會被網路環境放大）。判斷準則：改動涉及
`references/case-sharing.md`、SOUL 案例鉤子、Research Duties 或搜尋行為
→ 必跑；與案例機制無關的改動 → `SKIP="t11a"` 排除（T11b 便宜，照常跑）。
SOUL 大幅改動的 merge 前最後一輪，仍建議含 T11a 跑一次完整全套。

- **SIM 模式的通過率是另一條基準線**：歷史基準（下方）是固定台詞測出來的，
  兩者不可混算。先平行跑幾輪（scripted 與 sim 各自判定＋人工抽查模擬者
  擬真度），校準夠了再討論把 sim 設為 T4/T5 預設。每輪 sim 增量成本
  以 `REPORT.md` 的「模擬使用者小計」為準（估 < US$0.1）。

### Skill 相容性測試（單獨流程，不在主迴歸內）

評估一個新候選 skill（環境安裝或本機掛載）適不適合與 coach 搭配時：

```bash
bash evals/skill-compat.sh <skill-dir> <scenario-file>
# 例：bash evals/skill-compat.sh \
#   evals/fixtures/t8a-skills/.claude/skills/okr-intake-coach \
#   evals/fixtures/skill-compat/okr-intake.txt
```

流程與 judge rubric 見 `SKILL-COMPAT.md`；同樣吃 claude CLI 登入態
（前置條件同上）。

### Skill 獨立運作測試（單獨流程，不在主迴歸內）

驗證一個 skill 抽離本 repo 後能否自力運作（可攜性宣稱的行為驗證，
與 skill-compat 相反：compat 測「跟 coach 搭配」，standalone 測
「完全沒有 coach 時」）。測試副本是裸環境——沒有 SOUL/AGENTS/memory，
只有 skill 本身：

```bash
bash evals/skill-standalone.sh .claude/skills/pm-growth-coach \
  evals/fixtures/growth-standalone/basic.txt
SIM=1 bash evals/skill-standalone.sh .claude/skills/pm-growth-coach \
  evals/fixtures/growth-standalone/basic.txt   # Haiku 模擬使用者（建議預設）
```

**建議用 SIM 模式跑**：scripted 模式台詞寫死，五輪跑出來幾乎一樣，
測不出變化；SIM=1 時開場白取情境腳本第一個 turn，其後由 Haiku 照
`fixtures/personas/growth-standalone.md` 走位動態生成（第三個參數可
換 persona）。SIM 與 scripted 是兩條基準線，不可混算；模擬者脫稿或
未收尾標 `INVALID`，不計入分母（規則同主迴歸的模擬模式）。

第一層程式斷言：（SIM 模式先過 validity gate）無認證錯誤、skill 在
裸環境有觸發、journey 直接寫進工作目錄（skill 不得依賴宿主記憶機制，
也不必先問使用者存哪）。
第二層 judge 檢查項印在輸出的 `STANDALONE.md`。首選情境腳本
`fixtures/growth-standalone/basic.txt` 是 first-party harness，進版控
（與 skill-compat 的個人掃描腳本不同）。同樣跑 3 輪以上、≥80% 才算綠。

- 一輪 = 23 個 session（T1–T15，T8/T9/T10/T11 含 A/B，T12 含 A/B/C，
  T13/T15 含 A/B），分 5 波並行，約 6–7 分鐘，約 25 次 API 呼叫、US$4–5
  （Sonnet；T11a 一組就佔 $0.65–0.9，它要跑完整的搜尋查證迴圈）——這是
  人工估算數字；每輪跑完會自動產出 `REPORT.md`（見下方「執行報表」）給
  實測數字，之後應以實測為準。
- **T13–T15（issue #16 的 non-coachable 情境）是反應式對話，SIM 是主要跑法**
  ——scripted 只是煙霧測試（走位依賴 coach 上一手，寫死腳本測不出反應）。
  跑這三組求通過率時用 `SIM=1`；SIM_MAX_TURNS 預設 8 即可（persona 卡自帶
  第 5 輪收尾上限）。若 T13 的 INVALID／誤演率偏高，可把演使用者的模型從
  Haiku 往上調一級（改 `lib.sh` 的 `sim_turn`），被測 coach 仍維持 Sonnet。

## ⚠️ 成本注意事項（2026-07-12 事故記錄）

一次在遠端沙盒（Claude Code on the web）跑的 3 輪迴歸實際花掉 **$17.9**
（本機基準約 $3–4/輪），最後撞到 org 月度用量上限、評測中途斷頭。超支原因：

1. **遠端沙盒的 proxy 會間歇性擋 WebFetch/TLS**：T11a 的查證迴圈每次被擋
   都觸發換錨重試、甚至 debug 呼叫，token 白燒；proxy 也會弄壞 session
   （空 tools.log、API error），逼出補跑——這些成本在本機不存在。
2. T11a 本身是最貴的測試組（完整搜尋查證是它的本質成本）。

**避免再撞到的做法**：

- **評測一律在本機跑**，不要在遠端沙盒跑——又貴（1.5–2 倍以上）又不穩
  （INVALID session 率高）。
- 開發迭代期用 `ONLY=` 跑子集，全套留給 merge 前的最後確認。
- 可考慮**低階模型做便宜預檢**：迭代中先用 `--model haiku` 之類的低階
  model 當 coach 跑一輪抓大錯（skill 沒觸發、檔案沒寫入這類程式斷言層的
  問題），確認無誤再花錢跑正式的 Sonnet 輪。注意：預檢結果**不計入
  通過率基準**——基準必須是 Sonnet（見「模型分工」1），低階預檢只是
  省錢的煙霧測試。
- 跑之前看一眼額度餘裕；撞到 spend limit 時 session 會回傳
  "You've hit your org's monthly spend limit"，該輪所有後續 turn 都是廢資料。
- 跑多輪求通過率時**依序跑**（避免 rate limit），例：
  ```bash
  for r in 1 2 3; do RUN_DIR=/tmp/coach-eval-r$r bash evals/run.sh; done
  ```
- 每個 session 目錄產出：`transcript.md`（對話）、`tools.log`（工具呼叫）、
  `turn*.jsonl`（原始 stream-json）、`memory/`（可檢查檔案寫入）。
- 技術備註：runner 刻意不用 `set -u`（macOS bash 3.2 會把空陣列展開當
  unbound variable，曾因此整輪秒掛）。

## 判定（三層）

**第一層：程式斷言**（每輪必跑）

```bash
bash evals/assert.sh <RUN_DIR>
```

檢查：無 401、T7 檔案寫入（session log／team.md／MEMORY.md）、T8a skill
呼叫、T9b memory 無健康資訊、T10a 有真實搜尋。任何 FAIL 都要查原因。

**第二層：LLM judge（質性判定）**

由執行評測的 Claude（或另開 session）逐組閱讀 `transcript.md`，
**對照 `TEST-PLAN.md` 各組的「通過標準」與「失敗訊號」逐條判定**，
每條要能引用 transcript 原文為證。輸出格式：每組 `✅ 通過 / ⚠️ 部分通過
（缺哪一條）/ ❌ 失敗（違反哪一條）`，彙整成表。

SIM 模式的 run 要**先過 validity gate 再判 coach**：模擬者脫稿或未收尾
（目錄有 `INVALID` 檔，`report.sh` 也會列出）→ 該 run 不計入通過率分母，
不算 coach FAIL。規則與 beat 錨定的判準見 TEST-PLAN 各組的「模擬模式」段落。

判定時的既有決議（優先於 TEST-PLAN 字面）：
- T1：onboarding 三題「一次全問」與「逐題問」都算通過（2026-07-06 決議）。
- T8a：coach 型 skill 無縫使用、不事先告知，算通過（issue #6 決議）。
- 簡體字混入：記錄但不影響判定（issue #5 決議：模型層問題不修）。

**第三層：人工抽查**

Bob 每次改 SOUL.md 後抽讀 2–3 份 transcript，校準 judge 有沒有漏。

## 執行報表

`run.sh` 收尾會自動跑 `evals/report.sh <RUN_DIR>`，輸出印到終端機同時存成
`<RUN_DIR>/REPORT.md`。純解析 `turn*.jsonl`（每次 `claude -p` 呼叫的原始
stream-json 輸出）與 `run.log`，**不呼叫任何 API**，所以可以隨時對舊的
`RUN_DIR` 重跑，不會再花錢：

```bash
bash evals/report.sh <RUN_DIR>                      # 單輪
bash evals/report.sh /tmp/coach-eval-r1 /tmp/coach-eval-r2 /tmp/coach-eval-r3   # 多輪加總
EXPECTED_MODEL=haiku bash evals/report.sh <RUN_DIR> # 覆寫預期模型（預設 sonnet）
```

回答三件事：

1. **模型是否如預期**：讀每個 turn 的 `modelUsage`（CLI 自己回報的、
   每個實際用到的模型的 token/花費明細），跟 `EXPECTED_MODEL`（預設
   `sonnet`，對照「模型分工」一節）比對，只要有一個 turn 出現非預期的
   模型（fallback、或某個 skill/subagent 悄悄換了模型）就 `FAIL` 並列出
   是哪個 session、哪個 turn、用了什麼模型；PASS 的模型同時列出 `$` 花費，
   跟第 3 點的總花費互相印證。SIM 模式的 `sim*.jsonl` 另外對
   `SIM_EXPECTED_MODEL`（預設 `haiku`）做同樣檢查。已知例外：CLI
   （2.1.x 實測）在 session 啟動時會用 haiku 做一次微量內部輔助呼叫
   （約 $0.001），成本 < $0.005 的 haiku 用量列 `NOTE` 不列 `FAIL`。
2. **花的時間**：兩個數字都給，意義不同——`run.log` 首尾時間戳算出的
   **真實 wall-clock**（3 波平行，比累加數字短），以及所有 turn 的
   `duration_api_ms` **加總**（等於「如果完全序列執行要花多久」，看得出
   平行化省了多少）。
3. **花費估算**：所有 turn 的 `total_cost_usd`（CLI 官方算好的美金花費）
   加總；丟多個 `RUN_DIR` 進去（例如跑 3–5 輪求通過率時）會再加總成
   「這次迴歸一共花多少錢」。

## 通過門檻與結果去向

- 每組 3–5 輪、通過率 ≥ 80% 才算綠；單輪結果不作數。
- 判定報告寫 `evals/RESULTS-<日期>.md`、原始 transcript 歸檔
  `evals/runs/<日期>-run<n>/`——**兩者都在 .gitignore 內，只留本機**；
  要留存的綜合結果由 Bob 手動放 GitHub wiki。
- 發現的問題開 GitHub issue（`gh issue create`），不寫進版控檔案。
  在沒有 `gh` CLI 的環境（例如 Claude Code Cloud Environment）改用對應的
  GitHub MCP 工具（如 `mcp__github__issue_write`）達成同樣效果。
- **判準回流**：解 issue 時若驗證用了 TEST-PLAN 之外的新判準，關 issue 前
  把判準寫回 `TEST-PLAN.md`（通過標準／失敗訊號，可程式判定的加進
  `assert.sh`）——否則之後的迴歸不會保護這次的改動。

## 歷史基準

- 2026-07-06，5 輪 × 13 sessions（Sonnet）：無失敗；T4 的 L4 收尾 3/5、
  T6 過期求證 4/5、T10b 典範標註 3/4，其餘全過。下次迴歸重點看這三項
  與當次 SOUL 改動相關的組別。
