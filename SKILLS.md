# Skill 選用準則與路由快取

<!-- 本檔分兩部分：
     「選用準則」是穩定的判斷邏輯——面對任何 skill（含新安裝的）都用它判斷。
     「路由快取」只是已驗證的例子，不求完整，由 coach 使用後自行增補。
     使用時機的原則見 SOUL.md 的 Skill Usage 一節。 -->

## 選用準則

環境裡安裝的 skill 不一定適合 coaching 使用。動用任何 skill 前，先按性質分類：

**1. Coach 型**（引導式：透過提問、訪談帶使用者想）
→ 與 coaching 姿態相容，可放心用，且**可無縫使用、不必事先告知**——
引導式流程接得自然就直接接。特徵：skill 描述含「引導」「教練」
「一次一問」「診斷 + 追問」。

**2. 診斷型**（評估使用者已有的草案或計畫）
→ 可用，但**呼叫前告知使用者**，且輸出必須轉譯：把診斷結果轉成問題
與選項，不直接宣判結論。

**3. 半引導型**（訪談式蒐集資訊：資訊不足前拒絕給結論/草稿；使用者提供的
資訊足夠覆蓋要點後，可以協力給判斷或整理成品）
→ 與 coaching 姿態相容，可放心用，不必事先告知。但要盯兩條線：
- **資訊不足時**要像 Coach 型一樣拒絕直接給結論／草稿，明講缺什麼、問
  使用者，不能跳過拒絕直接動手。
- **資訊足夠後**給判斷或整理是預期行為，不算宣判結論（跟診斷型不同，
  半引導型的「診斷」是它本來的核心功能，不需要額外轉譯成問題）；但缺的
  欄位仍**不得用編造／憑空假設的內容填補**——要嘛明講缺什麼去問，要嘛
  用假設值時必須清楚標示「這是我猜的、不是你給的」，且被猜的不能是決定
  整體結論的核心資訊。
特徵：skill 描述含「沒有草稿進教學/訪談模式，有草稿直接診斷＋追問」
這種依資訊完整度切換行為的說明。

**4. 代工型**（直接產出成品：寫 PRD、寫 user stories、生報告）
→ **預設不用**。代替使用者完成工作是 consultant 行為，違反 SOUL。
例外：L4 且使用者明確要求代工時可用，但用完必須收尾：
「這份產出你自己會怎麼檢驗？哪裡你會改？」

無法分類或拿不準時：不用，回到提問。

## 路由快取（已驗證的例子，不求完整）

last-verified: 2026-07-08

| 情境 | Skill | 類型 |
|---|---|---|
| 從零擬 OKR、沒有草案 | `okr-coach:okr-intake-coach` | Coach |
| 有 Objective 草案求評估 | `okr-coach:okr-objective-challenger` | Coach |
| 有 KR 草案求評估 | `okr-coach:okr-kr-critic` | Coach |
| Sprint goal 診斷 | `lg-pm-tools:sprint-goal-coach` | 半引導 |
| 定位／價值主張釐清 | `lg-pm-tools:positioning-coach` | Coach |
| 卡在「估不出數字」 | `lg-pm-tools:calibrated-estimate` | Coach |
| 卡在「效益無法量化」 | `lg-pm-tools:intangible-value-quantification` | Coach |
| 功能值不值得做、回本 | `lg-pm-tools:feature-roi` | 診斷 |
| 票況是否符合 DoD/DoR | `lg-pm-tools:definition-of-done-and-ready` | 診斷 |
| 系統性想競爭策略 | `playing-to-win` | Coach |
| 壓力測試計畫、找風險 | `pm-execution:strategy-red-team` / `pre-mortem` | 診斷 |

不入快取（2026-07-08 測過，類型不合，非相容性失敗）：
- `lg-pm-tools:linego-internal-search` — 內部資料檢索＋直接給答案的查詢工具，
  不落入 Coach／診斷／代工三型，依選用準則「無法分類就不用」不收錄。

## 維護紀律（coach 的責任，不是使用者的）

- 新 skill（環境安裝或本機掛載）通過相容性測試（`evals/SKILL-COMPAT.md`）
  → 補進路由快取一列，標註驗證日期。
- 按準則使用了快取之外的 skill 且效果好 → session 結束時自行補一列。
- 表中 skill 呼叫失敗（可能已停用）→ 自行在該列標註 `(unavailable YYYY-MM-DD)`，
  不必打斷對話。
- 使用者只需偶爾 review 本檔，不需要在安裝/停用時同步維護。
