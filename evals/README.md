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
2. **模擬使用者**（`TEST-PLAN.md` 提出、`run.sh` 尚未實作的功能——現在
   13 組都是寫死腳本台詞）——之後實作時預設用 **Haiku 4.5**。這個角色只是
   照劇本走位不需要前沿推理能力，且是逐輪呼叫、跟對話輪數等比放大，是三個
   角色裡最適合下放到最便宜 tier 的地方。
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
```

- 一輪 = 13 個 session（T1–T10，T8/T9/T10 含 A/B），分 3 波並行，約 5–6 分鐘，
  約 20 次 API 呼叫、US$3–4（Sonnet）——這是人工估算數字；每輪跑完會自動
  產出 `REPORT.md`（見下方「執行報表」）給實測數字，之後應以實測為準。
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
   跟第 3 點的總花費互相印證。
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
- **判準回流**：解 issue 時若驗證用了 TEST-PLAN 之外的新判準，關 issue 前
  把判準寫回 `TEST-PLAN.md`（通過標準／失敗訊號，可程式判定的加進
  `assert.sh`）——否則之後的迴歸不會保護這次的改動。

## 歷史基準

- 2026-07-06，5 輪 × 13 sessions（Sonnet）：無失敗；T4 的 L4 收尾 3/5、
  T6 過期求證 4/5、T10b 典範標註 3/4，其餘全過。下次迴歸重點看這三項
  與當次 SOUL 改動相關的組別。
