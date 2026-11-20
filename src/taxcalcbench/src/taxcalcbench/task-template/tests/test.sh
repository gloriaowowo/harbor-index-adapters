#!/bin/bash
# Score /app/output/return.txt against the expected return with the upstream
# TaxCalcBench rules (tests/score.py). Reward = 1 for a strictly correct return
# (every scored line exact), else 0. Per-line results go to
# /logs/verifier/score.json.
mkdir -p /logs/verifier
rm -f /logs/verifier/reward.txt /logs/verifier/score.json

/usr/local/bin/python3 /tests/score.py \
  --output /app/output/return.txt \
  --expected /tests/expected.xml \
  --fields /tests/scored_fields.json \
  --report /logs/verifier/score.json \
  --reward /logs/verifier/reward.txt

test -f /logs/verifier/reward.txt || echo 0 > /logs/verifier/reward.txt
exit 0
