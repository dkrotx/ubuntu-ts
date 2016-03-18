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

TIMEDOUT_EXITSTATUS=124

run_sample() {
    local sample_no=$1
    local cpu_limit=$2

    timeout ${cpu_limit}m bash ./run.sh /samples/sample${sample_no}/*.gz >/tmp/result${sample_no}.txt

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

check_sample() {
    local sample_no=$1
    local cpu_limit=$2
    local mark=$3

    log_empty
    log_info "Launching sample${sample_no}"

    run_sample $sample_no $cpu_limit
    if [[ $? -ne 0 ]]; then
        echo "Your final result: ${LAST_MARK}. Try again..."
        exit 1
    fi

    # TODO: actually check the result

    LAST_MARK=$mark
    log_info "SUCCESS: You got $LAST_MARK mark at least..."
    return 0
}


###############################################################################
## MAIN
###############################################################################

log_empty

log_info "$( uname -sm ): $( lsb_release -i -s ) $( lsb_release -s -r ) ($( lsb_release -c -s ))"
mem_limit=$[ $( grep hierarchical_memory_limit /sys/fs/cgroup/memory/memory.stat | awk '{ print $2 }' ) / 2**20 ]
log_info "RAM limit: $mem_limit Mb"

log_empty
log_info "Starting to check homework #2"

LOCATION=$( find . -name run.sh | head -n 1 )
if [[ -z $LOCATION ]]; then
    err "Can't find run.sh"
fi

cd $( dirname "$LOCATION" )

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
log_info "SUCCESSFULLY FINISHED! !"
