#!/bin/bash
# Skill 獨立運作測試 harness — 驗證一個 skill 抽離本 repo 後能否自力運作。
# 與 skill-compat.sh 的差別：測試副本是「裸環境」——沒有 SOUL.md、AGENTS.md、
# CLAUDE.md、memory/，只有 .claude/skills/<name>/。測的是 skill 的可攜性
# 宣稱：觸發、自帶姿態、journey 直接寫進工作目錄（不依賴宿主記憶機制）。
# 用法：bash evals/skill-standalone.sh <skill-dir> <scenario-file>
# 例：  bash evals/skill-standalone.sh \
#         .claude/skills/pm-growth-coach \
#         evals/fixtures/growth-standalone/basic.txt
# RUN_DIR=... 可自訂輸出目錄（同 run.sh 慣例）。
# （沿用 run.sh 慣例：不用 set -u）
SKILL_DIR=$1
SCENARIO=$2
if [ ! -d "$SKILL_DIR" ] || [ ! -f "$SCENARIO" ]; then
  echo "用法: bash evals/skill-standalone.sh <skill-dir> <scenario-file>"
  echo "  <skill-dir>      要測的 skill 目錄（內含 SKILL.md）"
  echo "  <scenario-file>  情境腳本：一行一個使用者 turn（#開頭與空行忽略）"
  exit 1
fi

BASE="$(cd "$(dirname "$0")/.." && pwd)"
EVAL="$(cd "$(dirname "$0")" && pwd)"
RUN="${RUN_DIR:-$(mktemp -d /tmp/skill-standalone-XXXXXX)}"
FIX=$EVAL/fixtures
LOG=$RUN/run.log
mkdir -p "$RUN"
. "$EVAL/lib.sh"

NAME=$(basename "$SKILL_DIR")
T=standalone
echo "受測 skill: $NAME"
echo "RUN_DIR: $RUN"
log "=== skill-standalone start: $NAME ==="

# 裸環境：不用 setup_dir（那會疊整個 repo），只掛 skill 本身
rm -rf "$RUN/$T"; mkdir -p "$RUN/$T/.claude/skills"
cp -R "$BASE/$SKILL_DIR" "$RUN/$T/.claude/skills/$NAME" 2>/dev/null \
  || cp -R "$SKILL_DIR" "$RUN/$T/.claude/skills/$NAME"

# 逐行跑情境腳本（fd 3：避免 claude -p 吃掉腳本剩餘行）
n=1
while IFS= read -r line <&3 || [ -n "$line" ]; do
  case "$line" in ''|'#'*) continue ;; esac
  echo "turn $n ..."
  run_turn $T $n "$line"
  n=$((n+1))
done 3< "$SCENARIO"
log "=== skill-standalone done: $NAME ==="

# 第一層：程式斷言
fail=0
ck() { if [ "$2" -eq 0 ]; then echo "PASS  $1"; else echo "FAIL  $1"; fail=1; fi }
{
  echo "# Skill 獨立運作測試 — $NAME（$(date '+%Y-%m-%d')）"
  echo
  echo "## 程式斷言"
  grep -ql "authentication_error\|API Error" "$RUN/$T/transcript.md" 2>/dev/null
  ck "無 API/認證錯誤（有 FAIL 先檢查 claude CLI 登入）" $((! $?))
  grep -q "Skill :: .*$NAME" "$RUN/$T/tools.log" 2>/dev/null
  ck "skill 在裸環境有被觸發" $?
  # 可攜性核心斷言：journey 直接寫進工作目錄（skill 不得依賴宿主記憶機制，
  # 也不必先問使用者存哪）。裸環境開場時 .claude/ 之外沒有任何 .md，
  # 所以出現任何含盤點內容的 .md 就是 journey 落地的證據。
  found=$(find "$RUN/$T" -name '*.md' -not -path "*/.claude/*" \
    -exec grep -l "checkpoint\|構面" {} + 2>/dev/null | head -1)
  [ -n "$found" ]
  ck "journey 已寫進工作目錄（${found:-未找到}）" $?
  echo
  echo "## 第二層判定（judge 對 transcript 逐條檢查）"
  echo "- 廣泛意圖（未說「盤點」）即觸發"
  echo "- 姿態自足：一次一問、不代寫計畫、分數不宣判、進框架前徵求同意"
  echo "- 沒有向使用者詢問要存哪（直接存、寫入時告知位置）"
  echo "- 沒有提及任何不存在的宿主機制（SOUL、memory 目錄、索引檔）"
  echo "（transcript: $RUN/$T/transcript.md，工具呼叫: $RUN/$T/tools.log）"
} | tee "$RUN/$T/STANDALONE.md"
exit $fail
