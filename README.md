# Product Coach Agent

![The coach opening a session by asking what you want to work on and what you want to walk away with](https://github.com/bobchao/product-coach/releases/download/v0.3.0/product-coach-see-it-in-action.png)

For product people who often find themselves navigating complex situations alone: Product Coach
is your product partner, on call day and night. It asks questions to help you clear your thinking
and find your way out of the fog. Rather than toughing it out alone, or asking an AI for an answer
you have no way to verify, it works from a stable set of product management and dialogue
principles to help you face the problem, surface your blind spots, and find the breakthrough.

- **It remembers you, so you never start from zero.** Across sessions, it remembers your role and
  your company/product context, picking up right where the last conversation left off.
- **The principles are stable, but the toolkit grows with you.** The core approach follows
  well-known product-thinking frameworks — and you can install skills to extend the coach's
  toolkit beyond any single framework.

**Quick start** The coach *is* this folder — point Claude at it as the working directory and it
boots into the coach persona. Fastest path: paste one line into Claude Desktop, or `git clone` the
repo and run `claude`. One conversation = one session; say "done" to close it out, and the coach
writes the key points to memory before signing off. Full setup steps (including memory-sharing
notes) are in [Getting Started](#getting-started) below.

給常獨自在複雜情境裡迷失方向的產品人：Product Coach 是日夜無休的產品夥伴，用提問釐清思緒、
走出迷霧。與其獨自硬扛，或是向 AI 要一個難以驗證的答案，不如借助一套穩定的產品管理與對談原則，
面對問題、找出盲點與破口。

- **記憶會延續，不必每次從零開始。** 跨 session 保留角色、公司/產品脈絡，接續上次沒聊完的話題。
- **原則穩定，但手法會持續擴充。** 核心方法以業界知名的產品思維框架為準，也可透過安裝 skill
  擴充教練能用的手法，不受限於單一框架。

**快速上手** 這個 coach 就是這個資料夾本身，讓 Claude 以此為工作目錄啟動即可。最短路徑：在
Claude 桌面版貼上一句話，或 `git clone` 之後執行 `claude`。一次對話 = 一個 session，結束時說
「done」，教練會把重點寫進記憶再收尾。完整步驟(含記憶共用說明)見下方
[Getting Started](#getting-started)。

## Getting Started

The coach *is* this folder — a set of Markdown instructions (`SOUL.md`/`AGENTS.md`/`SKILLS.md`)
plus `memory/`. All you need to do is point Claude at this folder as its working directory, and
the agent follows the boot sequence into the coach persona. (In principle any general-purpose
agent that reads project-level config files like `CLAUDE.md`/`AGENTS.md` should support the same
mechanism, but so far this has only been tested on Claude Code.)

### Using Claude (Desktop or the terminal)

No git or terminal knowledge required — Claude Desktop works fine:

1. Open Claude Desktop and switch to **Code** mode (not regular chat mode).
2. Pick a local folder as the working directory (a new empty folder is fine) and open it.
3. Start a new session and paste this line:

   ```
   Follow the instructions at https://github.com/bobchao/product-coach/blob/main/README.md to set this agent up for use in Claude Code
   ```

4. Claude will follow this README and set up the files this folder needs. When it's done,
   **start a new session** (keeping the same working directory) to begin talking to the coach.

> **If you're comfortable with the terminal**, just clone and run it directly — same result:
>
> ```bash
> git clone https://github.com/bobchao/product-coach.git
> cd product-coach
> claude
> ```

Once it's running, **just say what product issue you want to work through today** — the coach
opens by confirming the agenda ("What do you want to work on today? What do you want to walk away
with?") rather than assuming a fixed process. **One conversation = one session**; say "that's it
for today" / "let's stop here" / "done" to end it, and the coach writes the key points from this
session into `memory/sessions/` before closing out. To keep coaching, open a new session in the
same folder next time — memory follows the folder, no extra setup needed.

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
