#!/usr/bin/env bash
# Generates the 2017 reference answers the Swift tests compare against, from your install.
# The answers depend on the install, so they stay out of the repository.
#
#   NSOClient/scripts/oracle-fixtures.sh [OUTPUT_DIR]     (default: $TMPDIR/fso-oracle-fixtures)
#   TSO_ORACLE_DIR=OUTPUT_DIR swift test --package-path NSOClient/SimAntics
#
# Needs TSO_GAME_DIR, the .NET SDK, and python3. Writes:
#   objects.tsv                   fso-oracle list-objects (TSOContent and SimAntics tests)
#   objects.digests               fso-oracle run-objects: each object alone for 30 ticks (SimAntics tests)
#   PRIMITIVE.requests.jsonl      generated cases for each ported primitive (expression, sleep, test_object_type, refresh, set_to_next)
#   PRIMITIVE.responses.jsonl     fso-oracle run-primitive answers (SimAntics tests)
set -euo pipefail

repository="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
output="${1:-${TMPDIR:-/tmp}/fso-oracle-fixtures}"
: "${TSO_GAME_DIR:?set TSO_GAME_DIR to your TSO install}"

mkdir -p "$output"
oracle() {
    dotnet run --project "$repository/NSOClient/Oracle" -c Release --no-build -- "$@"
}

echo "Building the oracle..."
dotnet build "$repository/NSOClient/Oracle" -c Release >/dev/null

echo "Listing objects..."
oracle list-objects >"$output/objects.tsv" 2>"$output/objects.log"

echo "Running each object alone (a few minutes)..."
cut -f1 "$output/objects.tsv" | oracle run-objects --ticks 30 --every 10 >"$output/objects.digests" 2>"$output/objects.digests.log"

# Generators that name real objects need the GUIDs of the lot's objects 1 and 2.
ORACLE_GUIDS=$(echo '{"opcode":2,"stackObject":2}' | oracle run-primitive 2>/dev/null |
    python3 -I -c 'import json, sys; r = json.load(sys.stdin); print(r["callerGUID"] + "," + r["stackObjectGUID"])')
export ORACLE_GUIDS

for primitive in expression sleep test_object_type refresh set_to_next; do
    echo "Running $primitive cases..."
    python3 -I "$repository/NSOClient/SimAntics/OracleCases/make_${primitive}_cases.py" "$output/$primitive.requests.jsonl"
    oracle run-primitive <"$output/$primitive.requests.jsonl" >"$output/$primitive.responses.jsonl" 2>"$output/$primitive.log"
done

echo "Done. Run the tests with: TSO_ORACLE_DIR=$output"
