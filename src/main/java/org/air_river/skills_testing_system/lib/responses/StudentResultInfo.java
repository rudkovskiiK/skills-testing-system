// StudentResultInfo.java - this file is part of skills-testing-system
// Copyright (C) 2026  Kirill Rudkovskii
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

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
