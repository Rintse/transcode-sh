#!/bin/bash
set -e

SRC=/media/flac
TGT=/media/opus
TC_CMD="ffmpeg -y"
TC_FLAGS="-c:v copy -c:a libopus -vbr on -b:a 256k"
SRC_EXT=flac
TGT_EXT=opus

echo "Searching for source files.."
SRC_FILES=$(find "$SRC" -type f -regex ".*.$SRC_EXT$")
readarray -td$'\n' SRC_FILE_ARR < <(printf "$SRC_FILES")

get_relative_path() {
    src="$1"
    path="$2"
    echo ${path#$src}
}

echo "Building up directory structure and command list.."
TRANSCODE_CMDS=""
for file in "${SRC_FILE_ARR[@]}"; do
    rel_path=$(get_relative_path "$SRC" "$file")
    rel_parent=$(dirname "$rel_path")

    mkdir -p "$TGT$rel_parent"
    tgt="$TGT${rel_path%.$SRC_EXT}.$TGT_EXT"

    if [[ ! -f "$tgt" ]]; then
        TRANSCODE_CMDS="$TRANSCODE_CMDS\n$TC_CMD -i \"$file\" $TC_FLAGS \"$tgt\""
    fi
done

# Transcode all the non-present files to the target
echo -e "Transcoding:$TRANSCODE_CMDS"
nproc=$(( $(nproc) - 1 ))
parallel --max-procs $nproc --eta < <(printf "$TRANSCODE_CMDS"); 

# Delete files in the target that are not in the source
TGT_FILES=$(find "$TGT" -type f -regex ".*.$TGT_EXT$")
readarray -td$'\n' TGT_FILE_ARR < <(printf "$TGT_FILES")

for file in "${TGT_FILE_ARR[@]}"; do
    rel_path=$(get_relative_path "$TGT" "$file")
    rel_parent=$(dirname "$rel_path")

    src="$SRC${rel_path%.$TGT_EXT}.$SRC_EXT"

    if [[ ! -f "$src" ]]; then
	echo "Removing: $file"
	rm "$file"
    fi
done

# remove all empty folders
find "$TGT" -type d -empty | xargs rmdir -p
