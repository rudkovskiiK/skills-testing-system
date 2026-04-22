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

if [ -z "$STS_SERVER_PATH" ]; then
    error "Error: global variable \"STS_SERVER_PATH\" is not defined!"
fi

testDir="${1%/}"
dbFile="$testDir/test.db"
resourceLimitsFile="$testDir/settings/resource_limits.txt"
serverSettingsFile="$testDir/settings/server.txt"
logFile="$testDir/log.txt"

if [ ! -d "$testDir" ]; then
    error "Error: directory \"$testDir\" doesn't exist!"
fi
if ! ls "$testDir/"{tools,lib,settings,data,work-tmp,test.db,log.txt} &> /dev/null; then
    error "Error: directory \"$testDir\" isn't correct!"
fi
if [ ! -f "$resourceLimitsFile" ]; then
    error "Error: file \"$resourceLimitsFile\" doesn't exist!"
fi
if [ ! -f "$serverSettingsFile" ]; then
    error "Error: file \"$serverSettingsFile\" doesn't exist!"
fi
logNumLine="$(cat "$logFile" | wc -l)"
export STS_SERVER_PID=-1

getPropertyFromFile() {
    file="$1"
    propName="$2"
    templateValue="$3"
    propStr="$(cat "$file" | tr -d '\t ' | grep -iP "^$propName:")"
    if [ $? -ne 0 ]; then
        echo -e "\033[33mError: property \"${propName}\" is incorrect or missing in file \"$file\"!\033[0m" >&2
        return 1
    fi
    if [ $(echo "$propStr" | wc -l) -gt 1 ]; then
        echo -e "\033[33mError: property \"${propName}\" is duplicated in file \"$file\"!\033[0m" >&2
        return 2
    fi
    value="${propStr#*:}"
    if ! echo "$value" | grep -P "^($templateValue)$" &> /dev/null; then
        echo -e "\033[33mError: the value of property \"$propName\" doesn't match the pattern \"$templateValue\" in file \"$file\"!\033[0m" >&2
        return 3
    fi
    echo "$value"
    return 0
}
STS_TIMEOUT=$(getPropertyFromFile "$resourceLimitsFile" "timeout" "\d+") || exit $?
STS_NICE=$(getPropertyFromFile "$resourceLimitsFile" "nice" "\d+") || exit $?
if [ $STS_NICE -gt 19 ]; then
    error "Error: parameter \"nice\" cannot exceed 19!"
fi
STS_MEMORY_HIGH=$(getPropertyFromFile "$resourceLimitsFile" "MemoryHigh" "\d+[KMGT%]?|infinity") || exit $?
STS_MEMORY_MAX=$(getPropertyFromFile "$resourceLimitsFile" "MemoryMax" "\d+[KMGT%]?|infinity") || exit $?
STS_MEMORY_SWAP_MAX=$(getPropertyFromFile "$resourceLimitsFile" "MemorySwapMax" "\d+[KMGT]?|infinity") || exit $?
STS_RUN_TASKS_MAX=$(getPropertyFromFile "$resourceLimitsFile" "RunTasksMax" "\d+") || exit $?
STS_STUD_PROC_MAX=$(getPropertyFromFile "$resourceLimitsFile" "StudProcMax" "\d+") || exit $?
export STS_TIMEOUT STS_NICE STS_MEMORY_HIGH STS_MEMORY_MAX STS_MEMORY_SWAP_MAX STS_RUN_TASKS_MAX STS_STUD_PROC_MAX
serverPort=$(getPropertyFromFile "$serverSettingsFile" "port" "\d+") || exit $?

rm -rf "$testDir/work-tmp/"* 2> /dev/null
mkdir "$testDir/work-tmp/code"
mkdir "$testDir/work-tmp/out"
mkdir "$testDir/work-tmp/msg"
mkdir "$testDir/work-tmp/stud-home"
studentIds="$(echo "SELECT id FROM students" | sqlite3 "$dbFile")"
for studentId in $studentIds; do
    mkdir "$testDir/work-tmp/stud-home/$studentId"
done

checkCmd() {
    line="$1"
    template="$2"
    echo "$line" | grep -P "$template" &> /dev/null
    return $?
}

getStudentResult() {
    studentId="$1"
    allTasks=($(echo "SELECT task_id FROM students_tasks WHERE student_id = $studentId" | sqlite3 "$dbFile"))
    solvedTasks=($(echo "SELECT task_id FROM results WHERE student_id = $studentId AND status = 1" | sqlite3 "$dbFile"))
    result=$(echo "(${#solvedTasks[*]}/${#allTasks[*]})*100" | bc -l)
    printf "%.2f" $result
}

indent() {
    sed 's/^/ /'
}

printStudents() {
    students=""
    if [ $# -eq 1 ]; then
        groupId="$1"
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
    out='id|fullName|res(%)|lp|group'
    while read studLine; do
        studentId="$(echo "$studLine" | cut -d '|' -f 1)"
        fullName="$(echo "$studLine" | cut -d '|' -f 2)"
        loginPermission="$(echo "$studLine" | cut -d '|' -f 3)"
        if [ "$loginPermission" -eq 1 ]; then
            loginPermission="\033[32mt\033[0m"
        else
            loginPermission="\033[31mf\033[0m"
        fi
        group="$(echo "$studLine" | cut -d '|' -f 4)"
        result="$(getStudentResult "$studentId")"
        out+="\n$studentId|$fullName|$result|$loginPermission|$group"
    done <<< "$students"
    echo -e "$out" | column -t -s '|' -o ' | '
    return 0
}

quit() {
    if [ $STS_SERVER_PID -ne -1 ]; then
        kill $STS_SERVER_PID
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
        printStudents | sed 's/\s*|\s*/,/g'
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
        STS_SERVER_PID=$!
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
        if [ $STS_SERVER_PID -ne -1 ]; then
            kill $STS_SERVER_PID
            STS_SERVER_PID=-1
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
        --bind "$(realpath $testDir)/lib/pyenv" /pyenv \
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
