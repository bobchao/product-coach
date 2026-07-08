#!/bin/bash
# 執行報表：模型是否如預期、耗時、花費。
# 純解析 run.sh 已產出的 turn*.jsonl / run.log，不呼叫任何 API，可隨時重跑。
# 用法：
#   bash evals/report.sh <RUN_DIR>                # 單輪
#   bash evals/report.sh <RUN_DIR1> <RUN_DIR2> …  # 多輪加總（例如 3–5 輪求通過率時）
#   EXPECTED_MODEL=haiku bash evals/report.sh <RUN_DIR>   # 覆寫 coach 預期模型（預設 sonnet）
#   SIM_EXPECTED_MODEL=… 覆寫模擬使用者預期模型（預設 haiku；對應 sim*.jsonl，見 README 模型分工）
EXPECTED_MODEL="${EXPECTED_MODEL:-sonnet}"
SIM_EXPECTED_MODEL="${SIM_EXPECTED_MODEL:-haiku}"

[ $# -ge 1 ] || { echo "用法: bash evals/report.sh <RUN_DIR> [<RUN_DIR2> ...]"; exit 1; }

to_sec() { local IFS=:; set -- $1; echo $((10#$1*3600+10#$2*60+10#$3)); }

scan_result_file() { # $1=jsonl $2=預期模型 $3=角色(coach|sim)；累加到全域計數器
  local f=$1 expect=$2 role=$3
  local sess turnname result cost api_ms bad note m m_cost is_trace
  sess=$(basename "$(dirname "$f")")
  turnname=$(basename "$f" .jsonl)

  while IFS= read -r result; do
    [ -z "$result" ] && continue
    if [ "$role" = sim ]; then sim_turns=$((sim_turns+1)); else turns=$((turns+1)); fi

    cost=$(echo "$result" | jq -r '.total_cost_usd // 0')
    api_ms=$(echo "$result" | jq -r '(.duration_api_ms // 0) | floor')
    run_cost=$(awk -v a="$run_cost" -v b="$cost" 'BEGIN{printf "%.6f", a+b}')
    run_api_ms=$((run_api_ms + api_ms))
    [ "$role" = sim ] && sim_cost=$(awk -v a="$sim_cost" -v b="$cost" 'BEGIN{printf "%.6f", a+b}')

    bad=""
    note=""
    while IFS= read -r m; do
      [ -z "$m" ] && continue
      case "$m" in
        *"$expect"*) continue ;;
      esac
      # 已知例外：CLI（2.1.x 實測）會在 session 啟動時用 haiku 做一次微量
      # 內部輔助呼叫（約 $0.001）。成本低於 $0.005 的 haiku 用量列 NOTE
      # 不列 FAIL——真正的模型錯置（fallback、subagent 換模型）成本遠高於此。
      m_cost=$(echo "$result" | jq -r --arg m "$m" '.modelUsage[$m].costUSD // 0')
      is_trace=0
      case "$m" in
        *haiku*) awk -v c="$m_cost" 'BEGIN{exit !(c < 0.005)}' && is_trace=1 ;;
      esac
      if [ "$is_trace" = 1 ]; then note="$note $m(\$$m_cost)"; else bad="$bad $m"; fi
    done < <(echo "$result" | jq -r '.modelUsage // {} | keys[]?')

    [ -n "$note" ] && echo "NOTE  $sess/$turnname: 微量 CLI 輔助呼叫，不計為模型錯置 -$note"
    if [ -n "$bad" ]; then
      echo "FAIL  $sess/$turnname: 出現非預期模型 -$bad（預期含 \"$expect\"）"
      fail=1
      if [ "$role" = sim ]; then sim_bad=$((sim_bad+1)); else bad_turns=$((bad_turns+1)); fi
    fi

    # 依模型列出這個 turn 的花費，跟上面的模型檢查互相印證
    echo "$result" | jq -r --arg sess "$sess" --arg turn "$turnname" \
      '.modelUsage // {} | to_entries[] | "        " + $sess + "/" + $turn + " " + .key + ": $" + (.value.costUSD|tostring)'
  done < <(jq -c 'select(.type=="result")' "$f")
}

fail=0
grand_cost=0
grand_api_ms=0
run_count=0

for R in "$@"; do
  [ -d "$R" ] || { echo "略過（非目錄）: $R"; continue; }
  run_count=$((run_count+1))
  echo "=== $R ==="

  run_cost=0
  run_api_ms=0
  turns=0
  bad_turns=0
  sim_turns=0
  sim_bad=0
  sim_cost=0

  # coach turns（turn*.jsonl）與模擬使用者 turns（sim*.jsonl）各自比對預期模型
  for f in "$R"/*/turn*.jsonl; do
    [ -f "$f" ] || continue
    scan_result_file "$f" "$EXPECTED_MODEL" coach
  done
  for f in "$R"/*/sim*.jsonl; do
    [ -f "$f" ] || continue
    scan_result_file "$f" "$SIM_EXPECTED_MODEL" sim
  done

  ok_turns=$((turns - bad_turns))
  echo "PASS  $R: $ok_turns/$turns turns 符合預期模型（\"$EXPECTED_MODEL\"）"
  if [ "$sim_turns" -gt 0 ]; then
    sim_ok=$((sim_turns - sim_bad))
    echo "PASS  $R: $sim_ok/$sim_turns 模擬使用者 turns 符合預期模型（\"$SIM_EXPECTED_MODEL\"）"
  fi

  # 模擬模式的無效 run（脫稿／未收尾，由 run.sh 標記）——不是 coach FAIL，
  # 但該 run 不計入通過率分母（規則見 TEST-PLAN「模擬模式」）
  for inv in "$R"/*/INVALID; do
    [ -f "$inv" ] || continue
    echo "INVALID  $(basename "$(dirname "$inv")"): $(head -1 "$inv")（不計入通過率分母）"
  done

  if [ -f "$R/run.log" ]; then
    start_ts=$(grep -m1 "eval run start" "$R/run.log" | sed -n 's/^\[\([0-9:]*\)\].*/\1/p')
    end_ts=$(grep -m1 "ALL DONE" "$R/run.log" | sed -n 's/^\[\([0-9:]*\)\].*/\1/p')
    if [ -n "$start_ts" ] && [ -n "$end_ts" ]; then
      wall=$(( $(to_sec "$end_ts") - $(to_sec "$start_ts") ))
      echo "耗時（真實 wall-clock，含平行波）: ${wall} 秒"
    fi
  fi
  echo "耗時（$((turns + sim_turns)) 次呼叫的 API 時間加總）: $((run_api_ms/1000)) 秒"
  [ "$sim_turns" -gt 0 ] && printf "花費（模擬使用者小計）: \$%.4f\n" "$sim_cost"
  printf "花費: \$%.4f\n" "$run_cost"
  echo

  grand_cost=$(awk -v a="$grand_cost" -v b="$run_cost" 'BEGIN{printf "%.6f", a+b}')
  grand_api_ms=$((grand_api_ms + run_api_ms))
done

echo "=== 總計（$run_count 個 RUN_DIR）==="
printf "總花費: \$%.4f\n" "$grand_cost"
echo "總 API 時間: $((grand_api_ms/1000)) 秒"

exit $fail
