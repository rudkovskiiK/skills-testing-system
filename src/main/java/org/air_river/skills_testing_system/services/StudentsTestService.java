package org.air_river.skills_testing_system.services;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileNotFoundException;
import java.io.InputStream;
import java.security.Principal;
import java.util.Arrays;
import java.util.List;
import java.util.NoSuchElementException;
import java.util.Optional;
import java.util.stream.StreamSupport;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.core.io.InputStreamResource;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Service;
import org.springframework.ui.Model;
import jakarta.servlet.http.HttpSession;
import org.air_river.skills_testing_system.lib.exceptions.ExecTaskCodeException;
import org.air_river.skills_testing_system.lib.exceptions.InvalidImageNameFormatException;
import org.air_river.skills_testing_system.lib.exceptions.NoSuchImageException;
import org.air_river.skills_testing_system.lib.exceptions.NoSuchUserException;
import org.air_river.skills_testing_system.lib.requests.UserCode;
import org.air_river.skills_testing_system.lib.responses.StudentResultInfo;
import org.air_river.skills_testing_system.lib.responses.SimpleTextResponse;
import org.air_river.skills_testing_system.models.Result;
import org.air_river.skills_testing_system.models.Student;
import org.air_river.skills_testing_system.models.Task;
import org.air_river.skills_testing_system.repos.ResultsRepository;
import org.air_river.skills_testing_system.repos.StudentsRepository;

@Service
public class StudentsTestService {
    @Autowired
    private StudentsRepository studentsRepository;
    @Autowired
    private ResultsRepository resultsRepository;
    @Autowired
    private TaskCodeExecutionService taskCodeExecutionService;

    private Student getStudent(Principal principal) throws NoSuchUserException {
        try {
            Long id = Long.valueOf(principal.getName());
            return studentsRepository.findById(id).get();
        } catch(NumberFormatException  ex) {
            throw new NoSuchUserException("Invalid student login (" + principal.getName() + ") format!");
        } catch(NoSuchElementException ex) {
            throw new NoSuchUserException("No student with id (" + principal.getName() + ") found!");
        }
    }

    private Optional<Task> getCurrentTask(Student student) {
        if(student.getTasks().isEmpty()) {
            return Optional.empty();
        }
        int index = student.getNextTaskClickCount() % student.getTasks().size();
        return Optional.of(student.getTasks().get(index));
    }

    private Optional<Result> getCurrentTaskResult(Student student) {
        return getCurrentTask(student)
            .flatMap(t -> student.getResults().stream().filter(r -> r.getTask().equals(t)).findAny());
    }

    private StudentResultInfo getStudentResultInfo(Student student) {
        int totalResult = 0;
        Optional<Boolean> status = Optional.empty();
        if(!student.getTasks().isEmpty()) {
            totalResult = (int)((100*student.getResults().stream().filter(r -> r.getStatus()).count()) / student.getTasks().size());
            status = Optional.of(getCurrentTaskResult(student).map(r -> r.getStatus()).orElse(false));
        }
        return new StudentResultInfo(status, totalResult);
    }

    public StudentResultInfo getStudentResultInfo(Principal principal) throws NoSuchUserException {
        Student student = getStudent(principal);
        return getStudentResultInfo(student);
    }

    public List<Student> getStudentsWithLoginPermission() {
        return StreamSupport
            .stream(studentsRepository.findByLoginPermissionTrueOrderById().spliterator(), false)
            .toList();
    }

    public void goToNextTask(Principal principal, UserCode userCode) throws NoSuchUserException {
        Student student = getStudent(principal);
        Optional<Task> curTask = getCurrentTask(student);
        if(curTask.isPresent()) {
            Result result = getCurrentTaskResult(student).orElse(new Result(student, curTask.get()));
            if(!result.getStatus()) {
                result.setCode(userCode.getCode());
                resultsRepository.save(result);
            }
        }
        student.setNextTaskClickCount(student.getNextTaskClickCount() + 1);
        studentsRepository.save(student);
    }

    public SimpleTextResponse executeCodeForCurTask(Principal principal, UserCode userCode) throws NoSuchUserException, ExecTaskCodeException {
        Student student = getStudent(principal);
        Optional<Task> curTask = getCurrentTask(student);
        if(curTask.isEmpty()) {
            return new SimpleTextResponse("");
        }
        if(userCode.getCode() == null || getCurrentTaskResult(student).map(r -> r.getStatus()).orElse(false)) {
            return new SimpleTextResponse("");
        }
        String correctAnswer = curTask.get().getAnswer();
        TaskCodeExecutionService.ExecResult execResult = taskCodeExecutionService.execute(student, userCode.getCode(), correctAnswer);
        Result result = getCurrentTaskResult(student).orElse(new Result(student, curTask.get()));
        result.setCode(userCode.getCode());
        result.setStatus(execResult.getExitStatus() == 0 ? true : false);
        resultsRepository.save(result);
        return new SimpleTextResponse(execResult.getCodeOutput());
    }

    public List<String> getListOfImageNames(Principal principal) throws NoSuchUserException {
        Student student = getStudent(principal);
        File studHomeDir = new File("work-tmp/stud-home/" + student.getId());
        return Arrays.stream(studHomeDir.listFiles((dir, name) -> name.matches("^.+\\.(png|jpeg)$"))).map(file -> file.getName()).toList();
    }

    public ResponseEntity<InputStreamResource> getImage(String imageName, Principal principal) throws NoSuchUserException,
        InvalidImageNameFormatException, NoSuchImageException {
        Student student = getStudent(principal);
        if(!imageName.matches("^[^/]+\\.(png|jpeg)$")) {
            throw new InvalidImageNameFormatException("Invalid image name format (" + imageName + ")!");
        }
        File imageFile = new File("work-tmp/stud-home/" + student.getId() + "/" + imageName);
        if(!imageFile.exists()) {
            throw new NoSuchImageException("Image file (" + imageName + ") doesn't not exist!");
        }
        InputStream in = null;
        try {
            in = new FileInputStream(imageFile);
        } catch(FileNotFoundException ex) {
            throw new NoSuchImageException("Image file (" + imageName + ") doesn't not exist!");
        }
        MediaType mediaType = imageName.matches("^.+\\.png$") ? MediaType.IMAGE_PNG : MediaType.IMAGE_JPEG;
        return ResponseEntity.ok().contentType(mediaType).body(new InputStreamResource(in));
    }

    public String getTestPageView(Model model, Principal principal, HttpSession httpSession) {
        try {
            Student student = getStudent(principal);
            model.addAttribute("student", student);
            model.addAttribute("taskIndexFromOne", getCurrentTask(student).map(t -> student.getTasks().indexOf(t) + 1).orElse(0));
            model.addAttribute("currentTaskDescription", getCurrentTask(student).map(t -> t.getDescription()).orElse("-------"));
            model.addAttribute("numberOfTasks", student.getTasks().size());
            model.addAttribute("resultInfo", getStudentResultInfo(student));
            model.addAttribute("taskCode", getCurrentTaskResult(student).map(r -> r.getStatus() ? "" : r.getCode()).orElse("Enter your code"));
            return "testPage";
        } catch(NoSuchUserException ex) {
            model.addAttribute("msg", ex.getMessage());
            return "appError";
        }
    }
}
