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
    echo "[$( date +'%d.%m.%y %H:%M:%S' )] $*"
}

log_debug() {
    if [[ -n $LOG_DEBUG ]]; then
        __log DEBUG "$@"
    fi
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

    log_info Запускаю ./run.sh /samples/sample${sample_no}/*.gz
    timeout ${cpu_limit}m bash ./run.sh /samples/sample${sample_no}/*.gz >$output 2>${output}.err

    ec=$?
    if [[ $ec -eq $TIMEDOUT_EXITSTATUS ]]; then
        log_err "Время вышло ($cpu_limit минут)"
        return 2
    elif [[ $ec -ne 0 ]]; then
        log_err "Скрипт завершился с ошибкой: $ec (вероятно, недостаточно памяти)"
        echo "Содержимое stderr:"
        cat ${output}.err
        return 1
    fi

    return 0
}

LAST_MARK=0
UTILS_DIR=$( readlink -f $( dirname $0 ) )
OUTPUT_DIR=/tmp/output


print_mark_and_exit() {
    echo
    echo "==============================================================="
    echo "Ваша итоговая оценка: ${LAST_MARK}"
    exit 0
}


check_sample() {
    local sample_no=$1
    local cpu_limit=$2
    local mark=$3

    prepare_run
    log_empty
    log_info "Проверяем на тестовом наборе #${sample_no}"

    run_sample $sample_no $cpu_limit $OUTPUT_DIR/result.txt
    if [[ $? -ne 0 ]]; then
        print_mark_and_exit
    fi
    
    log_info "Сравниваем с опорным выводом"

    # actually check the result
    RES=$( $UTILS_DIR/cmp_results.sh /answers/sample${sample_no} $OUTPUT_DIR/result.txt )
    INTERSECTION=$( echo $RES | awk '{ print $1 }' )
    UNION=$( echo $RES | awk '{ print $2 }' )
    F=$[ 100 * $INTERSECTION / $UNION ]

    NL_ANSW=$( cat /answers/sample${sample_no} | wc -l )
    NL_YOU=$( cat $OUTPUT_DIR/result.txt | wc -l )

    log_info "Результат: кол-во пар дубликатов: ваш вариант - $NL_YOU, опорный вариант - $NL_ANSW"
    log_info "Результат: пересечение=$INTERSECTION, объединение=$UNION; F=${F}%"
    if [[ $F -lt 20 ]]; then
        log_info "Проблема: F слишком мал, Ваш вывод слишком отличается от опорного"
        print_mark_and_exit
    fi

    LAST_MARK=$mark
    log_info "Успешно: считаем, что оценка $LAST_MARK у Вас уже есть..."
    return 0
}

prepare_run() {
    rm -rf $OUTPUT_DIR
    mkdir $OUTPUT_DIR

    log_debug "Удаляем тестовую директорию $TEST_DIR"
    cd /
    rm -rf $TEST_DIR || err "Не могу удалить тестовую директорию"

    log_debug "Распаковываем архив $archive в $TEST_DIR"
    mkdir -p $TEST_DIR || err "Ошибка создания тестового каталога"
    tar -C $TEST_DIR -xf $archive

    LOCATION=$( find $TEST_DIR -name run.sh | head -n 1 )
    if [[ -z $LOCATION ]]; then
        err "Не могу запустить run.sh"
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
log_info "Ограничение по RAM: $mem_limit Mb"

log_empty
log_info "Начинаем проверку ДЗ (дубликаты)"

prepare_run

if [[ -e preinstall.sh ]]; then
    log_info "запускаю preinstall.sh"
    bash ./preinstall.sh
else
    log_info "preinstall.sh не найден, пропускаем"
fi

check_sample 0 10 6
check_sample 1 10 8
check_sample 2 10 12
check_sample 3 15 15


echo
echo "==============================================================="
log_info "Ваша финальная оценка: ${LAST_MARK}. Поздравляю!"
