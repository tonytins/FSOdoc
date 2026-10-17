#!/usr/bin/env bash
# Runs the same experiments through fso-oracle (FreeSO) and nso-oracle (NSOClient) on each install,
# reports whether their records agree, and with --review writes docs/results/nso-review.md. Run it after a phase or milestone,
# not every session: it reruns every object and every primitive case on every install.
#
#   NSOClient/scripts/oracle-review.sh [--review | --mock] [OUTPUT_DIR]     (default: $TMPDIR/oracle-review)
#
# Installs come from TSO_GAME_DIR ("production") and TSO_BETA_DIR ("beta"); either or both.
# --mock runs on NSOClient/MockInstall ("mock") alone, as CI does: it never writes the review, and
# it fails if any comparison has a mismatch.
# Needs the .NET SDK, Swift, and python3. Each install gets OUTPUT_DIR/NAME/fso/, FreeSO's
# records from oracle-fixtures.sh (also a TSO_ORACLE_DIR for the NSOOracle tests), and
# OUTPUT_DIR/NAME/nso/, NSOClient's records of the same experiments in the same files, each with
# timings.tsv.
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
# Kept in step with oracle-fixtures.sh.
lot_ticks=1800
lot_every=300

echo "Building both oracles..."
dotnet build "$repository/NSOClient/FSO.Oracle" -c Release >/dev/null
swift build --package-path "$repository/NSOClient/NSOOracle" -c release >/dev/null
nso_binary="$(swift build --package-path "$repository/NSOClient/NSOOracle" -c release --show-bin-path)/nso-oracle"

for install in "${installs[@]}"; do
    name="${install%%=*}"
    game="${install#*=}"
    fso_folder="$output/$name/fso"
    folder="$output/$name/nso"
    mkdir -p "$folder"
    rm -f "$folder"/*.jsonl "$folder"/*.digests "$folder"/*.tsv "$folder/log.txt"

    echo "[$name] FreeSO's side..."
    if $mock; then
        ORACLE_BUILT=1 "$repository/NSOClient/scripts/oracle-fixtures.sh" --mock "$fso_folder" | sed "s|^|[$name] |"
    else
        ORACLE_BUILT=1 TSO_GAME_DIR="$game" "$repository/NSOClient/scripts/oracle-fixtures.sh" "$fso_folder" | sed "s|^|[$name] |"
    fi

    nso() { "$nso_binary" "$1" --game "$game" "${@:2}"; }
    # timed NAME COMMAND...: runs COMMAND, with its messages in log.txt, and records its seconds.
    timed() {
        local label="$1" start end
        shift
        start=$(date +%s.%N)
        "$@" 2>>"$folder/log.txt"
        end=$(date +%s.%N)
        printf '%s\t%s\n' "$label" "$(awk "BEGIN { printf \"%.1f\", $end - $start }")" >>"$folder/timings.tsv"
    }

    echo "[$name] NSOClient's side..."
    timed list-objects nso list-objects >"$folder/objects.tsv"
    timed run-objects nso run-objects --ticks 30 --every 10 <"$fso_folder/guids.txt" >"$folder/objects.digests"
    # Each lot with the objects fso-oracle left out of it left out here too.
    run_lots() {
        local lot file leave
        while read -r lot; do
            file="$(basename "$lot")"
            mapfile -t leave < <(awk -F'\t' -v f="$file" '$1 == f { print "--leave-out"; print $2 }' "$fso_folder/lots.leftout")
            nso run-lot --blueprint "$lot" --ticks "$lot_ticks" --every "$lot_every" "${leave[@]}" | sed "s|^|$file |"
        done <"$fso_folder/lots.run"
    }
    timed run-lot run_lots >"$folder/lots.digests"
    mapfile -t leave < <(awk '{ print "--leave-out"; print $1 }' "$fso_folder/primitives.leftout")
    for requests in "$fso_folder"/*.requests.jsonl; do
        primitive="$(basename "$requests" .requests.jsonl)"
        timed "run-primitive $primitive" nso run-primitive --blueprint "$(cat "$fso_folder/primitives.lot")" "${leave[@]}" \
            <"$requests" >"$folder/$primitive.responses.jsonl"
    done
    timed room-maps "$nso_binary" room-maps <"$fso_folder/rooms.lots" >"$folder/rooms.jsonl"

    arguments=(compare --fso "$fso_folder" --nso "$folder" --install "$name")
    if $mock; then arguments+=(--strict); fi
    if $review; then
        arguments+=(--review "$repository/docs/results/nso-review.md"
                    --commit "$(git -C "$repository" rev-parse --short HEAD)")
    fi
    "$nso_binary" "${arguments[@]}"
done
