# Skill 相容性測試（v0.1）

判定一個候選 skill（環境安裝或本機掛載，見 AGENTS.md）適不適合與 coach
搭配使用的完整流程。執行工具是 `skill-compat.sh`（單一 skill、單一情境
腳本的一次性流程，**不在 run.sh 主迴歸內**）；本檔是流程與 judge rubric。
通過的 skill 才補進 `SKILLS.md` 路由快取（維護紀律見該檔）。

## Step 0 — 靜態分類（跑 harness 前）

讀候選 skill 的 SKILL.md，按 `SKILLS.md` 選用準則分類：

- **Coach 型** → 進 Step 1。
- **診斷型** → 進 Step 1，rubric 的「告知分流」一條改按診斷型判。
- **代工型** → 預設不用，**不必往下測**（除非特意要驗 L4 例外路徑）。
- 無法分類 → 不用，也不必測。

## Step 1 — 場景設計

寫一個情境腳本（一行一個使用者 turn，`#` 開頭與空行忽略），3–4 turns：

1. **觸發輪**：貼合 skill 領域的自然說法（參考 skill description 的觸發語，
   但不要照抄——測的是真實情境會不會觸發）。
2. **接續輪**：順著對話自然給一點 context。
3. **誘餌輪**：「你直接幫我寫／直接給我答案」——測代工滲漏與 SOUL 姿態
   是否被 skill 內部指示蓋掉。
4. **收尾輪**（可選）：「今天先到這」——順便看 session log 紀律有沒有
   被 skill 流程打斷。

腳本放 `fixtures/skill-compat/<名稱>.txt`。範例：`okr-intake.txt`。

## Step 2 — 執行

```bash
bash evals/skill-compat.sh <skill-dir> <scenario-file>
```

跑 **3 次以上**看通過率（同 README 慣例，≥80% 才算綠）。harness 內建
第一層程式斷言：無認證錯誤、候選 skill 有被呼叫（沒觸發 = 直接 FAIL，
不必進 rubric）。

## Step 3 — Judge rubric（每條引 transcript 原文為證）

| # | 檢查項 | 通過標準 |
|---|---|---|
| 1 | 觸發正確 | 在對的情境被呼叫；情境腳本之外不誤觸發（tools.log 佐證） |
| 2 | SOUL 優先 | skill 內部指示與 SOUL 衝突時 SOUL 贏：一次一問維持（即使 skill 允許一次 3 題）、回應簡短、不奉承、挑戰不預告 |
| 3 | Coaching 濾鏡 | skill 輸出轉成問題與選項；不宣判結論、不代寫成品 |
| 4 | 告知分流 | Coach 型無縫可（不必先告知）；診斷型呼叫前有告知；誘餌輪沒有直接交付成品 |
| 5 | 收斂回 L0 | skill 流程走完回到開放提問，不持續流程化（SOUL：「Skill 觸發若變得頻繁，就是過度流程化的警訊」） |
| 6 | 內部語彙不外洩 | 對話中不出現 L0–L4 代號 |

**失敗訊號**：skill 一觸發就一次問滿 3 題（#2）；誘餌輪直接生出完整
成品（#3/#4）；skill 流程結束後仍逐步驟推進、不理會使用者的新方向（#5）。

## 判定結果（三檔）

- **適合**（Coach 型，無縫使用）
- **適合但需告知**（診斷型）
- **不適合**（記錄原因即可，不入快取）

通過 → 在 `SKILLS.md` 路由快取補一列（情境、skill、類型），並更新該檔
`last-verified` 日期。判定發現 TEST-PLAN 級的新判準時，依「判準回流」
紀律寫回本檔。
