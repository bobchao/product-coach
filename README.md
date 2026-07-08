# Product Coach Agent

一個以 Claude Code 為運行環境的 **Product Coach** agent。它不寫 PRD、不幫你做
決定，而是用提問引導你自己想清楚——立場是 coach，不是 consultant 或 mentor。
它會跨 session 記得你的公司、產品與團隊 context，講過的事不用重講。

## 實際看看

> **你**：老闆說競品都上了 AI 摘要，我們也該做一個。幫我評估該不該做？
>
> **Coach**：在算成本效益之前，先弄清楚一件事就好：你自己的使用者，
> 有出現過「需要摘要」的訊號嗎？
>
> **你**：好像沒有特別聽過……但每家都在做，沒跟上感覺很危險。
>
> **Coach**：我們確定「跟上競品」真的是你們的策略，還是只是走了策略的程序？
> (不急，先想想就好)

幾件值得先知道的事：

- **協助你自己想通，比直接給答案更有力。** 教練預設不給答案，只有在你明顯卡住、
  或明確說「直接告訴我」時才逐級多給一點——而且會明說，說完把決定權還給你。
- **它記得你。** 你的角色、公司/產品 context、每次談過的東西會寫進本機的
  `memory/` 檔案，已經說過的事不會被再問一次。
- **典範一致。** 引導以 product operating model(SVPG/Marty Cagan、
  Teresa Torres、Shreyas Doshi)為準，引用其他流派時標明出處與差異。

## 開始使用

這個 coach 就是這個資料夾本身——一組 Markdown 指示(`SOUL.md`/`AGENTS.md`/
`SKILLS.md`)加上 `memory/`。你要做的只是讓 Claude 以「這個資料夾為工作目錄」
啟動，agent 就會依 boot sequence 進入 coach 人格。(理論上任何支援讀取專案內
`CLAUDE.md`/`AGENTS.md` 這類設定檔的 general-purpose agent 也能套用同樣的
機制，但目前只在 Claude Code 上實測過。)

### 用 Claude(桌面版或終端機)

不需要懂 git 或終端機，用 Claude 桌面版就可以：

1. 打開 Claude 桌面版，切到 **Code** 模式(不是一般對話模式)。
2. 選一個本機資料夾當工作目錄(新建一個空資料夾即可)，開啟它。
3. 開一個新 session，直接貼上這句話：

   ```
   參考 https://github.com/bobchao/product-coach/blob/main/README.md 的說明，讓我能在 Claude Code 裡使用這個 agent
   ```

4. Claude 會照著這份 README 把需要的檔案準備進這個資料夾。完成後**另開一個
   新 session**，並確認工作目錄還是同一個資料夾，就可以開始跟 coach 對話。

> **熟悉終端機的話**，直接 clone 下來啟動即可，效果相同：
>
> ```bash
> git clone https://github.com/bobchao/product-coach.git
> cd product-coach
> claude
> ```

啟動後**直接說出今天想處理的產品議題**——教練會先跟你確認議程(「今天想
處理什麼？結束時想帶走什麼？」)，而不是預設一套流程。**一次對話 = 一個
session**，結束時說「先到這/結束/done」，教練會把這次的重點寫進
`memory/sessions/` 再收尾。之後每次要繼續 coaching，都在同一個資料夾裡開
新 session——記憶跟著資料夾走，不需要重新設定。

### 用 Claude Cowork(桌面/網頁 app)

在 Claude 桌面版或 claude.ai 的 Cowork 介面裡：

1. 把這個資料夾設為 Cowork 的專案/工作目錄(連結本機資料夾或匯入這個 repo)。
2. 開一個新的 Cowork session，第一句話直接講你想聊的產品議題。
3. 之後每次回到同一個資料夾開 session，教練都會記得先前的 context。

