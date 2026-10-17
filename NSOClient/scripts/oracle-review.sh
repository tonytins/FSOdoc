#!/usr/bin/env bash
# Runs fso-oracle (FreeSO) and nso-oracle (NSOClient) side by side on each install, compares their
# answers, and with --review writes docs/results/nso-review.md. Run it after a phase or milestone,
# not every session: it reruns every object on every install.
#
#   NSOClient/scripts/oracle-review.sh [--review | --mock] [OUTPUT_DIR]     (default: $TMPDIR/oracle-review)
#
# Installs come from TSO_GAME_DIR ("production") and TSO_BETA_DIR ("beta"); either or both.
# --mock runs on NSOClient/MockInstall ("mock") alone, as CI does; it never writes the review.
# Needs the .NET SDK, Swift, and python3. Each install gets OUTPUT_DIR/NAME/{fso,nso}/ with
# objects.tsv, objects.digests, lots.digests (run-lot on each lot with objects, lines prefixed with
# the lot's file name), rooms.jsonl, and timings.tsv, plus fso/lots.leftout (the objects fso-oracle
# left out of each lot, which nso-oracle leaves out too). OUTPUT_DIR/NAME/fso also works as
# TSO_ORACLE_DIR for `swift test --package-path NSOClient/NSOOracle`.
set -euo pipefail

repository="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
review=false
mock=false
case "${1:-}" in
    --review) review=true; shift ;;
    --mock) mock=true; shift ;;
esac
output="${1:-${TMPDIR:-/tmp}/oracle-review}"

installs=()
if $mock; then
    installs+=("mock=$repository/NSOClient/MockInstall/TSOClient")
else
    [[ -n "${TSO_GAME_DIR:-}" ]] && installs+=("production=$TSO_GAME_DIR")
    [[ -n "${TSO_BETA_DIR:-}" ]] && installs+=("beta=$TSO_BETA_DIR")
fi
if (( ${#installs[@]} == 0 )); then
    echo "oracle-review: set TSO_GAME_DIR, TSO_BETA_DIR, or both, or pass --mock" >&2
    exit 2
fi

echo "Building both oracles..."
dotnet build "$repository/NSOClient/Oracle" -c Release >/dev/null
swift build --package-path "$repository/NSOClient/NSOOracle" -c release >/dev/null
nso_binary="$(swift build --package-path "$repository/NSOClient/NSOOracle" -c release --show-bin-path)/nso-oracle"

mkdir -p "$output"
echo "Writing the synthetic lots..."
python3 -I "$repository/NSOClient/SimAntics/OracleCases/make_blueprints.py" "$output/blueprints" >/dev/null
# Lots with objects, for run-lot: FreeSO's empty lot (its objects are the lot's mailbox and the
# like), then the house in NSOClient/Lots, or on the mock install, the mock lots.
{ echo "$repository/TSOClient/tso.content/Content/Blueprints/empty_lot_fso.xml"
  if $mock; then ls "$repository"/NSOClient/MockInstall/Lots/*.xml; else ls "$repository"/NSOClient/Lots/*.xml; fi
} >"$output/lots-run.txt"
{ cat "$output/blueprints/blueprints.txt"
  echo "$repository/TSOClient/tso.content/Content/Blueprints/empty_lot_fso.xml"
  ls "$repository"/NSOClient/Lots/*.xml "$repository"/NSOClient/MockInstall/Lots/*.xml; } >"$output/lots.txt"
# Kept in step with the run-lot test in NSOClient/NSOOracle (lotRunsMatchFreeSO).
lot_ticks=1800
lot_every=300

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
    # Each side's folder is then a TSO_ORACLE_DIR for the NSOOracle fixture tests.
    ln -sfn "$output/blueprints" "$folder/fso/blueprints"
    rm -f "$folder/fso/timings.tsv" "$folder/nso/timings.tsv" "$folder/fso/log.txt" "$folder/nso/log.txt" \
        "$folder/fso/lots.digests" "$folder/nso/lots.digests" "$folder/fso/lots.leftout"
    fso() { dotnet run --project "$repository/NSOClient/Oracle" -c Release --no-build -- "$@" --game "$game"; }
    nso() { "$nso_binary" "$1" --game "$game" "${@:2}"; }

    echo "[$name] Listing objects..."
    timed fso list-objects "$folder/fso/objects.tsv" fso list-objects
    timed nso list-objects "$folder/nso/objects.tsv" nso list-objects
    echo "[$name] Running each object alone (a few minutes per side)..."
    cut -f1 "$folder/fso/objects.tsv" >"$folder/guids.txt"
    timed fso run-objects "$folder/fso/objects.digests" fso run-objects --ticks 30 --every 10 <"$folder/guids.txt"
    timed nso run-objects "$folder/nso/objects.digests" nso run-objects --ticks 30 --every 10 <"$folder/guids.txt"
    echo "[$name] Running each lot..."
    # run-lot takes one lot; run both sides on each, prefix lines with the lot's file name, and time the whole.
    run_lots() {
        local side="$1" lot file guids
        while read -r lot; do
            file="$(basename "$lot")"
            if [[ "$side" == fso ]]; then
                fso run-lot --blueprint "$lot" --ticks "$lot_ticks" --every "$lot_every" 2>"$folder/fso/lot-err.txt" | sed "s|^|$file |"
                cat "$folder/fso/lot-err.txt" >>"$folder/fso/log.txt"
                grep -o 'object 0x[0-9A-Fa-f]*; left out' "$folder/fso/lot-err.txt" | awk -v f="$file" '{ print f "\t" substr($2, 1, length($2) - 1) }' \
                    >>"$folder/fso/lots.leftout" || true
            else
                guids=()
                while IFS=$'\t' read -r leftFile guid; do
                    [[ "$leftFile" == "$file" ]] && guids+=(--leave-out "$guid")
                done <"$folder/fso/lots.leftout"
                nso run-lot --blueprint "$lot" --ticks "$lot_ticks" --every "$lot_every" "${guids[@]}" | sed "s|^|$file |"
            fi
        done <"$output/lots-run.txt"
    }
    touch "$folder/fso/lots.leftout"
    timed fso run-lot "$folder/fso/lots.digests" run_lots fso
    timed nso run-lot "$folder/nso/lots.digests" run_lots nso
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
