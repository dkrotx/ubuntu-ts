#!/usr/bin/env bash

#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
# checking results of students homework
# Technosfera: indexation (https://github.com/dkrotx/ts-idx-2016)
#
# - launch ./preinstall.sh (optionally)
# - for each set of documents (*.gz):
# -- launch ./index.sh {varbyte|simple9} path/to/*.gz
# -- limit by time
# -- strictly check with diff
#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

TIMEDOUT_EXITSTATUS=124
TEST_DIR=/tmp/ts-idx-check

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
    local sample_encoding=$2
    local cpu_limit=$3
    local output=$4

    local input_files=$( ls /samples/sample${sample_no}/*.gz | LC_ALL=C sort )

    log_info Запускаю ./index.sh ${sample_encoding} $input_files
    timeout ${cpu_limit}m bash ./index.sh ${sample_encoding} $input_files >/dev/null 2>${output}.err

    ec=$?
    if [[ $ec -eq $TIMEDOUT_EXITSTATUS ]]; then
        log_err "Время вышло ($cpu_limit минут)"
        return 2
    elif [[ $ec -ne 0 ]]; then
        log_err "Скрипт завершился с ошибкой: $ec (вероятно, недостаточно памяти)"
        echo "Содержимое stderr (20 последних строк):"
        tail -n 20 ${output}.err
        return 1
    fi

    log_info Запускаю ./make_dict.sh
    timeout ${cpu_limit}m bash ./make_dict.sh >/dev/null 2>${output}.err

    ec=$?
    if [[ $ec -eq $TIMEDOUT_EXITSTATUS ]]; then
        log_err "Время вышло ($cpu_limit минут)"
        return 2
    elif [[ $ec -ne 0 ]]; then
        log_err "Скрипт завершился с ошибкой: $ec (вероятно, недостаточно памяти)"
        echo "Содержимое stderr (20 последних строк):"
        tail -n 20 ${output}.err
        return 1
    fi
    
    log_info Запускаю ./search.sh
    timeout 3s bash ./search.sh >$output 2>${output}.err </samples/sample${sample_no}/queries.txt

    ec=$?
    if [[ $ec -eq $TIMEDOUT_EXITSTATUS ]]; then
        log_err "Время вышло (3 секунды)"
        return 2
    elif [[ $ec -ne 0 ]]; then
        log_err "Скрипт завершился с ошибкой: $ec"
        echo "Содержимое stderr (20 последних строк):"
        tail -n 20 ${output}.err
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
    echo "Ваша оценка: ${LAST_MARK}"
    echo "!!! Внимание: финальная оценка будет проставлена позже, на основе кода"
    exit 0
}


check_sample() {
    local sample_no=$1
    local sample_encoding=$2
    local cpu_limit=$3
    local mark=$4

    prepare_run
    log_empty
    log_info "Проверяем на тестовом наборе #${sample_no}"

    run_sample $sample_no $sample_encoding $cpu_limit $OUTPUT_DIR/result.txt
    if [[ $? -ne 0 ]]; then
        print_mark_and_exit
    fi
    
    log_info "Сравниваем с опорным выводом (diff)"
    diff -U 100 /answers/sample${sample_no} $OUTPUT_DIR/result.txt >/tmp/diff

    if [[ $? -ne 0 ]]; then
        log_info "Проблема: Ваш вывод не совпадает с опорным (см. diff)"
        log_info "diff (первые 200 строк):"
        head -n 200 /tmp/diff
        log_info "======================================================"
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

    LOCATION=$( find $TEST_DIR -name index.sh | head -n 1 )
    if [[ -z $LOCATION ]]; then
        err "Не могу найти index.sh"
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
log_info "Начинаем проверку ДЗ (индексация и булев поиск)"

prepare_run

if [[ -e preinstall.sh ]]; then
    log_info "запускаю preinstall.sh"
    bash ./preinstall.sh
else
    log_info "preinstall.sh не найден, пропускаем"
fi


check_sample 0 varbyte 1 8   # tiny size (~1.5K docs)
check_sample 1 simple9 1 12  # normal size (10K)
check_sample 2 simple9 4 15  # big size (100K)
check_sample 3 varbyte 13 20 # huge size (~600K)

