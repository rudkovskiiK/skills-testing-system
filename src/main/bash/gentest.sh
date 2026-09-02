#!/bin/bash
# gentest.sh - this file is part of skills-testing-system
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

shopt -s extglob

info() {
   echo -en "\033[32m$1\033[0m" # $1 - message
}

printOk() {
   echo -e "\033[32mOK\033[0m"
}

if [ $# -ne 3 ]; then
    echo -e "\033[33mError! Use: gentest test_name group_directory task_directory\033[0m" >&2
    exit 1
fi

testDir="${1%/}"
groupDir="${2%/}"
taskDir="${3%/}"

if [ -e "$testDir" ]; then
    echo -e "\033[33mError: \"$testDir\" already exists!\033[0m" >&2
    exit 1
fi
info "Creating \"$testDir\" directory..."
mkdir -p "$testDir"
printOk

error() {
    echo -e "\033[33m$1\033[0m" | tr -s ' ' >&2 # $1 - message
    find "$testDir/data" -type d -exec chmod 755 {} \; &> /dev/null
    rm -rf "$testDir"
    exit 1
}

for dir in "$groupDir" "$taskDir"; do
    if [ ! -d "$dir" ]; then
        error "Error: directory \"$dir\" doesn't exist!"
    fi
done

if [ -z "$(ls "$groupDir")" ]; then
    error "Error: \"$groupDir\" directory is empty!"
fi

if ! ls "$taskDir/"*.* &> /dev/null; then
    error "Error: directory \"$taskDir\" doesn't contain any code files!"
fi

if ls "$taskDir/"*.py &> /dev/null; then
    if ! env | grep "VIRTUAL_ENV" &> /dev/null; then
        error "Error: python environment must be activated!"
    fi
fi

testDir="$(realpath "$testDir")"
groupDir="$(realpath "$groupDir")"
taskDir="$(realpath "$taskDir")"
dbFile="$testDir/test.db"
taskLabels=(L M H)

mkdir "$testDir/tools"
mkdir "$testDir/lib"
mkdir "$testDir/settings"
mkdir "$testDir/data"
mkdir "$testDir/work-tmp"
touch "$testDir/log.txt"

info "Creating database tables..."
echo "PRAGMA foreign_keys = ON;
CREATE TABLE groups (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL UNIQUE);
CREATE TABLE students (id INTEGER PRIMARY KEY AUTOINCREMENT, full_name TEXT NOT NULL, \
login_permission BOOLEAN NOT NULL CHECK(login_permission IN (0, 1)) DEFAULT 1, \
group_id INTEGER REFERENCES groups(id) ON DELETE RESTRICT, password TEXT NOT NULL, \
next_task_click_count INTEGER NOT NULL DEFAULT 0);
CREATE TABLE tasks (id INTEGER PRIMARY KEY AUTOINCREMENT, description TEXT NOT NULL UNIQUE, \
answer TEXT NOT NULL, difficulty_level INTEGER NOT NULL CHECK(difficulty_level IN (0, 1, 2)), \
class TEXT NOT NULL, language TEXT NOT NULL, run_script TEXT NOT NULL);
CREATE TABLE students_tasks (student_id INTEGER REFERENCES students(id) ON DELETE RESTRICT, \
task_id INTEGER REFERENCES tasks(id) ON DELETE RESTRICT, UNIQUE(task_id, student_id));
CREATE TABLE results (id INTEGER PRIMARY KEY AUTOINCREMENT, \
student_id INTEGER REFERENCES students(id) ON DELETE RESTRICT, \
task_id INTEGER REFERENCES tasks(id) ON DELETE RESTRICT, code TEXT NOT NULL, \
status BOOLEAN NOT NULL CHECK(status IN (0, 1)), UNIQUE(student_id, task_id));" | sqlite3 "$dbFile"
printOk

if [ -d "$taskDir/data" ]; then
    if ls "$taskDir/data/"* &> /dev/null; then
        info "Copying files from directory \"$taskDir/data\"..."
        cp -r "$taskDir/data/"* "$testDir/data"
        chmod -R ugo-w "$testDir/data"
        printOk
    fi
fi

getSpecialCommentBody() {
    local task="$1"
    local keyWord="$2"
    local s='[[:space:]]'
    sed -nE "s/$s*$// ; s%^$s*(#|//)$s*:$keyWord:$s*%%p" < "$task"
}

addTaskToDb() {
    local task="$1"
    local taskId="$2"
    local language="${task##*.}"
    local description="$(getSpecialCommentBody "$task" 'd' | tr '\n' ' ' | tr "'" '"')"
    if [ -z "$description" ]; then
        error "Error: there is no description in the task file \"$task\"!
               Example description:
               #|// :d: your_description
               #|// :d: your_description"
    fi
    local query="SELECT (id) FROM tasks WHERE description = '$description'"
    if [ ! -z "$(echo "$query" | sqlite3 "$dbFile")" ]; then
        error "Error: the following task description occurs twice:\n\"$description\"!"
    fi
    local diffLevel="$(getSpecialCommentBody "$task" 'level' | head -1 | tr -d '\n' | tr 'L' '0' | tr 'M' '1' | tr 'H' '2')"
    if ! echo "$diffLevel" | grep "^[012]$" &> /dev/null; then
        error "Error: missing or invalid difficulty level label in the task file \"$task\"!
               Use: #|// :level: L|M|H"
    fi
    local class="$(getSpecialCommentBody "$task" 'class' | head -1 | tr -d '\n')"
    if ! echo "$class" | grep -P "^\w+$" &> /dev/null; then
        error "Error: missing or invalid class label in the task file \"$task\"!
               Use: #|// :class: [A-Za-z0-9_]+"
    fi
    local run_com_tmpl="$(getSpecialCommentBody "$task" 'run' | head -1)"
    if ! echo "$run_com_tmpl" | grep -P "^[a-zA-Z0-9_+]+\s+{}.*$" &> /dev/null; then
        error "Error: missing or invalid run instruction in the task file \"$task\"!
               Correct examples:
               #|// :run: gcc {} -o exe && ./exe
               #|// :run: python {}"
    fi
    local run_com="$(echo "$run_com_tmpl" | sed "s|{}|$task|")"
    local run_dir="$testDir/run"
    mkdir "$run_dir"
    if [ -d "$testDir/data" ]; then
        ln -s "$testDir/data" "$run_dir/data"
    fi
    pushd "$run_dir" &> /dev/null
    local answer
    answer="$(bash -c "$run_com")" || error "Error in task: \"$task\""
    popd &> /dev/null
    rm -rf "$run_dir"
    local answer="$(echo "$answer" | tr -d '\n\t\r ')"
    if [ -z "$answer" ]; then
        error "Error: The answer to task \"$task\" is empty!"
    fi
    local hashAnswer="$(echo -n "$answer" | sha256sum | tr -d ' \-\n')"
    local run_script="$(echo "$run_com_tmpl" | sed "s|{}|/code.$language|")"
    if [ "$language" = 'py' ]; then
        run_script="source /pyenv/bin/activate ; $run_script"
    fi
    info "\nAdding ${taskLabels[$diffLevel]}-level (\"$class\"-class) task with id $taskId: \"$description\" to database..."
    echo "INSERT INTO tasks (id, description, answer, difficulty_level, class, language, run_script) VALUES \
        ($taskId, '$description', '$hashAnswer', $diffLevel, '$class', '$language', '$run_script')" | sqlite3 "$dbFile"
    printOk
}

distributeTasks() {
    local studentId="$1"
    local taskDistribution=($(echo "$2" | tr 'LMH' ' ')) # $2 - example: 3H2M1L
    for i in ${!taskDistribution[*]}; do
        local n="${taskDistribution[$i]}"
        if [ "$n" -gt 0 ]; then
            local query="SELECT DISTINCT class FROM tasks WHERE difficulty_level = $i ORDER BY RANDOM() LIMIT $n"
            local nUniqueClasses=($(echo "$query" | sqlite3 "$dbFile"))
            if [ "${#nUniqueClasses[*]}" -ne "$n" ]; then
                query="SELECT full_name FROM students WHERE id = $studentId"
                local name="$(echo "$query" | sqlite3 "$dbFile")"
                query="SELECT name FROM groups WHERE id = (SELECT group_id FROM students WHERE id = $studentId)"
                local group="$(echo "$query" | sqlite3 "$dbFile")"
                error "Error: there are not enough tasks of different classes of ${taskLabels[$i]}-level tasks \
                       for student \"$name\", group \"$group\"!"
            fi
            local taskIds=()
            for class in ${nUniqueClasses[*]}; do
                query="SELECT id FROM tasks WHERE class = '$class' AND difficulty_level = $i ORDER BY RANDOM() LIMIT 1"
                local taskId="$(echo "$query" | sqlite3 "$dbFile")"
                taskIds+=("$taskId")
            done
            info "\t\tAssigning the following ${taskLabels[$i]}-level tasks with ids: (${taskIds[*]})..."
            for taskId in ${taskIds[*]}; do
                echo "INSERT INTO students_tasks (student_id, task_id) VALUES ($studentId, $taskId)" | sqlite3 "$dbFile"
            done
            printOk
        fi
    done
}

# adding tasks to the DB
taskId=1
for task in "$taskDir/"*.*; do
    if [ ! -f "$task" ]; then
        continue
    fi
    addTaskToDb "$task" "$taskId"
    taskId=$(( $taskId + 1 ))
done

# Adding students and distributing tasks
studentId=1
groupId=1
for group in "$groupDir/"*; do
    if [ ! -f "$group" ]; then
        error "Error: \"$group\" isn't a file!"
    fi
    if [ -z "$(echo "${group##*/}" | grep -P '^[A-Za-zА-Яа-яёЁ0-9-]+_\d+L\d+M\d+H\.csv$')" ]; then
        error "Error: invalid group file name \"$group\". Correct example: \"groupName_3L4M2H.csv\""
    fi
    groupName="${group##*/}"
    groupName="${groupName%_*}"
    query="SELECT (id) FROM groups WHERE name = '$groupName'"
    if [ ! -z "$(echo "$query" | sqlite3 "$dbFile")" ]; then
        error "Error: the following group name occurs twice: \"$groupName\""
    fi
    groupTaskDistribution="${group##*_}"
    groupTaskDistribution="${groupTaskDistribution%.csv}"
    info "\nAdding student group \"$groupName\" to database..."
    echo "INSERT INTO groups (id, name) VALUES ($groupId, '$groupName')" | sqlite3 "$dbFile"
    printOk
    while read line
    do
        if [ -z "$(echo "$line" | grep -P '^[A-Za-zА-Яа-яёЁ\- ]+,[^, \t]+(,\d+L\d+M\d+H)?,?$')" ]; then
            error "Error: invalid student line \"$line\". Use: \"full_name,password[,nLnMnH (n - number)]\""
        fi
        fullName="$(echo "$line" | cut -d ',' -f 1 | sed 's/^[ \t]*\|[ \t]*$//g')"
        hashPassw="$(echo "$line" | cut -d ',' -f 2 | sed 's/^[ \t]*\|[ \t]*$//g' | htpasswd -inBC 12 '' | tr -d ':\n')"
        info "\n\tAdding student \"$fullName\" to database..."
        echo "INSERT INTO students (id, full_name, password, group_id) \
        VALUES ($studentId, '$fullName', '$hashPassw', $groupId)" | sqlite3 "$dbFile"
        printOk
        studentTaskDistribution="$(echo "$line" | cut -d ',' -f 3 2> /dev/null | sed 's/^[ \t]*\|[ \t]*$//g')"
        studentTaskDistribution="${studentTaskDistribution:=$groupTaskDistribution}"
        distributeTasks $studentId $studentTaskDistribution
        studentId=$(( $studentId + 1 ))
    done < "$group"
    groupId=$(( $groupId + 1 ))
done

info "\nCreating python environment for sandbox..."
mkdir "$testDir/lib/pyenv"
bwrap \
--new-session \
--unshare-all \
--ro-bind /usr /usr \
--symlink /usr/bin /bin \
--symlink /usr/lib /lib \
--symlink /usr/lib64 /lib64 \
--ro-bind /etc /etc \
--dev /dev \
--bind "$testDir/lib/pyenv" /pyenv \
bash -c 'python3 -m venv /pyenv'
printOk

if ls "$taskDir/"*.py &> /dev/null; then
    pyRequirements="$(pip freeze | tr '\n' ' ')"
    if [ -n "$pyRequirements" ]; then
        info "\nInstalling dependencies into python environment inside sandbox...\n"
        pyRequirements="$(pip freeze | tr '\n' ' ')"
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
        --bind "$testDir/lib/pyenv" /pyenv \
        bash -c ". /pyenv/bin/activate; \
        pip install $pyRequirements; \
        deactivate"
        printOk
    fi
fi

info "Creating a resource limit configuration file..."
echo 'timeout:10
nice:5
MemoryHigh:800M
MemoryMax:1000M
MemorySwapMax:0
RunTasksMax:5
StudProcMax:100' > "$testDir/settings/resource_limits.txt"
chmod 644 "$testDir/settings/resource_limits.txt"
printOk

info "Creating a server configuration file..."
echo 'port:8080' > "$testDir/settings/server.txt"
chmod 644 "$testDir/settings/server.txt"
printOk

info "Creating a script that executes the student's code..."
echo '#!/bin/bash
studentId="$1"
hashCorrectAnswer="$2"
language="$3"
run_script="$4"
rm -rf "$(pwd)/work-tmp/stud-home/$studentId/"* 2> /dev/null
rm -rf "$(pwd)/work-tmp/stud-home/$studentId/".* 2> /dev/null
rm "$(pwd)/work-tmp/msg/$studentId.txt" 2> /dev/null
ulimit -f 2048
systemd-run \
--scope \
--user \
--nice $STS_NICE \
-p MemoryHigh=$STS_MEMORY_HIGH \
-p MemoryMax=$STS_MEMORY_MAX \
-p MemorySwapMax=$STS_MEMORY_SWAP_MAX \
-p TasksMax=$STS_STUD_PROC_MAX \
timeout $STS_TIMEOUT \
bwrap \
--new-session \
--unshare-all \
--die-with-parent \
--ro-bind /usr /usr \
--symlink /usr/bin /bin \
--symlink /usr/lib /lib \
--symlink /usr/lib64 /lib64 \
--ro-bind /etc /etc \
--setenv HOME /home/student \
--dev /dev \
--ro-bind "$(pwd)/lib/pyenv" /pyenv \
--ro-bind "$(pwd)/work-tmp/code/${studentId}.txt" /code.$language \
--bind "$(pwd)/work-tmp/stud-home/$studentId" /home/student \
--ro-bind "$(pwd)/data" /home/student/data \
--chdir /home/student \
bash -c "$run_script" &> "$(pwd)/work-tmp/out/${studentId}.txt"

if [ "$(cat "$(pwd)/work-tmp/out/${studentId}.txt" | wc -c)" -eq "$(( 2048 * 1024 ))" ]; then
    echo "The program output may have exceeded 2 MiB!" >> "$(pwd)/work-tmp/msg/${studentId}.txt"
fi
curDate="$(date +%Y%m%d%H%M%S)"
pushd "$(pwd)/work-tmp/stud-home/$studentId" &> /dev/null
for fileName in *.{png,jpeg}; do
    if [ -f "$fileName" ]; then
        if [ "$(cat "$fileName" | wc -c)" -eq "$(( 2048 * 1024 ))" ]; then
            echo "File \"$fileName\" has exceeded 2 MiB in size!" >> "$(pwd)/work-tmp/msg/$studentId.txt"
            rm "$fileName"
            continue
        fi
        mv "$fileName" "$curDate$fileName" 2> /dev/null
    fi
done
popd &> /dev/null
hashAnswer="$(cat "$(pwd)/work-tmp/out/${studentId}.txt" | tail -n +2 | tr -d "\n\t\r " | sha256sum | tr -d " \-\n")"
if [ "$hashAnswer" == "$hashCorrectAnswer" ]; then
    exit 0
else
    exit 1
fi' > "$testDir/tools/run-stud-code.sh"
chmod 550 "$testDir/tools/run-stud-code.sh"
printOk
info "Done\n"
exit 0
