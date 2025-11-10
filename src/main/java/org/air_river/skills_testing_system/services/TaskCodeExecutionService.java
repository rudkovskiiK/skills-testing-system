package org.air_river.skills_testing_system.services;
import java.io.BufferedReader;
import java.io.BufferedWriter;
import java.io.File;
import java.io.FileReader;
import java.io.FileWriter;
import java.io.IOException;
import java.util.Collections;
import java.util.LinkedList;
import java.util.List;
import java.util.Optional;
import org.springframework.stereotype.Service;
import org.air_river.skills_testing_system.lib.exceptions.ExecTaskCodeException;
import org.air_river.skills_testing_system.models.Student;

@Service
public class TaskCodeExecutionService {
    private int numRunTasks = 0;
    private int runTasksMax;
    private List<Long> queueForExec = Collections.synchronizedList(new LinkedList<Long>());

    public TaskCodeExecutionService() {
        runTasksMax = Optional.ofNullable(System.getenv("STS_RUN_TASKS_MAX")).map(v -> Integer.valueOf(v)).orElse(1);
    }

    public static class ExecResult {
        private int exitStatus;
        private String codeOutput;

        public ExecResult(int exitStatus, String codeOutput) {
            this.exitStatus = exitStatus;
            this.codeOutput = codeOutput;
        }

        public int getExitStatus() {
            return exitStatus;
        }

        public String getCodeOutput() {
            return codeOutput;
        }
    }

    ExecResult execute(Student student, String code, String correctAnswer) throws ExecTaskCodeException {
        if(numRunTasks >= runTasksMax) {
            queueForExec.add(Thread.currentThread().getId());
            while((numRunTasks >= runTasksMax) || (queueForExec.get(0) != Thread.currentThread().getId())) {
                try {
                    Thread.sleep(1000);
                } catch(InterruptedException ex) {
                    queueForExec.remove(0);
                    throw new ExecTaskCodeException("Error. This thread was interrupted!");
                }
            }
            numRunTasks++;
            System.out.println("numRunTasks(+) = " + numRunTasks + " stud_id = " + student.getId());
            queueForExec.remove(0);
        } else {
            numRunTasks++;
            System.out.println("numRunTasks(+) = " + numRunTasks + " stud_id = " + student.getId());
        }
        File codeFilePath = new File("./work-tmp/code/" + student.getId() + ".py");
        File outFilePath = new File("./work-tmp/out/" + student.getId() + ".txt");
        File msgFilePath = new File("./work-tmp/msg/" + student.getId() + ".txt");
        try(BufferedWriter bw = new BufferedWriter(new FileWriter(codeFilePath))) {
            bw.write(code);
        } catch(IOException ex) {
            throw new ExecTaskCodeException("Error saving code file!");
        }
        try {
            Process process = new ProcessBuilder("./tools/run-stud-code.sh", student.getId().toString(), correctAnswer).start();
            process.waitFor();
            String out = "";
            try(BufferedReader br = new BufferedReader(new FileReader(outFilePath))) {
                String line = "";
                int c = 0;
                while((line = br.readLine()) != null) {
                    if(c > 0) {
                        out += out.isEmpty() ? line : "\n" + line;
                    }
                    c++;
                }
            }
            if(msgFilePath.exists()) {
                try(BufferedReader br = new BufferedReader(new FileReader(msgFilePath))) {
                    String line = "";
                    while((line = br.readLine()) != null) {
                        out += out.isEmpty() ? line : "\n" + line;
                    }
                }
            }
            numRunTasks--;
            System.out.println("numRunTasks(-) = " + numRunTasks + " stud_id = " + student.getId());
            return new ExecResult(process.exitValue(), out);
        } catch(IOException ex) {
            numRunTasks--;
            System.out.println("numRunTasks(-) = " + numRunTasks + " stud_id = " + student.getId());
            throw new ExecTaskCodeException("Stream error (user code)!");
        } catch(InterruptedException ex) {
            numRunTasks--;
            System.out.println("numRunTasks(-) = " + numRunTasks + " stud_id = " + student.getId());
            throw new ExecTaskCodeException("Error. This thread was interrupted!");
        }
    }
}
