#!/bin/bash
# Skill 相容性測試 harness — 判定一個候選 skill 適不適合與 coach 搭配使用。
# 用法：bash evals/skill-compat.sh <skill-dir> <scenario-file>
# 例：  bash evals/skill-compat.sh \
#         evals/fixtures/t8a-skills/.claude/skills/okr-intake-coach \
#         evals/fixtures/skill-compat/okr-intake.txt
# RUN_DIR=... 可自訂輸出目錄（同 run.sh 慣例）。
# 完整流程（靜態分類、場景設計、judge rubric）見 SKILL-COMPAT.md；
# 本檔只做執行＋第一層程式斷言，質性判定由 judge 照 rubric 對 transcript 做。
# （沿用 run.sh 慣例：不用 set -u）
SKILL_DIR=$1
SCENARIO=$2
if [ ! -d "$SKILL_DIR" ] || [ ! -f "$SCENARIO" ]; then
  echo "用法: bash evals/skill-compat.sh <skill-dir> <scenario-file>"
  echo "  <skill-dir>      候選 skill 目錄（內含 SKILL.md）"
  echo "  <scenario-file>  情境腳本：一行一個使用者 turn（#開頭與空行忽略）"
  exit 1
fi

BASE="$(cd "$(dirname "$0")/.." && pwd)"
EVAL="$(cd "$(dirname "$0")" && pwd)"
RUN="${RUN_DIR:-$(mktemp -d /tmp/skill-compat-XXXXXX)}"
FIX=$EVAL/fixtures
LOG=$RUN/run.log
mkdir -p "$RUN"
. "$EVAL/lib.sh"

NAME=$(basename "$SKILL_DIR")
T=compat
echo "候選 skill: $NAME"
echo "RUN_DIR: $RUN"
log "=== skill-compat start: $NAME ==="

# 乾淨副本＋user-seed（避免 onboarding 干擾），再把候選 skill 掛進副本
setup_dir $T user-seed
mkdir -p "$RUN/$T/.claude/skills"
cp -R "$SKILL_DIR" "$RUN/$T/.claude/skills/$NAME"

# 逐行跑情境腳本（fd 3：避免 claude -p 吃掉腳本剩餘行）
n=1
while IFS= read -r line <&3 || [ -n "$line" ]; do
  case "$line" in ''|'#'*) continue ;; esac
  echo "turn $n ..."
  run_turn $T $n "$line"
  n=$((n+1))
done 3< "$SCENARIO"
log "=== skill-compat done: $NAME ==="

# 第一層：程式斷言
fail=0
ck() { if [ "$2" -eq 0 ]; then echo "PASS  $1"; else echo "FAIL  $1"; fail=1; fi }
{
  echo "# Skill 相容性測試 — $NAME（$(date '+%Y-%m-%d')）"
  echo
  echo "## 程式斷言"
  grep -ql "authentication_error\|API Error" "$RUN/$T/transcript.md" 2>/dev/null
  ck "無 API/認證錯誤（有 FAIL 先檢查 claude CLI 登入）" $((! $?))
  grep -q "Skill :: .*$NAME" "$RUN/$T/tools.log" 2>/dev/null
  ck "候選 skill 有被呼叫（沒觸發 = 不必進 rubric 判定）" $?
  echo
  echo "## 第二層判定"
  echo "請照 evals/SKILL-COMPAT.md 的 rubric 對 transcript.md 逐條判定"
  echo "（transcript: $RUN/$T/transcript.md，工具呼叫: $RUN/$T/tools.log）"
} | tee "$RUN/$T/COMPAT.md"
exit $fail
