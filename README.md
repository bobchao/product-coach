# Product Coach Agent

一個以 Claude Code 為運行環境的 **Product Coach** agent 原型。它不寫 PRD、不幫你做決定，
而是用提問引導你自己想清楚——立場是 coach，不是 consultant 或 mentor。

## 這是什麼

這個資料夾定義了一個完整的 AI coaching 人格與運作規則：

- 每次對話由使用者設定議程，教練以「澄清 → 反映 → 深化 → 收斂」的節奏提問。
- 預設不給答案，只有在使用者明顯卡住或明確要求時才逐級介入（見 Intervention Ladder）。
- 主要引用 SVPG／Marty Cagan、Teresa Torres、Shreyas Doshi 的 product operating model
  作為教練典範，避免混用不同流派的框架。
- 具備跨 session 記憶，記錄使用者背景、公司/產品 context、以及教練對使用者思考模式的觀察，
  避免重複發問已經講過的事。

## 檔案結構

```
├── CLAUDE.md          # 精簡 loader，載入 AGENTS.md
├── AGENTS.md           # 環境與操作說明：boot sequence、目錄配置、記憶機制
├── SOUL.md             # 教練的核心人格與行為準則（憲法，優先權最高）
├── SKILLS.md           # Skill 選用準則 + 已驗證的路由快取
├── references/
│   └── product-operating-model.md   # product operating model 的權威基準版本
└── memory/
    ├── MEMORY.md.example   # 記憶索引模板（真正的 MEMORY.md 是 gitignored）
    ├── context/            # 公司、產品、團隊的策略 context 模板
    ├── user/               # 使用者角色與成長目標檔案模板
    ├── sessions/           # 逐次 session 紀錄（執行時建立，gitignored）
    └── insights/           # 教練對使用者思考慣性與成長軌跡的觀察模板
```

`memory/` 底下只有 `*.md.example` 模板進版控；實際記憶檔（同名、去掉
`.example`）是執行時才建立的個人資料，預設 gitignored。

## 如何使用

這個 coach 沒有安裝步驟，也沒有要跑的程式。它就是這個資料夾本身——一組
Markdown 指示（`SOUL.md`／`AGENTS.md`／`SKILLS.md`）加上 `memory/`。你要做的
只是讓 Claude 以「這個資料夾為工作目錄」啟動，`CLAUDE.md` 就會自動載入
`AGENTS.md`，agent 隨即依 boot sequence 進入 coach 人格。

不論用哪種入口，啟動後 agent 都會：

1. 讀 `SOUL.md` 並完整採納，成為 coach。
2. 需要時補讀 `references/product-operating-model.md` 校準典範。
3. 讀 `memory/MEMORY.md` 索引，載入與你這次開場相關的記憶。

接著你**直接說出今天想處理的產品議題**即可——教練會先跟你確認議程
（「今天想處理什麼？結束時想帶走什麼？」），而不是預設一套流程。

### 用 Claude Code（終端機）

適合已經在用 CLI／IDE 的人。

```bash
git clone <this-repo> ProductCoachAgent
cd ProductCoachAgent
claude
```

在這個資料夾底下啟動 `claude`，工作目錄就是專案根目錄，`CLAUDE.md` 會被自動
讀取。之後每次要開始 coaching，就在這個資料夾裡開一個新的 `claude` session。
**一次對話 = 一個 session**，結束時可以說「先到這／結束／done」，教練會把這次
的重點寫進 `memory/sessions/` 再收尾。

### 用 Claude Desktop 的 Code 模式（不熟 git 的使用者）

適合沒用過終端機、不想自己 `git clone` 的人。一樣是啟動 Claude Code，只是
把「開資料夾」跟「打指令」都換成在 Desktop app 裡點選。

1. 打開 Claude 桌面版，切到 **Code** 模式（不是一般對話模式）。
2. 選一個本機資料夾當工作目錄（新建一個空資料夾即可），開啟它。
3. 開一個新 session，直接貼上這句話：

   ```
   參考 https://github.com/bobchao/product-coach/blob/main/README.md 的說明，讓我能在 Claude Code 裡使用這個 agent
   ```

4. Claude 會照著這份 README 把需要的檔案準備進這個資料夾。完成後**另開一個
   新 session**，並確認工作目錄還是同一個資料夾，就可以直接開始跟 coach 對話。
5. 之後每次要繼續 coaching，都在同一個資料夾裡開新 session——記憶存在
   `memory/` 裡，跟著資料夾走，不需要再重新設定。

### 用 Claude Cowork（桌面／網頁 app）

適合不想碰終端機的人。在 Claude 桌面版或 claude.ai 的 Cowork 介面裡：

1. 把這個資料夾設為 Cowork 的專案／工作目錄（連結本機資料夾或匯入這個 repo）。
2. 開一個新的 Cowork session，第一句話直接講你想聊的產品議題。
   Cowork 一樣會先讀 `CLAUDE.md → AGENTS.md`，載入 coach 人格與記憶。
3. 之後每次回到同一個資料夾開 session，教練都會記得先前的 context——記憶是
   存在 `memory/` 檔案裡，跟著資料夾走，不綁在特定 app。

> **記憶會寫進檔案。** 以上入口共用同一份 `memory/`，所以 coach 記得的東西
> （你的角色、公司/產品 context、對你思考模式的觀察）在 Claude Code、Desktop
> 與 Cowork 之間是互通的。這些真正的記憶檔預設是 gitignored（避免不小心把個人教練
> 紀錄 commit 進 PR）——只有空白的 `*.md.example` 模板會進版控。如果你確實
> 想把記憶納入版本控制或跟團隊共享，用 `git add -f` 強制加入；想清空重來，
> 刪掉 `memory/` 底下的紀錄檔就好。

## 設計原則

- **人格層（`SOUL.md`）穩定**：定義 coach 是誰，很少變動。
- **環境層（`AGENTS.md`）隨執行環境調整**：目錄結構、記憶機制、boot sequence。
- **設定層（`SKILLS.md`、`memory/`）自由變動**：由 coach 在使用過程中自行維護。

三層各自只放一種內容，其他層用引用而不重複陳述，避免規則分散在多處導致不一致。

詳見 [DESIGN.md](DESIGN.md) 了解完整設計脈絡與決策考量。

## 授權

本 repo 採用 [CC BY-SA 4.0](LICENSE) 授權。
