#!/bin/bash
shopt -s extglob

info() {
   echo -en "\033[32m$1\033[0m" # $1 - message
}
printOk() {
   echo -e "\033[32mOK\033[0m"
}

if [ $# -ne 3 ]; then
    echo -e "\033[33mError! Use: \"$0\" test_name group_directory task_directory\033[0m" >&2
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

if [ ! -d "$groupDir" ]; then
    error "Error: directory \"$groupDir\" doesn't exist!"
fi

if [ ! -d "$taskDir" ]; then
    error "Error: directory \"$taskDir\" doesn't exist!"
fi

if [ -z "$(ls "$groupDir")" ]; then
    error "Error: \"$groupDir\" directory is empty!"
fi

if [ "$(ls "$taskDir/"*.{py,sh} 2> /dev/null | wc -l)" -eq 0 ]; then
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
language TEXT NOT NULL CHECK(language IN ('py', 'sh')));
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

# adding tasks to the DB
taskLabels=(L M H)
taskId=1
for task in "$taskDir/"*.{py,sh}; do
    if [ ! -f "$task" ]; then
        continue
    fi
    description="$(grep -P '^\s*#\s*:d:' "$task" | sed 's/^[ \t]*#[ \t]*:d:[ \t]*//' | tr '\n' ' ' | tr "'" "\"" | sed 's/[ \t]$//')"
    if [ -z "$description" ]; then
        error "Error: there is no description in the task file \"$task\"!.\nExample description:\n# :d: your_description\n# :d: your_description"
    fi
    query="SELECT (id) FROM tasks WHERE description = '$description'"
    if [ ! -z "$(echo "$query" | sqlite3 "$dbFile")" ]; then
        error "Error: the following task description occurs twice:\n\"$description\""
    fi
    diffLevel="$(grep -P '^\s*#\s*:level:\s*[LMH]\s*$' "$task" | tr -c 'LMH' ' ' | tr -d ' ' | tr 'L' '0' | tr 'M' '1' | tr 'H' '2')"
    if [ -z "$diffLevel" ]; then
        error "Error: there is no difficulty level label in the task file \"$task\".\nUse:\n# :level: L|M|H"
    fi
    info "\nAdding ${taskLabels[$diffLevel]}-level task with id $taskId: \"$description\" to database..."
    pushd "$testDir" &> /dev/null
    if [ "${task##*.}" = 'py' ]; then
        language='py'
        answer="$(python "$task")" || error "Error in task: \"$task\""
    else # bash
        language='sh'
        answer="$(bash "$task")" || error "Error in task: \"$task\""
    fi
    popd &> /dev/null
    answer="$(echo "$answer" | tr -d '\n\t\r ')"
    if [ -z "$answer" ]; then
        error "Error: The answer to task \"$task\" is empty!"
    fi
    hashAnswer="$(echo -n "$answer" | sha256sum | tr -d ' \-\n')"
    echo "INSERT INTO tasks (id, description, answer, difficulty_level, language) VALUES \
        ($taskId, '$description', '$hashAnswer', $diffLevel, '$language')" | sqlite3 "$dbFile"
    printOk
    taskId=$(( $taskId + 1 ))
done

distributeTasks() {
    # $1 - student id
    # $2 - task distribution line (example: 3H2M1L)
    taskDistribArr=($(echo "$2" | tr 'LMH' ' '))
    for i in {0..2}; do
        if [ ${taskDistribArr[$i]} -gt 0 ]; then
            tasksIds=($(echo "SELECT (id) FROM tasks WHERE difficulty_level = $i ORDER BY RANDOM() LIMIT ${taskDistribArr[$i]}" | sqlite3 "$dbFile"))
            if [ ${#tasksIds[*]} -lt ${taskDistribArr[$i]} ]; then
                query="SELECT s.full_name, g.name FROM students AS s JOIN groups AS g ON s.group_id = g.id WHERE s.id = $1"
                studentAndGroup="$(echo "$query" | sqlite3 "$dbFile")"
                s="$(echo "$studentAndGroup" | cut -d '|' -f 1)"
                g="$(echo "$studentAndGroup" | cut -d '|' -f 2)"
                error "Error: for student \"$s\" from group \"$g\" there were not enough ${taskLabels[$i]} tasks, \
                    ${taskDistribArr[$i]} tasks are required, but there are only ${#tasksIds[*]}!"
            fi

            info "\t\tAssigning the following ${taskLabels[$i]}-level tasks with ids: (${tasksIds[*]})..."
            for taskId in ${tasksIds[*]}
            do
                echo "INSERT INTO students_tasks (student_id, task_id) VALUES ($1, $taskId)" | sqlite3 "$dbFile"
            done
            printOk
        fi
    done
}

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
--ro-bind "$(pwd)/work-tmp/code/${studentId}.txt" /code.txt \
--ro-bind "$(pwd)/tools/run-code-inside-sandbox.sh" /run-code.sh \
--bind "$(pwd)/work-tmp/stud-home/$studentId" /home/student \
--ro-bind "$(pwd)/data" /home/student/data \
--chdir /home/student \
bash /run-code.sh "$language" &> "$(pwd)/work-tmp/out/${studentId}.txt"

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

info "Creating a script to run student code inside the sandbox..."
echo '#!/bin/bash
language="$1"
source /pyenv/bin/activate
if [ "$language" = "py" ]; then
    python /code.txt
elif [ "$language" = "sh" ]; then
    bash /code.txt
fi
deactivate' > "$testDir/tools/run-code-inside-sandbox.sh"
chmod 444 "$testDir/tools/run-code-inside-sandbox.sh"
printOk

info "Done\n"
exit 0
