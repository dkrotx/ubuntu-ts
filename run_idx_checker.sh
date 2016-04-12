#!/usr/bin/env bash

err() {
    echo "$@" >&2
    exit 1
}

if [[ $# -ne 1 ]]; then
    echo "Usage: $( basename $0 ) path/to/archive" >&2
    exit 64
fi


archive=$( readlink -f $1 )
archive_dst=/tmp/$( basename $archive )

UTILS_DIR=$( readlink -f $( dirname $0 ))/idx-check
[[ -d $UTILS_DIR ]] || err "utils directory not found"

CHECK_DATA=$HOME/Cloud/lects/ts-idx1/all-datasets

docker run --rm -m 2g -a stdout -a stderr \
    -v "$CHECK_DATA/samples:/samples:ro" \
    -v "$CHECK_DATA/answers:/answers:ro" \
    -v "$UTILS_DIR:/utils:ro" \
    -v "$archive:$archive_dst:ro" \
    dkrot/ubuntu-ts /utils/check.sh "$archive_dst" 2>&1 | fgrep -v 'Your kernel does not support swap limit capabilities'
