#!/usr/bin/env bash
# Extracts The Sims Online installer's .cab files into a game folder that
# tsofiles-check and the NSOClient packages can read.
#
# The format is detected from each cabinet's first bytes:
#   MSCF  Microsoft Cabinet, extracted with cabextract (spanned sets supported)
#   ISc(  InstallShield cabinet, extracted with unshield (needs data1.hdr beside it)
# The source can be a folder of cabinets, a single cabinet, or a .zip holding them.

set -euo pipefail

readonly program_name="${0##*/}"

usage() {
    cat <<EOF
usage: $program_name [options] <installer folder | first .cab | .zip> <output folder>

Extracts The Sims Online installer cabinets into <output folder>, then reports
where the TSOClient game folder ended up.

options:
  --lowercase    lower-case every extracted path (cabextract -L); helps tools
                 that assume lower-case paths, such as FreeSO's update-46 client
  --force        extract into an output folder that isn't empty
  --skip-test    don't test cabinet integrity before extracting
  --check        run tsofiles-check on the result (needs the Swift toolchain)
  -h, --help     show this help

exit status: 0 on success, 1 if extraction or the check fails, 2 for usage errors
EOF
}

die() {
    printf '%s: %s\n' "$program_name" "$1" >&2
    exit "${2:-1}"
}

need() {
    command -v "$1" >/dev/null 2>&1 || die "$1 is required: $2"
}

# Prints the first four bytes of a file as text, or nothing if it's shorter.
magic_of() {
    head -c 4 -- "$1" 2>/dev/null | LC_ALL=C tr -c '[:print:]' '.'
}

lowercase=false
force=false
test_first=true
run_check=false
positional=()

while (($# > 0)); do
    case "$1" in
        --lowercase) lowercase=true ;;
        --force) force=true ;;
        --skip-test) test_first=false ;;
        --check) run_check=true ;;
        -h | --help) usage; exit 0 ;;
        --) shift; positional+=("$@"); break ;;
        -*) usage >&2; die "unknown option $1" 2 ;;
        *) positional+=("$1") ;;
    esac
    shift
done

((${#positional[@]} == 2)) || { usage >&2; die "expected a source and an output folder" 2; }
source_path=${positional[0]}
output_dir=${positional[1]}

[[ -e $source_path ]] || die "$source_path does not exist" 2
if [[ -d $output_dir && -n $(ls -A -- "$output_dir") && $force == false ]]; then
    die "$output_dir is not empty (use --force to extract into it anyway)" 2
fi

work_dir=$(mktemp -d)
trap 'rm -rf -- "$work_dir"' EXIT

# A .zip is unpacked first; the cabinets inside are then handled like a folder.
if [[ -f $source_path && ${source_path,,} == *.zip ]]; then
    if command -v bsdtar >/dev/null 2>&1; then
        bsdtar -xf "$source_path" -C "$work_dir"
    elif command -v 7z >/dev/null 2>&1; then
        7z x -y -o"$work_dir" -- "$source_path" >/dev/null
    else
        die "unpacking a .zip needs bsdtar or 7z"
    fi
    source_path=$work_dir
fi

# Collect cabinets in natural order (data1, data2, ..., data10), case-insensitively.
cabinets=()
if [[ -d $source_path ]]; then
    while IFS= read -r -d '' cabinet; do
        cabinets+=("$cabinet")
    done < <(find "$source_path" -type f -iname '*.cab' -print0 | sort -z -V)
else
    cabinets=("$source_path")
fi
((${#cabinets[@]} > 0)) || die "no .cab files found in $source_path"

first=${cabinets[0]}
magic=$(magic_of "$first")
printf 'found %d cabinet(s); first is %s (%s)\n' "${#cabinets[@]}" "${first##*/}" "${magic:-empty}"

mkdir -p -- "$output_dir"

case "$magic" in
    MSCF)
        need cabextract "install the cabextract package"
        for cabinet in "${cabinets[@]}"; do
            [[ $(magic_of "$cabinet") == MSCF ]] || die "${cabinet##*/} is not a Microsoft Cabinet like the first one"
        done
        cabextract_flags=(-q)
        [[ $lowercase == true ]] && cabextract_flags+=(-L)
        if [[ $test_first == true ]]; then
            echo "testing cabinets..."
            cabextract -t -q -- "${cabinets[@]}" >/dev/null || die "a cabinet failed its integrity test (missing or damaged part?)"
        fi
        echo "extracting with cabextract..."
        # Listing every cabinet lets cabextract join spanned sets and extract each file once.
        cabextract -d "$output_dir" "${cabextract_flags[@]}" -- "${cabinets[@]}" || die "cabextract failed"
        ;;
    'ISc(')
        need unshield "install unshield (for example: brew install unshield)"
        header=$(find "$(dirname -- "$first")" -maxdepth 1 -type f -iname 'data1.hdr' -print -quit)
        [[ -n $header ]] || echo "warning: no data1.hdr next to ${first##*/}; unshield may fail" >&2
        unshield_flags=(-d "$output_dir")
        [[ $lowercase == true ]] && unshield_flags+=(-L)
        if [[ $test_first == true ]]; then
            echo "testing cabinets..."
            unshield t "$first" >/dev/null || die "the InstallShield cabinet set failed its integrity test"
        fi
        echo "extracting with unshield..."
        unshield "${unshield_flags[@]}" x "$first" >/dev/null || die "unshield failed"
        ;;
    *)
        die "${first##*/} is not a Microsoft (MSCF) or InstallShield (ISc() cabinet"
        ;;
esac

# Find the game folder: the one holding tuning.dat, which every TSO install has.
tuning=$(find "$output_dir" -type f -iname 'tuning.dat' -print -quit)
if [[ -z $tuning ]]; then
    echo "warning: extracted, but no tuning.dat was found; this may not be a complete TSO install" >&2
    game_dir=$output_dir
else
    game_dir=$(dirname -- "$tuning")
fi

game_dir=$(cd -- "$game_dir" && pwd)
file_count=$(find "$output_dir" -type f | wc -l)
printf 'extracted %d files\ngame folder: %s\n' "$file_count" "$game_dir"
printf 'next: export TSO_GAME_DIR=%q\n' "$game_dir"

if [[ $run_check == true ]]; then
    need swift "the Swift toolchain runs tsofiles-check"
    package_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../TSOFilesCheck" && pwd)
    echo "running tsofiles-check..."
    swift run --package-path "$package_dir" -q tsofiles-check "$game_dir"
fi
