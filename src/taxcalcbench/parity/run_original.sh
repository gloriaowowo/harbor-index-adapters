#!/bin/bash
# Original-side parity run: unmodified upstream TaxCalcBench at the pinned
# commit, one run over the parity cases.
#
# Upstream's CLI writes outputs into its own results/ tree (where the
# leaderboard's saved outputs live), so use a separate, throwaway checkout of
# the pinned commit. Each run's files are moved to $OUT_DIR/run_<N>/<task_id>/.
#
#   export OPENAI_API_KEY=...            # parity key
#   export OPENAI_BASE_URL=https://app.ppapi.ai/v1  OPENAI_API_BASE=$OPENAI_BASE_URL
#   TAXCALCBENCH_ROOT=/path/to/clean/checkout RUN=1 OUT_DIR=parity_runs/original \
#     [CASES_FILE=parity/parity_cases.txt] [LIMIT=5] ./parity/run_original.sh
set -euo pipefail
: "${TAXCALCBENCH_ROOT:?set TAXCALCBENCH_ROOT to a clean checkout of the pinned commit}"
: "${OPENAI_API_KEY:?}"
: "${RUN:?set RUN to the run number (1, 2, 3)}"
: "${OUT_DIR:?}"
MODEL=${MODEL:-gpt-6.2-sol}
LEVEL=${THINKING_LEVEL:-high}
CASES_FILE=$(cd "$(dirname "${CASES_FILE:-$(dirname "$0")/parity_cases.txt}")" && pwd)/$(basename "${CASES_FILE:-parity_cases.txt}")
OUT_DIR=$(mkdir -p "$OUT_DIR" && cd "$OUT_DIR" && pwd)
LIMIT=${LIMIT:-0}

cd "$TAXCALCBENCH_ROOT"
echo "upstream commit: $(git rev-parse HEAD)" | tee "$OUT_DIR/run_${RUN}.meta"
echo "model: openai/$MODEL  thinking level: $LEVEL" | tee -a "$OUT_DIR/run_${RUN}.meta"

n=0
grep -v '^#' "$CASES_FILE" | while read -r task_id year case_name; do
  [ -z "$task_id" ] && continue
  n=$((n + 1))
  if [ "$LIMIT" -gt 0 ] && [ "$n" -gt "$LIMIT" ]; then break; fi
  results="tax_calc_bench/$year/results/$case_name/openai/$MODEL"
  # Start from an empty output folder so nothing saved earlier is reused.
  rm -f "$results"/*"_${LEVEL}_1.md"
  uv run python -m tax_calc_bench.main --provider openai --model "$MODEL" \
    --thinking-level "$LEVEL" --tax-year "$year" --test-name "$case_name" \
    --save-outputs --num-runs 1 || echo "generation failed: $task_id"
  dest="$OUT_DIR/run_${RUN}/$task_id"
  mkdir -p "$dest"
  mv "$results"/*"_${LEVEL}_1.md" "$dest/" 2>/dev/null || echo "no output saved: $task_id"
done
