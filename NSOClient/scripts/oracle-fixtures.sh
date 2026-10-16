#!/usr/bin/env bash
# Generates FreeSO's reference answers the Swift tests compare against, from your install.
# The answers depend on the install, so they stay out of the repository.
#
#   NSOClient/scripts/oracle-fixtures.sh [OUTPUT_DIR]     (default: $TMPDIR/fso-oracle-fixtures)
#   TSO_ORACLE_DIR=OUTPUT_DIR swift test --package-path NSOClient/SimAntics
#
# Needs TSO_GAME_DIR, the .NET SDK, and python3. Writes:
#   objects.tsv                   fso-oracle list-objects (TSOContent and SimAntics tests)
#   objects.digests               fso-oracle run-objects: each object alone for 30 ticks (SimAntics tests)
#   PRIMITIVE.requests.jsonl      generated cases for each ported primitive (see OracleCases/make_cases.py)
#   PRIMITIVE.responses.jsonl     fso-oracle run-primitive answers (SimAntics tests)
#   blueprints/                   synthetic lots (see OracleCases/make_blueprints.py)
#   rooms.jsonl                   fso-oracle room-maps for them, FreeSO's empty lot, and NSOClient/Lots (SimAntics tests)
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
# Generators that name real objects need the GUIDs of the lot's objects, in object ID order (1 is
# the caller, 2 the stack object), and of its multi-tile masters.
lot=$(echo '{"opcode":2,"stackObject":2}' | oracle run-primitive 2>/dev/null)
ORACLE_GUIDS=$(echo "$lot" | python3 -I -c 'import json, sys; print(",".join(entry[1] for entry in json.load(sys.stdin)["lot"]))')
ORACLE_MASTERS=$(echo "$lot" | python3 -I -c 'import json, sys; print(",".join(group[1] for group in json.load(sys.stdin)["groups"] if group[1]))')
export ORACLE_GUIDS ORACLE_MASTERS

for primitive in expression sleep test_object_type refresh set_to_next random_number play_sound create_object_instance find_location_for; do
    echo "Running $primitive cases..."
    python3 -I "$repository/NSOClient/SimAntics/OracleCases/make_cases.py" "$primitive" "$output/$primitive.requests.jsonl"
    oracle run-primitive <"$output/$primitive.requests.jsonl" >"$output/$primitive.responses.jsonl" 2>"$output/$primitive.log"
done

echo "Generating rooms..."
python3 -I "$repository/NSOClient/SimAntics/OracleCases/make_blueprints.py" "$output/blueprints"
# FreeSO's empty_lot.xml has a DTD, which .NET refuses to read, so only empty_lot_fso.xml joins them,
# with the owner's lots in NSOClient/Lots.
{ cat "$output/blueprints/blueprints.txt"; echo "$repository/TSOClient/tso.content/Content/Blueprints/empty_lot_fso.xml"
  ls "$repository"/NSOClient/Lots/*.xml; } |
    oracle room-maps >"$output/rooms.jsonl" 2>"$output/rooms.log"

echo "Done. Run the tests with: TSO_ORACLE_DIR=$output"
