#!/usr/bin/env bash
# End-to-end smoke test: both web pages respond, and a vote sent to the vote
# app is processed by the worker and stored in PostgreSQL.
#
# Defaults match `docker compose up`. Override for other environments, e.g.
#   VOTE_URL=http://localhost:31000 \
#   PSQL="kubectl exec deploy/db -- psql -U postgres -tAc" \
#   scripts/smoke-test.sh
set -euo pipefail

VOTE_URL="${VOTE_URL:-http://localhost:8082}"
RESULT_URL="${RESULT_URL:-http://localhost:8081}"
PSQL="${PSQL:-docker compose exec -T db psql -U postgres -tAc}"
TIMEOUT_SECONDS="${TIMEOUT_SECONDS:-60}"

read -r -a psql_cmd <<< "$PSQL"
voter="smoke-$(date +%s)-$RANDOM"

echo "1. vote page responds"
curl -fsS -o /dev/null "$VOTE_URL/"

echo "2. result page responds"
result_page="$(curl -fsS "$RESULT_URL/")"
grep -q "Cats vs Dogs -- Result" <<< "$result_page"

echo "3. cast vote 'a' as $voter"
curl -fsS -o /dev/null -b "voter_id=$voter" -d "vote=a" "$VOTE_URL/"

echo "4. wait up to ${TIMEOUT_SECONDS}s for the worker to store it"
for _ in $(seq 1 "$TIMEOUT_SECONDS"); do
  stored="$("${psql_cmd[@]}" "SELECT vote FROM votes WHERE id = '$voter';" 2>/dev/null || true)"
  if [ "$(echo "$stored" | tr -d '[:space:]')" = "a" ]; then
    echo "PASS: vote stored in PostgreSQL"
    exit 0
  fi
  sleep 1
done

echo "FAIL: vote for $voter not found in PostgreSQL after ${TIMEOUT_SECONDS}s" >&2
exit 1
