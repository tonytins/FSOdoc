#!/usr/bin/env bash
# Runs every experiment on FreeSO, through fso-oracle, and writes its records: the
# fixtures the NSOOracle tests read (TSO_ORACLE_DIR) and the FreeSO side of oracle-review.sh.
# The records depend on the install, so they stay out of the repository.
#
#   NSOClient/scripts/oracle-fixtures.sh [--mock] [OUTPUT_DIR]     (default: $TMPDIR/fso-oracle-fixtures)
#   TSO_ORACLE_DIR=OUTPUT_DIR swift test --package-path NSOClient/NSOOracle
#
# Reads the install in TSO_GAME_DIR, or with --mock, NSOClient/MockInstall (whose lots are
# NSOClient/MockInstall/Lots). Needs the .NET SDK and python3. Set ORACLE_BUILT=1 to skip
# building fso-oracle. Writes:
#   objects.tsv                   list-objects: what loads for every object
#   objects.digests               run-objects: each object alone for 30 ticks
#   lots.run, lots.digests        the lots with objects, and run-lot on each (lines prefixed with
#                                 its file name)
#   lots.leftout                  the objects fso-oracle left out of each (file name, tab, GUID)
#   PRIMITIVE.requests.jsonl      generated cases for each ported primitive (OracleCases/make_cases.py)
#   PRIMITIVE.responses.jsonl     run-primitive responses to them
#   primitives.lot, primitives.leftout   the lot run-primitive loads, and the objects it left out
#   blueprints/, rooms.lots       synthetic lots (OracleCases/make_blueprints.py), and every lot
#                                 room-maps reads
#   rooms.jsonl                   room-maps for them
#   timings.tsv, *.log            seconds per command, and fso-oracle's messages
set -euo pipefail

repository="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
mock=false
if [[ "${1:-}" == "--mock" ]]; then
    mock=true
    shift
fi
output="${1:-${TMPDIR:-/tmp}/fso-oracle-fixtures}"
if $mock; then
    game="$repository/NSOClient/MockInstall/TSOClient"
    lots=("$repository"/NSOClient/MockInstall/Lots/*.xml)
    primitive_lot="$repository/NSOClient/MockInstall/Lots/mock-lot.xml"
else
    game="${TSO_GAME_DIR:?set TSO_GAME_DIR to your TSO install, or pass --mock}"
    lots=("$repository"/NSOClient/Lots/*.xml)
    primitive_lot="$repository/TSOClient/tso.content/Content/Blueprints/empty_lot_fso.xml"
fi
empty_lot="$repository/TSOClient/tso.content/Content/Blueprints/empty_lot_fso.xml"
# Kept in step with the NSOOracle tests (lotRunsMatchFreeSO).
# A full in-game day (150 ticks a game minute), compared every game hour.
lot_ticks=216000
lot_every=9000
primitives=(expression sleep test_object_type refresh set_to_next random_number play_sound create_object_instance find_location_for run_tree_by_name stackobj_notify_out_of_idle get_distance_to get_direction_to transfer_funds remove_object_instance set_balloon_headline idle_for_input breakpoint special_effect stop_all_sounds get_terrain_info)

mkdir -p "$output"
rm -f "$output/timings.tsv" "$output/lots.digests" "$output/lots.leftout"
oracle() {
    dotnet run --project "$repository/NSOClient/FSO.Oracle" -c Release --no-build -- "$@" --game "$game"
}
# timed NAME COMMAND...: runs COMMAND and records its seconds in timings.tsv.
timed() {
    local name="$1" start end
    shift
    start=$(date +%s.%N)
    "$@"
    end=$(date +%s.%N)
    printf '%s\t%s\n' "$name" "$(awk "BEGIN { printf \"%.1f\", $end - $start }")" >>"$output/timings.tsv"
}
# The objects fso-oracle reported leaving out of a lot, from its messages: one GUID a line.
left_out() {
    grep -o 'object 0x[0-9A-Fa-f]*; left out' "$1" | awk '{ print substr($2, 1, length($2) - 1) }' || true
}

if [[ "${ORACLE_BUILT:-}" != 1 ]]; then
    echo "Building fso-oracle..."
    dotnet build "$repository/NSOClient/FSO.Oracle" -c Release >/dev/null
fi

echo "Listing objects..."
timed list-objects oracle list-objects >"$output/objects.tsv" 2>"$output/objects.log"

echo "Running each object alone (a few minutes)..."
cut -f1 "$output/objects.tsv" >"$output/guids.txt"
timed run-objects oracle run-objects --ticks 30 --every 10 <"$output/guids.txt" >"$output/objects.digests" 2>"$output/objects.digests.log"

echo "Running each lot..."
printf '%s\n' "$empty_lot" "${lots[@]}" >"$output/lots.run"
run_lots() {
    local lot file
    while read -r lot; do
        file="$(basename "$lot")"
        oracle run-lot --blueprint "$lot" --ticks "$lot_ticks" --every "$lot_every" 2>"$output/lot.log" | sed "s|^|$file |"
        cat "$output/lot.log" >>"$output/lots.log"
        left_out "$output/lot.log" | sed "s|^|$file\t|" >>"$output/lots.leftout"
    done <"$output/lots.run"
}
: >"$output/lots.log"
timed run-lot run_lots >"$output/lots.digests"

# The cases name the lot's objects by GUID, in object ID order (1 is the caller, 2 the stack
# object), and its multi-tile masters, so they're read from the lot run-primitive loads.
echo "$primitive_lot" >"$output/primitives.lot"
lot=$(echo '{"opcode":2,"stackObject":2}' | oracle run-primitive --blueprint "$primitive_lot" 2>"$output/primitives.log")
left_out "$output/primitives.log" >"$output/primitives.leftout"
ORACLE_GUIDS=$(echo "$lot" | python3 -I -c 'import json, sys; print(",".join(entry[1] for entry in json.load(sys.stdin)["lot"]))')
ORACLE_MASTERS=$(echo "$lot" | python3 -I -c 'import json, sys; print(",".join(group[1] for group in json.load(sys.stdin)["groups"] if group[1]))')
export ORACLE_GUIDS ORACLE_MASTERS
for primitive in "${primitives[@]}"; do
    echo "Running $primitive cases..."
    python3 -I "$repository/NSOClient/SimAntics/OracleCases/make_cases.py" "$primitive" "$output/$primitive.requests.jsonl"
    timed "run-primitive $primitive" oracle run-primitive --blueprint "$primitive_lot" \
        <"$output/$primitive.requests.jsonl" >"$output/$primitive.responses.jsonl" 2>"$output/$primitive.log"
done

echo "Room maps..."
python3 -I "$repository/NSOClient/SimAntics/OracleCases/make_blueprints.py" "$output/blueprints" >/dev/null
# FreeSO's empty_lot.xml has a DTD, which .NET refuses to read, so only empty_lot_fso.xml joins them.
{ cat "$output/blueprints/blueprints.txt"; echo "$empty_lot"
  ls "$repository"/NSOClient/Lots/*.xml "$repository"/NSOClient/MockInstall/Lots/*.xml; } >"$output/rooms.lots"
timed room-maps oracle room-maps <"$output/rooms.lots" >"$output/rooms.jsonl" 2>"$output/rooms.log"

echo "Done. Compare with: TSO_ORACLE_DIR=$output swift test --package-path NSOClient/NSOOracle"
