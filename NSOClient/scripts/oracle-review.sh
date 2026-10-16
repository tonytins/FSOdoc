#!/usr/bin/env bash
# Runs fso-oracle (FreeSO) and nso-oracle (NSOClient) side by side on each install, compares their
# answers, and with --review writes docs/results/nso-review.md. Run it after a phase or milestone,
# not every session: it reruns every object on every install.
#
#   NSOClient/scripts/oracle-review.sh [--review] [OUTPUT_DIR]     (default: $TMPDIR/oracle-review)
#
# Installs come from TSO_GAME_DIR ("production") and TSO_BETA_DIR ("beta"); either or both.
# Needs the .NET SDK, Swift, and python3. Each install gets OUTPUT_DIR/NAME/{fso,nso}/ with
# objects.tsv, objects.digests, rooms.jsonl, and timings.tsv.
set -euo pipefail

repository="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
review=false
if [[ "${1:-}" == "--review" ]]; then
    review=true
    shift
fi
output="${1:-${TMPDIR:-/tmp}/oracle-review}"

installs=()
[[ -n "${TSO_GAME_DIR:-}" ]] && installs+=("production=$TSO_GAME_DIR")
[[ -n "${TSO_BETA_DIR:-}" ]] && installs+=("beta=$TSO_BETA_DIR")
if (( ${#installs[@]} == 0 )); then
    echo "oracle-review: set TSO_GAME_DIR, TSO_BETA_DIR, or both" >&2
    exit 2
fi

echo "Building both oracles..."
dotnet build "$repository/NSOClient/Oracle" -c Release >/dev/null
swift build --package-path "$repository/NSOClient/NSOOracle" -c release >/dev/null
nso_binary="$(swift build --package-path "$repository/NSOClient/NSOOracle" -c release --show-bin-path)/nso-oracle"

mkdir -p "$output"
echo "Writing the synthetic lots..."
python3 -I "$repository/NSOClient/SimAntics/OracleCases/make_blueprints.py" "$output/blueprints" >/dev/null
{ cat "$output/blueprints/blueprints.txt"
  echo "$repository/TSOClient/tso.content/Content/Blueprints/empty_lot_fso.xml"
  ls "$repository"/NSOClient/Lots/*.xml; } >"$output/lots.txt"

# timed SIDE NAME OUTPUT COMMAND...: runs COMMAND with standard output to OUTPUT, and records its seconds.
timed() {
    local side="$1" name="$2" file="$3"
    shift 3
    local start end
    start=$(date +%s.%N)
    "$@" >"$file" 2>>"$(dirname "$file")/log.txt"
    end=$(date +%s.%N)
    printf '%s\t%s\n' "$name" "$(awk "BEGIN { printf \"%.1f\", $end - $start }")" >>"$(dirname "$file")/timings.tsv"
}

for install in "${installs[@]}"; do
    name="${install%%=*}"
    game="${install#*=}"
    folder="$output/$name"
    mkdir -p "$folder/fso" "$folder/nso"
    rm -f "$folder/fso/timings.tsv" "$folder/nso/timings.tsv" "$folder/fso/log.txt" "$folder/nso/log.txt"
    fso() { dotnet run --project "$repository/NSOClient/Oracle" -c Release --no-build -- "$@" --game "$game"; }
    nso() { "$nso_binary" "$1" --game "$game" "${@:2}"; }

    echo "[$name] Listing objects..."
    timed fso list-objects "$folder/fso/objects.tsv" fso list-objects
    timed nso list-objects "$folder/nso/objects.tsv" nso list-objects
    echo "[$name] Running each object alone (a few minutes per side)..."
    cut -f1 "$folder/fso/objects.tsv" >"$folder/guids.txt"
    timed fso run-objects "$folder/fso/objects.digests" fso run-objects --ticks 30 --every 10 <"$folder/guids.txt"
    timed nso run-objects "$folder/nso/objects.digests" nso run-objects --ticks 30 --every 10 <"$folder/guids.txt"
    echo "[$name] Room maps..."
    timed fso room-maps "$folder/fso/rooms.jsonl" fso room-maps <"$output/lots.txt"
    timed nso room-maps "$folder/nso/rooms.jsonl" "$nso_binary" room-maps <"$output/lots.txt"

    arguments=(compare --fso "$folder/fso" --nso "$folder/nso" --install "$name")
    if $review; then
        arguments+=(--review "$repository/docs/results/nso-review.md"
                    --commit "$(git -C "$repository" rev-parse --short HEAD)")
    fi
    "$nso_binary" "${arguments[@]}"
done
