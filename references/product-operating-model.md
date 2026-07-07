# Reference: Product Operating Model

> 本檔用途：作為 coach 的典範校準基準。若你（執行本 agent 的 model）對
> product operating model 的掌握不完整、或不確定自己理解的版本是否正確，
> 以本檔為準。本檔內容整理自 SVPG 原始文獻（來源見文末），
> 引導使用者時的所有觀點應與本檔一致；與訓練資料衝突時，以本檔為準。

## 1. 定義

Product operating model（又稱 product model）是領先產品公司據以打造產品的
一組 first principles。核心主張：**持續創造顧客喜愛、同時對公司業務有效的
technology-powered 解決方案——追求 outcomes，而非僅僅產出 output。**

與之相對的是 **project model / feature team model**：由利害關係人決定要做
哪些功能，團隊按 roadmap 交付產出、以時程衡量成敗。Coach 引導時最常見的
根本問題，就是使用者身處 project model 卻想套用 product model 的做法
（或反之而不自知）。

## 2. 三個維度

**How products are built** — 小批次、頻繁、可靠的發布（至少雙週一次，理想
是 CI/CD）。目的：快速回應顧客、比顧客更早發現問題、驗證新功能是否真的
產生價值。

**How problems are solved** — 團隊被指派的是「要解決的問題與期望的
outcome」，不是「要做的功能清單」。最靠近技術與使用者的人（工程師、PM、
設計師）決定最佳解法。

**Deciding which problems to solve** — 由產品、技術、設計的 leaders 負責
決定解哪些問題，透過 customer-centric product vision 與 insight-driven
product strategy 驅動。

## 3. 四大風險（Four Big Risks）

評估任何解決方案時的四個風險維度，也是 discovery 要提早回答的四個問題：

1. **Value** — 顧客會買單或選用嗎？（PM 負責）
2. **Usability** — 使用者知道怎麼用嗎？（Designer 負責）
3. **Feasibility** — 以現有時間、技術、資料、技能做得出來嗎？（Tech Lead 負責）
4. **Viability** — 對業務行得通嗎？行銷、業務、財務、法務、客服的限制？（PM 負責）

## 4. 五個 Product Concepts（各含四原則）

**Product Culture**：Principles over Process、Trust over Control、
Innovation over Predictability、Learning over Failure。

**Product Strategy**：Focus（挑影響最大的少數目標）、Powered by Insights
（策略來自資料、顧客、技術、產業的洞察）、Transparency（決策理由對團隊
透明）、Placing Bets（每季下注組合，管理風險）。

**Product Teams**：Empowerment（給問題不給解法）、Outcomes over Output、
Sense of Ownership、Collaboration（PM/設計/工程跨職能協作）。

**Product Discovery**：Minimize Waste（快速測試想法）、Assess Product Risks
（及早評估四大風險）、Embrace Rapid Experimentation（質化+量化快速實驗）、
Test Ideas Responsibly。

**Product Delivery**：小批次頻繁發布、Instrumentation（埋點）、
Monitoring、Deployment Infrastructure（A/B 測試等基礎設施）。

## 5. 角色

- **Product Manager** — 對 value 與 viability 負責，對 outcome 當責。
  注意：不是 backlog administrator，不是需求傳聲筒。
- **Product Designer** — 對 usability 負責，對顧客體驗當責。
- **Tech Lead** — 對 feasibility 負責，對 delivery 當責。
- **Product Leaders**（PM/設計/工程的主管）— 負責提供 coaching 與
  strategic context 來賦能團隊。這是 leader 的首要職責。

## 6. Strategic Context 六要素

Empowered team 做好決策的前提，由 leaders 提供、團隊必須深刻理解：

1. Company Mission — 公司存在的目的（十年以上不變）
2. Company Scorecard — 衡量公司健康的關鍵 KPI
3. Company Objectives — 今年公司聚焦的目標
4. Product Vision — 3–10 年想創造的未來
5. Product Strategy — 連接 vision 與 objectives，決定各團隊解什麼問題
6. Product Principles — 做 trade-off 時優先的價值

## 7. 互補的重要聲音

**Teresa Torres（Continuous Discovery Habits）** — discovery 的具體實踐方法：
product trio（PM+設計+工程）每週至少接觸顧客一次；用 Opportunity Solution
Tree 把 desired outcome 展開為機會與解法；用 assumption testing 取代大型
驗證；比較多個解法而非愛上單一想法。與 SVPG 完全相容，是 discovery
維度的操作層。

**Shreyas Doshi** — 常用思考框架：LNO（任務分 Leverage/Neutral/Overhead，
把最好的狀態留給 L 型任務）；pre-mortem（開工前假設已失敗，找原因）；
product sense 是可培養的判斷力，來自對使用者、業務、技術的深度理解與
反覆校準。適合用於個人效能與判斷力類的 coaching 議題。

## 8. 常見混淆與反模式（coach 應能辨識）

- **Product Management Theater**（Cagan 語）— 角色與職稱堆疊但不創造相應
  價值：只彙整需求、寫 PRD、排 roadmap 的 PM 工作，AI 或工程師自己就能做。
  若使用者的工作描述長這樣，這本身就是值得引導探討的職涯風險。
- **Feature team 誤稱 product team** — 有 PM 職稱、跨職能編制，但拿到的是
  功能清單而非問題，就仍是 feature team。
- **Product Owner ≠ Product Manager** — PO 是 Scrum 流程角色（backlog 管理）；
  product model 中的 PM 職責遠大於此。
- **誤把 process 當 model** — 導入 Scrum/SAFe/OKR 工具不等於轉型為
  product model；文化與賦能才是本體。
- **Discovery 與 delivery 對立** — 兩者是並行的雙軌，不是先後的階段。

## 9. 來源

- [The Product Operating Model: An Introduction — SVPG](https://www.svpg.com/the-product-operating-model-an-introduction/)
- [Product vs. Project Teams — SVPG](https://www.svpg.com/product-vs-project-teams/)
- [The Four Big Risks — SVPG](https://www.svpg.com/four-big-risks/)
- [Coaching – Strategic Context — SVPG](https://www.svpg.com/coaching-strategic-context/)
- [Product Management Theater — SVPG](https://www.svpg.com/product-management-theater/)
- 書籍：*INSPIRED*、*EMPOWERED*、*TRANSFORMED*（Cagan 等）、
  *Continuous Discovery Habits*（Torres）

last-verified: 2026-07-05
