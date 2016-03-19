#!/usr/bin/env bash

#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
# checking results of students homework
# Technosfera: duplicates (Broader' algorithm for near duplicates)
#
# - launch ./preinstall.sh (optionally)
# - for each set of URL-samples do:
# -- launch ./run.sh path/to/samples/*.gz
# -- limit by time
# -- briefly check for results
#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

TIMEDOUT_EXITSTATUS=124
TEST_DIR=/tmp/dups-check

__log() {
    local level=$1
    shift
    echo "[$( date +'%d.%m.%y %H:%M:%S' )] $level: $*"
}

log_info() {
    __log INFO "$@"
}

log_err() {
    __log ERROR "$@"
}


log_empty() {
    echo
}

err() {
    log_err "$@"
    exit 1
}


run_sample() {
    local sample_no=$1
    local cpu_limit=$2
    local output=$3

    timeout ${cpu_limit}m bash ./run.sh /samples/sample${sample_no}/*.gz >$output

    ec=$?
    if [[ $ec -eq $TIMEDOUT_EXITSTATUS ]]; then
        log_err "timeout ($cpu_limit) exhausted"
        return 2
    elif [[ $ec -ne 0 ]]; then
        log_err "script exited with non-zero status: $ec"
        return 1
    fi

    return 0
}

LAST_MARK=0
UTILS_DIR=$( readlink -f $( dirname $0 ) )
OUTPUT_DIR=/tmp/output


print_mark_and_exit() {
    echo "Your final result: ${LAST_MARK}"
    exit 0
}


check_sample() {
    local sample_no=$1
    local cpu_limit=$2
    local mark=$3

    prepare_run
    log_empty
    log_info "Launching sample${sample_no}"

    run_sample $sample_no $cpu_limit $OUTPUT_DIR/result.txt
    if [[ $? -ne 0 ]]; then
        print_mark_and_exit
    fi

    # actually check the result
    RES=$( $UTILS_DIR/cmp_results.sh /answers/sample${sample_no} $OUTPUT_DIR/result.txt )
    INTERSECTION=$( echo $RES | awk '{ print $1 }' )
    UNION=$( echo $RES | awk '{ print $2 }' )
    F=$[ 100 * $INTERSECTION / $UNION ]

    log_info "Output values: intersection=$INTERSECTION, union=$UNION; F=${F}%"
    if $F -lt 30; then
        log_info "FAIL: F is too small"
        print_mark_and_exit
    fi

    LAST_MARK=$mark
    log_info "SUCCESS: You got $LAST_MARK mark at least..."
    return 0
}

prepare_run() {
    rm -rf $OUTPUT_DIR
    mkdir $OUTPUT_DIR

    log_info "Remove temp directory $TEST_DIR"
    cd /
    rm -rf $TEST_DIR || err "failed to remove test dir"

    log_info "Extracting $archive to $TEST_DIR"
    mkdir -p $TEST_DIR || err "failed to create test dir"
    bash -x -c "tar -C $TEST_DIR -xf $archive"

    LOCATION=$( find $TEST_DIR -name run.sh | head -n 1 )
    if [[ -z $LOCATION ]]; then
        err "Can't find run.sh"
    fi

    cd $( dirname "$LOCATION" )
}

usage() {
    echo "Usage: $( basename $0 ) path/to/archive" >&2
    exit 64
}


###############################################################################
## MAIN
###############################################################################


[[ $# -eq 1 ]] || usage
archive=$1


log_empty

log_info "$( uname -sm ): $( lsb_release -i -s ) $( lsb_release -s -r ) ($( lsb_release -c -s ))"
mem_limit=$[ $( grep hierarchical_memory_limit /sys/fs/cgroup/memory/memory.stat | awk '{ print $2 }' ) / 2**20 ]
log_info "RAM limit: $mem_limit Mb"

log_empty
log_info "Starting to check homework #2"

prepare_run

if [[ -e preinstall.sh ]]; then
    log_info "launching preinstall.sh"
    bash ./preinstall.sh
else
    log_info "preinstall.sh not found, skipping"
fi

check_sample 1 10 5
check_sample 2 10 10
check_sample 3 15 15


log_info "Your final result: ${LAST_MARK}. Congratulations!"