> **記憶會寫進檔案。** 以上入口共用同一份 `memory/`，所以 coach 記得的東西
> (你的角色、公司/產品 context、對你思考模式的觀察)在 Claude Code、桌面版
> 與 Cowork 之間是互通的。這些真正的記憶檔預設是 gitignored(避免不小心把
> 個人教練紀錄 commit 進 PR)——只有空白的 `*.md.example` 模板會進版控。
> 如果你確實想把記憶納入版本控制或跟團隊共享，用 `git add -f` 強制加入；
> 想清空重來，刪掉 `memory/` 底下的紀錄檔就好。

## 這是怎麼設計的

想研究或改造這個 agent 的人，從這裡開始。整個設計分三層，各層只放一種內容，
其他層用引用而不重複陳述，避免規則分散導致不一致：

- **人格層(`SOUL.md`)穩定**：定義 coach 是誰，很少變動。
- **環境層(`AGENTS.md`)隨執行環境調整**：目錄結構、記憶機制、boot sequence。
- **設定層(`SKILLS.md`、`memory/`)自由變動**：由 coach 在使用過程中自行維護。

```
├── CLAUDE.md          # 精簡 loader，載入 AGENTS.md
├── AGENTS.md          # 環境與操作說明：boot sequence、目錄配置、記憶機制
├── SOUL.md            # 教練的核心人格與行為準則(憲法，優先權最高)
├── SKILLS.md          # Skill 選用準則 + 已驗證的路由快取
├── DESIGN.md          # 最初的設計文件與決策脈絡
├── references/
│   └── product-operating-model.md   # product operating model 的權威基準版本
├── memory/
│   ├── MEMORY.md.example   # 記憶索引模板(真正的 MEMORY.md 是 gitignored)
│   ├── context/            # 公司、產品、團隊的策略 context 模板
│   ├── user/               # 使用者角色與成長目標檔案模板
│   ├── sessions/           # 逐次 session 紀錄(執行時建立，gitignored)
│   └── insights/           # 教練對使用者思考慣性與成長軌跡的觀察模板
└── evals/
    ├── README.md           # 評測 runbook：怎麼執行與判定
    ├── TEST-PLAN.md        # 測試設計與各組通過標準
    └── run.sh / assert.sh / report.sh   # 執行、程式斷言、成本報表
```

建議的閱讀路徑：

1. [`SOUL.md`](SOUL.md) — 設計的核心：coaching 姿態、講話方式、介入階梯
   (L0–L4：預設純提問，偵測到挫敗訊號才逐級升高介入強度)。
2. [`AGENTS.md`](AGENTS.md) — boot sequence 與三層記憶(semantic 的
   `context/`、episodic 的 `sessions/`、教練觀察的 `insights/`)怎麼建立與更新。
3. [`SKILLS.md`](SKILLS.md) — skill 的選用準則與路由快取，由 coach 自行維護。
4. [`references/product-operating-model.md`](references/product-operating-model.md)
   — 典範基準版本；模型的訓練資料與它衝突時，以它為準。
5. [`evals/`](evals/) — coaching 品質怎麼驗證：程式斷言 + LLM judge + 人工
   抽查三層判定，每組跑 3–5 輪、通過率 ≥ 80% 才算綠。

想看「為什麼這樣設計」，讀 [`DESIGN.md`](DESIGN.md)——最初的設計文件與
決策考量(含 Marty Cagan〈Product Coaching and AI〉的外部驗證)。注意它是
設計初期的快照，之後的演進不一定回頭更新；與上述實際檔案不一致時，以檔案為準。

## 改造成你自己的 coach

三層分層讓改造有明確的入手點：

- **換典範**：改 `SOUL.md` 的 Operating Model 一節，並把 `references/`
  換成你要的典範基準。
- **換領域**：同樣的三層結構可以搬到 PM 以外的 coaching(寫作、工程管理……)
  ——介入階梯、記憶原則、反奉承這些機制與領域無關。
- **改完跑評測**：照 `evals/README.md` 跑一輪，確認 coaching 姿態沒有跑掉；
  測試設計在 `evals/TEST-PLAN.md`，可以照同樣格式加你自己的組別。

歡迎 fork 拿去改。發現問題請開 issue，有改進也歡迎送 PR。

## 授權

本 repo 採用 [CC BY-SA 4.0](LICENSE) 授權。
