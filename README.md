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
- **想要的話，它會定期回來找你。** 這是 opt-in 的：累積幾次對話後教練會
  問一次要不要定期回顧提醒(每週或每兩週)，同意才會建立。提醒從上次沒聊完
  的事接起，一則就好，不理會也不會追發；說「不要再提醒」隨時關掉。
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
>
> **為避免 Cowork 忽略設定檔，建議在 Claude 的 Settings > Cowork > Global instruction 處加上：**
>
> ```
> When starting a session, read the CLAUDE.md file in the project root and follow the instructions there.
> ```

## How This Is Designed

Start here if you want to study or adapt this agent. The design has three layers, each holding
exactly one kind of content — other layers reference it instead of repeating it, so the rules
don't drift out of sync:

- **Personality layer (`SOUL.md`) is stable**: defines who the coach is; rarely changes.
- **Environment layer (`AGENTS.md`) adapts to the runtime**: directory layout, memory mechanics,
  boot sequence.
- **Configuration layer (`SKILLS.md`, `memory/`) changes freely**: maintained by the coach itself
  during use.

```
├── CLAUDE.md          # Thin loader that pulls in AGENTS.md
├── AGENTS.md          # Environment & operating instructions: boot sequence, directory layout, memory mechanics
├── SOUL.md            # The coach's core personality and behavioral rules (the constitution — highest priority)
├── SKILLS.md          # Skill selection guidelines + a validated routing cache
├── DESIGN.md          # Original design doc and the reasoning behind it
├── references/
│   └── product-operating-model.md   # Authoritative baseline for the product operating model
├── memory/
│   ├── MEMORY.md.example   # Memory index template (the real MEMORY.md is gitignored)
│   ├── context/            # Templates for company/product/team strategic context
│   ├── user/               # Templates for the user's role and growth goals
│   ├── sessions/           # Per-session logs (created at runtime, gitignored)
│   └── insights/           # Templates for the coach's observations on the user's thinking patterns and growth trajectory
└── evals/
    ├── README.md           # Eval runbook: how to run it and how to judge results
    ├── TEST-PLAN.md        # Test design and pass criteria per suite
    └── run.sh / assert.sh / report.sh   # Execution, programmatic assertions, cost report
```

Suggested reading order:

1. [`SOUL.md`](SOUL.md) — the heart of the design: coaching stance, tone of voice, the
   intervention ladder (L0–L4: pure questions by default, escalating intervention only when
   frustration signals show up).
2. [`AGENTS.md`](AGENTS.md) — the boot sequence and the three-layer memory system (semantic
   `context/`, episodic `sessions/`, the coach's own `insights/`) — how each is created and updated.
3. [`SKILLS.md`](SKILLS.md) — skill selection guidelines and the routing cache, maintained by the
   coach itself.
4. [`references/product-operating-model.md`](references/product-operating-model.md)
   — the paradigm's baseline reference; when the model's training data conflicts with it, this
   file wins.
5. [`evals/`](evals/) — how coaching quality gets verified: programmatic assertions + LLM judge +
   manual spot-checks across three tiers, 3–5 runs per suite, ≥80% pass rate to go green.

To see *why* it's designed this way, read [`DESIGN.md`](DESIGN.md) — the original design doc and
the reasoning behind it (including external validation from Marty Cagan's *Product Coaching and
AI*). Note that it's a snapshot from early design and isn't necessarily updated as the project
evolves — where it conflicts with the files above, the files win.

## Adapting It Into Your Own Coach

The three-layer split gives you clear places to start adapting:

- **Swap the paradigm**: edit the Operating Model section in `SOUL.md`, and replace `references/`
  with your own paradigm's baseline.
- **Swap the domain**: the same three-layer structure can move to coaching outside PM (writing,
  engineering management...) — the intervention ladder, memory principles, and anti-sycophancy
  mechanisms are domain-agnostic.
- **Run the evals after changes**: run through `evals/README.md` to confirm the coaching stance
  hasn't drifted; test design lives in `evals/TEST-PLAN.md` — add your own suites in the same
  format.

Forks welcome. Open an issue if you find a problem, and PRs are welcome too.

## License

This repo is licensed under [CC BY-SA 4.0](LICENSE).
