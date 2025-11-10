package org.air_river.skills_testing_system.lib.responses;
import java.util.Optional;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;

@JsonIgnoreProperties(ignoreUnknown = true)
public class StudentResultInfo {
    private Optional<Boolean> taskStatus;
    private int totalResult;

    public StudentResultInfo(Optional<Boolean> taskStatus, int totalResult) {
        this.taskStatus = taskStatus;
        this.totalResult = totalResult;
    }

    public boolean isTaskStatus() {
        return taskStatus.orElse(false);
    }

    public String getTaskStatusForHuman() {
        return taskStatus.map(s -> s ? "solved" : "unsolved").orElse("-------");
    }

    public int getTotalResult() {
        return totalResult;
    }
}
