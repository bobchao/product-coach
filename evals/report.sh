#!/bin/bash
# 執行報表：模型是否如預期、耗時、花費。
# 純解析 run.sh 已產出的 turn*.jsonl / run.log，不呼叫任何 API，可隨時重跑。
# 用法：
#   bash evals/report.sh <RUN_DIR>                # 單輪
#   bash evals/report.sh <RUN_DIR1> <RUN_DIR2> …  # 多輪加總（例如 3–5 輪求通過率時）
#   EXPECTED_MODEL=haiku bash evals/report.sh <RUN_DIR>   # 覆寫預期模型（預設 sonnet）
EXPECTED_MODEL="${EXPECTED_MODEL:-sonnet}"

[ $# -ge 1 ] || { echo "用法: bash evals/report.sh <RUN_DIR> [<RUN_DIR2> ...]"; exit 1; }

to_sec() { local IFS=:; set -- $1; echo $((10#$1*3600+10#$2*60+10#$3)); }

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

  for f in "$R"/*/turn*.jsonl; do
    [ -f "$f" ] || continue
    sess=$(basename "$(dirname "$f")")
    turnname=$(basename "$f" .jsonl)

    while IFS= read -r result; do
      [ -z "$result" ] && continue
      turns=$((turns+1))

      cost=$(echo "$result" | jq -r '.total_cost_usd // 0')
      api_ms=$(echo "$result" | jq -r '(.duration_api_ms // 0) | floor')
      run_cost=$(awk -v a="$run_cost" -v b="$cost" 'BEGIN{printf "%.6f", a+b}')
      run_api_ms=$((run_api_ms + api_ms))

      bad=""
      while IFS= read -r m; do
        [ -z "$m" ] && continue
        case "$m" in
          *"$EXPECTED_MODEL"*) ;;
          *) bad="$bad $m" ;;
        esac
      done < <(echo "$result" | jq -r '.modelUsage // {} | keys[]?')

      if [ -n "$bad" ]; then
        echo "FAIL  $sess/$turnname: 出現非預期模型 -$bad（預期含 \"$EXPECTED_MODEL\"）"
        fail=1
        bad_turns=$((bad_turns+1))
      fi

      # 依模型列出這個 turn 的花費，跟上面的模型檢查互相印證
      echo "$result" | jq -r --arg sess "$sess" --arg turn "$turnname" \
        '.modelUsage // {} | to_entries[] | "        " + $sess + "/" + $turn + " " + .key + ": $" + (.value.costUSD|tostring)'
    done < <(jq -c 'select(.type=="result")' "$f")
  done

  ok_turns=$((turns - bad_turns))
  echo "PASS  $R: $ok_turns/$turns turns 符合預期模型（\"$EXPECTED_MODEL\"）"

  if [ -f "$R/run.log" ]; then
    start_ts=$(grep -m1 "eval run start" "$R/run.log" | sed -n 's/^\[\([0-9:]*\)\].*/\1/p')
    end_ts=$(grep -m1 "ALL DONE" "$R/run.log" | sed -n 's/^\[\([0-9:]*\)\].*/\1/p')
    if [ -n "$start_ts" ] && [ -n "$end_ts" ]; then
      wall=$(( $(to_sec "$end_ts") - $(to_sec "$start_ts") ))
      echo "耗時（真實 wall-clock，含平行波）: ${wall} 秒"
    fi
  fi
  echo "耗時（$turns 次呼叫的 API 時間加總）: $((run_api_ms/1000)) 秒"
  printf "花費: \$%.4f\n" "$run_cost"
  echo

  grand_cost=$(awk -v a="$grand_cost" -v b="$run_cost" 'BEGIN{printf "%.6f", a+b}')
  grand_api_ms=$((grand_api_ms + run_api_ms))
done

echo "=== 總計（$run_count 個 RUN_DIR）==="
printf "總花費: \$%.4f\n" "$grand_cost"
echo "總 API 時間: $((grand_api_ms/1000)) 秒"

exit $fail
