#!/bin/bash
# runtest.sh - this file is part of skills-testing-system
# Copyright (C) 2026  Kirill Rudkovskii
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

error() {
   echo -e "\033[33m$1\033[0m" >&2 # $1 - message
   exit 1
}

if [ $# -ne 1 ]; then
    error "Error! Use: runtest test_dir_name"
fi

testDir="${1%/}"
if [ ! -d "$testDir" ]; then
    error "Error: directory \"$testDir\" doesn't exist!"
fi
if ! ls "$testDir/"{pyenv,conf.txt,lib,data,run-stud-code.sh,work-tmp,test.db,log.txt} &> /dev/null; then
    error "Error: directory \"$testDir\" isn't correct!"
fi

if [ -z "$STS_SERVER_PATH" ]; then
    error "Error: global variable \"STS_SERVER_PATH\" is not defined!"
fi

dbFile="$testDir/test.db"
confFile="$testDir/conf.txt"
logFile="$testDir/log.txt"
logNumLine="$(cat "$logFile" | wc -l)"
serverPid=-1

getPropertyFromConfig() {
    local propName="$1"
    local templateValue="$2"
    local s='[[:space:]]'
    local propValue="$(sed -n "s/$s//g ; s/^$propName://p" < "$confFile")"
    if [ -z "$propValue" ]; then
        echo "Error: property \"${propName}\" is incorrect or missing in configuration file!"
        return 1
    fi
    if [ "$(echo "$propValue" | wc -l)" -gt 1 ]; then
        echo "Error: property \"${propName}\" is duplicated in configuration file!"
        return 2
    fi
    if ! echo "$propValue" | grep -P "^($templateValue)$" &> /dev/null; then
        echo "Error: the value of property \"$propName\" doesn't match the pattern \"$templateValue\" in configuration file!"
        return 3
    fi
    echo "$propValue" | tr -d '\n'
    return 0
}

readConfig() {
    local answer=""
    answer="$(getPropertyFromConfig "timeout" "\d+")"
    test $? -eq 0 && export STS_TIMEOUT="$answer" || error "$answer"

    answer="$(getPropertyFromConfig "nice" "[0-9]|1[0-9]")"
    test $? -eq 0 && export STS_NICE="$answer" || error "$answer"

    answer="$(getPropertyFromConfig "MemoryHigh" "\d+[KMGT%]?|infinity")"
    test $? -eq 0 && export STS_MEMORY_HIGH="$answer" || error "$answer"

    answer="$(getPropertyFromConfig "MemoryMax" "\d+[KMGT%]?|infinity")"
    test $? -eq 0 && export STS_MEMORY_MAX="$answer" || error "$answer"

    answer="$(getPropertyFromConfig "MemorySwapMax" "\d+[KMGT]?|infinity")"
    test $? -eq 0 && export STS_MEMORY_SWAP_MAX="$answer" || error "$answer"

    answer="$(getPropertyFromConfig "RunTasksMax" "\d+")"
    test $? -eq 0 && export STS_RUN_TASKS_MAX="$answer" || error "$answer"

    answer="$(getPropertyFromConfig "StudProcMax" "\d+")"
    test $? -eq 0 && export STS_STUD_PROC_MAX="$answer" || error "$answer"

    answer="$(getPropertyFromConfig "serverPort" "\d+")"
    test $? -eq 0 && serverPort="$answer" || error "$answer"
}
readConfig
chmod -R 755 "$testDir/work-tmp/"* 2> /dev/null
rm -rf "$testDir/work-tmp/"*
mkdir "$testDir/work-tmp/code"
mkdir "$testDir/work-tmp/out"
mkdir "$testDir/work-tmp/msg"
mkdir "$testDir/work-tmp/stud-home"

checkCmd() {
    local line="$1"
    local template="$2"
    echo "$line" | grep -P "$template" &> /dev/null
    return $?
}

getStudentResult() {
    local studentId="$1"
    local allTasks=($(echo "SELECT task_id FROM students_tasks WHERE student_id = $studentId" | sqlite3 "$dbFile"))
    local solvedTasks=($(echo "SELECT task_id FROM results WHERE student_id = $studentId AND status = 1" | sqlite3 "$dbFile"))
    local result=$(echo "(${#solvedTasks[*]}/${#allTasks[*]})*100" | bc -l)
    printf "%.2f" $result
}

indent() {
    sed 's/^/ /'
}

printStudents() {
    local students=""
    if [ $# -eq 1 ]; then
        local groupId="$1"
        groupId="$(echo "SELECT id FROM groups WHERE id = $groupId" | sqlite3 "$dbFile")"
        if [ -n "$groupId" ]; then
            students="$(echo "SELECT s.id, s.full_name, s.login_permission, g.name\
                       FROM students AS s JOIN groups AS g ON s.group_id = g.id WHERE s.group_id = $groupId" | sqlite3 "$dbFile")"
        else
            echo -e '\033[33mError: no such group id!\033[0m' | indent >&2
            return 1
        fi
    else
        students="$(echo "SELECT s.id, s.full_name, s.login_permission, g.name\
                   FROM students AS s JOIN groups AS g ON s.group_id = g.id" | sqlite3 "$dbFile")"
    fi
    local out='id|fullName|res(%)|lp|group'
    while read studLine; do
        local studentId="$(echo "$studLine" | cut -d '|' -f 1)"
        local fullName="$(echo "$studLine" | cut -d '|' -f 2)"
        local loginPermission="$(echo "$studLine" | cut -d '|' -f 3)"
        if [ "$loginPermission" -eq 1 ]; then
            loginPermission="\033[32mt\033[0m"
        else
            loginPermission="\033[31mf\033[0m"
        fi
        local group="$(echo "$studLine" | cut -d '|' -f 4)"
        local result="$(getStudentResult "$studentId")"
        out+="\n$studentId|$fullName|$result|$loginPermission|$group"
    done <<< "$students"
    echo -e "$out" | column -t -s '|' -o ' | '
    return 0
}

quit() {
    if [ "$serverPid" -ne -1 ]; then
        kill "$serverPid"
    fi
    echo -e '\r<< bye! >>'
    exit 0
}
trap quit SIGTERM SIGINT SIGQUIT


echo -en "\033[32m>> \033[0m"
while read line; do
    line="$(echo "$line" | tr '\t' ' ' | tr -s ' ')"
    if checkCmd "$line" '^g$'; then
        echo 'SELECT id, name FROM groups' | sqlite3 -header "$dbFile" | column -t -s '|' -o ' | ' | indent
    elif checkCmd "$line" '^s$'; then
        printStudents | indent
    elif checkCmd "$line" '^s csv$'; then
        printStudents | sed 's/\s*|\s*/,/g' | sort -t ',' -k 2
    elif checkCmd "$line" '^sg \d+$'; then
        groupId="$(echo "$line" | cut -d ' ' -f 2)"
        printStudents "$groupId" | indent
    elif checkCmd "$line" '^sg \d+ csv$'; then
        groupId="$(echo "$line" | cut -d ' ' -f 2)"
        printStudents "$groupId" | sed 's/\s*|\s*/,/g'
    elif checkCmd "$line" '^lp [tf]$'; then
        flag="$(echo "$line" | cut -d ' ' -f 2 | tr 't' '1' | tr 'f' '0')"
        echo "UPDATE students SET login_permission = $flag" | sqlite3 "$dbFile"
    elif checkCmd "$line" '^lps \d+ [tf]$'; then
        studentId="$(echo "$line" | cut -d ' ' -f 2)"
        flag="$(echo "$line" | cut -d ' ' -f 3 | tr 't' '1' | tr 'f' '0')"
        n="$(echo "SELECT COUNT(*) FROM students WHERE id = $studentId" | sqlite3 "$dbFile")"
        if [ "$n" -eq 0 ]; then
            echo -e '\033[33mError: no such student id!\033[0m' | indent
        else
            echo "UPDATE students SET login_permission = $flag WHERE id = $studentId" | sqlite3 "$dbFile"
        fi
    elif checkCmd "$line" '^lpg \d+ [tf]$'; then
        groupId="$(echo "$line" | cut -d ' ' -f 2)"
        flag="$(echo "$line" | cut -d ' ' -f 3 | tr 't' '1' | tr 'f' '0')"
        n="$(echo "SELECT COUNT(*) FROM groups WHERE id = $groupId" | sqlite3 "$dbFile")"
        if [ "$n" -eq 0 ]; then
            echo -e '\033[33mError: no such group id!\033[0m' | indent
        else
            echo "UPDATE students SET login_permission = $flag WHERE group_id = $groupId" | sqlite3 "$dbFile"
        fi
    elif checkCmd "$line" '^st \d+$'; then
        studentId="$(echo "$line" | cut -d ' ' -f 2)"
        n="$(echo "SELECT COUNT(*) FROM students WHERE id = $studentId" | sqlite3 "$dbFile")"
        if [ "$n" -eq 0 ]; then
            echo -e '\033[33mError: no such student id!\033[0m' | indent
        else
            allTasks=($(echo "SELECT task_id FROM students_tasks WHERE student_id = $studentId ORDER BY task_id" | sqlite3 "$dbFile" | tr '\n' ' '))
            solvedTasks=($(echo "SELECT task_id FROM results WHERE student_id = $studentId AND status = 1 ORDER BY task_id" | sqlite3 "$dbFile" | tr '\n' ' '))
            echo "all: ${allTasks[*]}" | indent
            echo "solved: ${solvedTasks[*]}" | indent
            if [ "${#allTasks[*]}" -gt 0 ]; then
                nextTaskClickCount="$(echo "SELECT next_task_click_count FROM students WHERE id = $studentId" | sqlite3 "$dbFile")"
                currentTaskIndex=$(( $nextTaskClickCount % ${#allTasks[*]} ))
                echo "current: ${allTasks[$currentTaskIndex]}" | indent
            fi
        fi
    elif checkCmd "$line" '^stc \d+ \d+$'; then
        studentId="$(echo "$line" | cut -d ' ' -f 2)"
        taskId="$(echo "$line" | cut -d ' ' -f 3)"
        resultId="$(echo "SELECT id FROM results WHERE student_id = $studentId AND task_id = $taskId" | sqlite3 "$dbFile")"

        if [ -z "$resultId" ]; then
            ns="$(echo "SELECT COUNT(*) FROM students WHERE id = $studentId" | sqlite3 "$dbFile")"
            nt="$(echo "SELECT COUNT(*) FROM tasks WHERE id = $taskId" | sqlite3 "$dbFile")"
            nst="$(echo "SELECT COUNT(*) FROM students_tasks WHERE student_id = $studentId AND task_id = $taskId" | sqlite3 "$dbFile")"
            if [ "$ns" -eq 0 ]; then
                echo -e "\033[33mError: no such student with id = $studentId!\033[0m" | indent
            elif [ "$nt" -eq 0 ]; then
                echo -e "\033[33mError: no such task with id = $taskId!\033[0m" | indent
            elif [ "$nst" -eq 0 ]; then
                echo -e "\033[33mError: Task with id = $taskId is not assigned to student with id = $studentId\033[0m" | indent
            else
                echo -e "\033[33mError: student with id = $studentId has not yet started solving task with id = $taskId!\033[0m" | indent
            fi
        else
            description="$(echo "SELECT description FROM tasks WHERE id = $taskId" | sqlite3 "$dbFile")"
            code="$(echo "SELECT code FROM results WHERE id = $resultId" | sqlite3 "$dbFile")"
            echo -e "\033[35mdescription:\033[0m\n$description"
            echo -e "\033[35mcode:\033[0m\n$code"
        fi
    elif checkCmd "$line" '^start$'; then
        pushd "$testDir" &> /dev/null
        java -jar "$STS_SERVER_PATH" --server.port=$serverPort &>> "log.txt" &
        serverPid=$!
        popd &> /dev/null
        sleep 2
        curLogNumLine=$(cat "$logFile" | wc -l)
        while [ $curLogNumLine -gt $logNumLine ]
        do
            numNewLines=$(( $curLogNumLine - $logNumLine ))
            cat "$logFile" | tail -n $numNewLines | indent
            logNumLine=$curLogNumLine
            sleep 2
            curLogNumLine=$(cat "$logFile" | wc -l)
        done
    elif checkCmd "$line" '^stop$'; then
        if [ "$serverPid" -ne -1 ]; then
            kill "$serverPid"
            serverPid=-1
        else
            echo -e '\033[33mError: server not running!\033[0m' | indent
        fi
    elif checkCmd "$line" '^log$'; then
        curLogNumLine="$(cat "$logFile" | wc -l)"
        if [ $curLogNumLine -gt $logNumLine ]; then
            numNewLines=$(( $curLogNumLine - $logNumLine ))
            cat "$logFile" | tail -n $numNewLines | indent
            logNumLine=$curLogNumLine
        fi
    elif checkCmd "$line" '^inst [A-Za-z0-9-]+$'; then
        libName="$(echo "$line" | cut -d ' ' -f 2)"
        bwrap \
        --new-session \
        --unshare-all \
        --share-net \
        --ro-bind /usr /usr \
        --symlink /usr/bin /bin \
        --symlink /usr/lib /lib \
        --symlink /usr/lib64 /lib64 \
        --ro-bind /etc /etc \
        --dev /dev \
        --bind "$(realpath $testDir)/pyenv" /pyenv \
        bash -c ". /pyenv/bin/activate;pip install $libName; deactivate" | indent
    elif checkCmd "$line" '^ip$'; then
        ip -br address | indent
    elif checkCmd "$line" '^q$'; then
        quit
    elif checkCmd "$line" '^h$'; then
        echo 'g - print list of all student groups' | indent
        echo 's - print list of all students' | indent
        echo 's csv - print list of all students in csv format' | indent
        echo 'sg <group_id> - print a list of all students in the group' | indent
        echo 'sg <group_id> csv - print a list of all students in the group in csv format' | indent
        echo 'lp t|f - set the login permission flag for all students' | indent
        echo 'lps <student_id> t|f - set the login permission flag for student' | indent
        echo 'lpg <group_id> t|f - set the login permission flag for all students in the group' | indent
        echo "st <student_id> - show student task id's" | indent
        echo "stc <student_id> <task_id> - show the description and code of the student's solution to the task" | indent
        echo 'start - web server start' | indent
        echo 'stop - web server stop' | indent
        echo 'log - print server log' | indent
        echo 'inst <python_package_name> - install python package into virtual environment inside sandbox' | indent
        echo 'ip - show IP addresses of host network interfaces' | indent
        echo 'q - exit' | indent
        echo 'h - print this help' | indent
    else
        if [ -n "$line" ]; then
            echo -e '\033[33mError: invalid command, use help\033[0m' | indent
        fi
    fi
    echo -en "\033[32m>> \033[0m"
done
quit
