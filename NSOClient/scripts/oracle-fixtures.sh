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
#   expression.requests.jsonl     generated Expression cases
#   expression.responses.jsonl    fso-oracle run-primitive answers (SimAntics tests)
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

echo "Running Expression cases..."
python3 -I "$repository/NSOClient/SimAntics/OracleCases/make_expression_cases.py" "$output/expression.requests.jsonl"
oracle run-primitive <"$output/expression.requests.jsonl" >"$output/expression.responses.jsonl" 2>"$output/expression.log"

echo "Done. Run the tests with: TSO_ORACLE_DIR=$output"
