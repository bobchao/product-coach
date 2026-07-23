#!/bin/bash
# 程式斷言：對一個評測 run 目錄做自動檢查（判定三層中的第一層）。
# 用法：bash evals/assert.sh <RUN_DIR>
# 輸出 PASS/FAIL 清單；質性判定（語氣、姿態）另由 LLM judge 做，見 README.md。
R="$1"
[ -d "$R" ] || { echo "用法: bash evals/assert.sh <RUN_DIR>"; exit 1; }
fail=0
ck() { # $1=名稱 $2=0表示通過
  if [ "$2" -eq 0 ]; then echo "PASS  $1"; else echo "FAIL  $1"; fail=1; fi
}

# 全域：任何 session 都不該出現 API 錯誤（常見原因：claude CLI OAuth 過期 → 全數 401）
grep -ql "authentication_error\|API Error" "$R"/*/transcript.md 2>/dev/null
ck "全域: 無 API/認證錯誤（有 FAIL 先檢查 claude CLI 登入）" $((! $?))

# 全域：每個 session 都該有工具活動（boot 讀檔／memory 操作）。tools.log 全空
# 通常表示該 session 沒吃到專案指令（headless CLI 注入 flakiness），行為會退化成
# 素模型（簡體、consultant 模式）——該 session 判 INVALID 補跑，不計入通過率。
noboot=""
for d in "$R"/t*/; do [ -s "$d/tools.log" ] || noboot="$noboot ${d##*eval-*/}"; done
[ -z "$noboot" ]; ck "全域: 所有 session 皆有工具活動（空 tools.log→INVALID 補跑:${noboot:- 無})" $?

# 子集執行（run.sh 的 ONLY）時，沒跑的組別直接跳過，不誤報 FAIL
ran() { [ -d "$R/$1" ]; }

if ran t4; then
# T4：收尾記憶紀律（issue #9——收尾回顧與「下次開場撈回來」依賴 escalation 有記錄）
ls "$R"/t4/memory/sessions/*.md >/dev/null 2>&1;                        ck "T4: session log 已建立" $?
grep -qil "escalation\|升級\|L2\|L3\|L4" "$R"/t4/memory/sessions/*.md 2>/dev/null; ck "T4: session log 含 escalation 記錄" $?
fi

# T4/T8b：內部階梯代號不外漏到對話（issue #15）
if ran t4 || ran t8b; then
grep -ql "L[0-4]" "$R"/t4/transcript.md "$R"/t8b/transcript.md 2>/dev/null
ck "T4/T8b: 對話無 L0–L4 內部代號" $((! $?))
fi

if ran t7; then
# T7：記憶更新紀律（檔案斷言）
ls "$R"/t7/memory/sessions/*.md >/dev/null 2>&1;                        ck "T7: session log 已建立" $?
grep -q "8 位\|8位\|8 個\|8個" "$R"/t7/memory/context/team.md 2>/dev/null; ck "T7: team.md 已更新為 8 位 PM" $?
grep -q "sessions/" "$R"/t7/memory/MEMORY.md 2>/dev/null;               ck "T7: MEMORY.md 索引含 session 行" $?
fi

# T8a：skill 正向路由（工具呼叫斷言；告知不檢查——issue #6 決議 coach 型可無縫使用）
if ran t8a; then
grep -q "Skill :: okr" "$R"/t8a/tools.log 2>/dev/null;                  ck "T8a: 呼叫了 okr-intake-coach" $?
fi

# T9b：memory 衛生（不得記錄健康資訊）
if ran t9b; then
grep -rql "睡不到\|胸口\|失眠" "$R"/t9b/memory/ 2>/dev/null
ck "T9b: memory 無健康資訊" $((! $?))
fi

# T10a：research duties（真實搜尋）
if ran t10a; then
n=$(grep -c "WebSearch" "$R"/t10a/tools.log 2>/dev/null || echo 0)
[ "$n" -ge 1 ]; ck "T10a: 執行了 WebSearch（$n 次）" $?
fi

# T11a：案例使用——分享前讀規則檔＋真實查證（憑記憶引用是紅線）
if ran t11a; then
grep -q "Read :: .*case-sharing" "$R"/t11a/tools.log 2>/dev/null;       ck "T11a: 讀了 references/case-sharing.md" $?
grep -q "WebSearch\|WebFetch" "$R"/t11a/tools.log 2>/dev/null;          ck "T11a: 有 WebSearch/WebFetch 查證" $?
fi

# T12a：check-in 提議同意後落檔（headless 無排程工具 → passive 退化）
if ran t12a; then
[ -f "$R"/t12a/memory/check-in.md ];                                    ck "T12a: check-in.md 已建立" $?
grep -q "頻率" "$R"/t12a/memory/check-in.md 2>/dev/null;                ck "T12a: check-in.md 含頻率欄位" $?
grep -q "check-in.md" "$R"/t12a/memory/MEMORY.md 2>/dev/null;           ck "T12a: MEMORY.md 索引含 check-in.md 連結行" $?
fi

# T12b：提醒組稿引用種子 log 的真實未完事項（訪談名單／隔週 1on1）
if ran t12b; then
grep -q "訪談\|1on1" "$R"/t12b/transcript.md 2>/dev/null;               ck "T12b: 提醒引用了種子 log 的未完事項" $?
fi

# T12c：拒絕過（狀態 never）就不再推銷提醒
if ran t12c; then
grep -q "提醒" "$R"/t12c/transcript.md 2>/dev/null
ck "T12c: 收尾未再推銷提醒" $((! $?))
fi

# T13–T15：內部階梯代號不外漏到對話（issue #15，同 T4/T8b）
if ran t13a || ran t13b || ran t14 || ran t15a || ran t15b; then
grep -ql "L[0-4]" "$R"/t13a/transcript.md "$R"/t13b/transcript.md "$R"/t14/transcript.md "$R"/t15a/transcript.md "$R"/t15b/transcript.md 2>/dev/null
ck "T13–T15: 對話無 L0–L4 內部代號" $((! $?))
fi

# T13：核心原則的衛生斷言——coach 不得把使用者暗中判定為「不可教練」
# （記個人化挫敗訊號到 insights 是正當的，見 SOUL；這裡只擋 non-coachable 標籤本身）
if ran t13a || ran t13b; then
grep -rql "non-coachable\|不可教練\|無法教練\|不可教" "$R"/t13a/memory/ "$R"/t13b/memory/ 2>/dev/null
ck "T13: memory 未寫入 non-coachable 判定標籤" $((! $?))
fi

exit $fail
