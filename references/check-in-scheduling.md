# Check-in 排程機制 — recipes

（何時讀這份檔：要建立、更改或取消定期回顧提醒的排程時。行為規則——何時
提議、語氣、退避——在 `AGENTS.md` 的「Check-in reminders」，本檔只管
「怎麼把排程建起來」。）

## 原則

1. **先盤點，再動手**：同一個環境可能有不止一種排程機制。先確認目前環境
   實際提供哪些（看可用工具清單裡有沒有 cron／schedule／trigger／routine
   類的工具），再對照下方 recipes。
2. **有相符 recipe 就照做**，免除重複探索。多個機制都可用而不確定哪個
   合適時，問使用者（收斂型選擇題）。
3. **無相符就探索**：挑一個最貼近的機制，小步驗證（先列出現有排程確認
   工具真的可用，再建立）。用完把可重用的步驟記回 `memory/check-in.md`
   的「機制操作筆記」，日後同環境直接複用。
4. **經驗回流**：在新環境驗證過的做法，值得補成下方的新 recipe（進版控，
   所有使用者受益）——這是少數建議對本檔送 PR 的情況。
5. **一個都沒有 → passive 模式**：把下次 check-in 日期記進
   `memory/check-in.md`，靠 boot sequence 在過期後帶起，並跟使用者說清楚
   （「這個環境我建不了排程，我會記下時間，下次你回來而時間到了，我會
   主動提」）。**絕不虛構工具呼叫**，也不假裝排程已建立。

## 排程 prompt 模板

排程觸發的是一個全新 session，prompt 必須是獨立完整指示（觸發當下沒有
任何對話 context）：

```
以這個資料夾為工作目錄。照 AGENTS.md 的 boot sequence 進入 coach 人格，
然後執行定期回顧 check-in：讀 memory/MEMORY.md 與最近幾篇
memory/sessions/*.md，從未完事項（open threads）挑最有分量的一條——
若 MEMORY.md 的 Growth 索引顯示 checkpoint 已過期，一併考慮——用一句
像人在關心的話開場邀請，例如「上次聊到 X，目前狀況如何，想聊聊嗎？」。
不用「session」「排程」這類系統詞；沒有值得提的內容就什麼都不發。
發出一則後即收，不追問。最後依 AGENTS.md 的 Check-in reminders 規則
更新 memory/check-in.md。
```

頻率是「每兩週」而機制只支援週級 cron 時：照每週觸發，並在 prompt 加一句
「先讀 memory/check-in.md 的『上次發送』，未滿兩週就什麼都不做、靜默結束」。

## Recipes

### Claude Code／Cowork 排程工具（本機桌面環境）

- 特徵：工具清單有 Cron 類工具（如 CronCreate／CronList／CronDelete），
  或 Cowork 介面本身提供 scheduled task；啟用後專案根目錄會出現
  `.claude/scheduled_tasks.lock`（已在 `.gitignore`）。
- 建立：用上方 prompt 模板建立排程，頻率照使用者選的；觸發時段挑使用者
  慣用的時間，不確定就問一句。
- 確認與取消：用對應的 List／Delete 工具。使用者也可能從介面自行刪除，
  取消或異動後要跟 `memory/check-in.md` 對一次帳。

### Claude Code on the web／remote（Routines）

- 特徵：工具清單有 trigger 類工具（如 create_trigger／list_triggers／
  delete_trigger，常掛在 claude-code-remote 之類的 MCP server 下）。
- 建立：cron expression 設週級；每兩週用上方的「上次發送」自查法。
- 注意：remote 環境的排程綁在該環境——使用者若主要在本機用 coach，
  提醒會出現在 remote 而不是本機。建立前先確認這是使用者要的入口。

### 找不到任何排程工具

→ passive 模式（見原則 5）。
