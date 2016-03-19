#!/usr/bin/env bash

normalize_file() {
    LC_ALL=C $THIS_DIR/normalize_result.py $1 | LC_ALL=C sort >$2
}

if [[ $# -ne 2 ]]; then
    echo "Usage: $( basename $0 ) basefile newfile" >&2
    exit 64
fi

basefile=$1
resfile=$2

OUTPUT_DIR=$( mktemp -d -t cmp_res_XXXXXX )
THIS_DIR=$( dirname $0 )

trap "rm -rf $OUTPUT_DIR" EXIT

normalize_file $basefile $OUTPUT_DIR/base
normalize_file $resfile $OUTPUT_DIR/res

INTERSECTION=$( LC_ALL=C comm -1 -2 $OUTPUT_DIR/base $OUTPUT_DIR/res | wc -l )
UNION=$( LC_ALL=C comm $OUTPUT_DIR/base $OUTPUT_DIR/res | wc -l )

echo $INTERSECTION $UNION
