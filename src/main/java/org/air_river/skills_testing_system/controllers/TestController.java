// TestController.java - this file is part of skills-testing-system
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

package org.air_river.skills_testing_system.controllers;
import java.security.Principal;
import java.util.List;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.core.io.InputStreamResource;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseBody;
import org.springframework.web.bind.annotation.ResponseStatus;
import jakarta.servlet.http.HttpSession;
import org.air_river.skills_testing_system.lib.responses.StudentResultInfo;
import org.air_river.skills_testing_system.lib.exceptions.ExecTaskCodeException;
import org.air_river.skills_testing_system.lib.exceptions.InvalidImageNameFormatException;
import org.air_river.skills_testing_system.lib.exceptions.NoSuchImageException;
import org.air_river.skills_testing_system.lib.exceptions.NoSuchUserException;
import org.air_river.skills_testing_system.lib.requests.UserCode;
import org.air_river.skills_testing_system.lib.responses.SimpleTextResponse;
import org.air_river.skills_testing_system.services.StudentsTestService;

@Controller
@RequestMapping("/")
public class TestController {
    @Autowired
    private StudentsTestService studentsTestService;

    @GetMapping
    public String getTestPage(Model model, Principal principal, HttpSession httpSession) {
        return studentsTestService.getTestPageView(model, principal, httpSession);
    }

    @GetMapping("login")
    public String getLoginPage(Model model) {
        model.addAttribute("students", studentsTestService.getStudentsWithLoginPermission());
        return "login";
    }

    @PostMapping("next_task")
    @ResponseStatus(code = HttpStatus.NO_CONTENT)
    public void goToNextTask(Principal principal, @RequestBody UserCode userCode) throws NoSuchUserException {
        studentsTestService.goToNextTask(principal, userCode);
    }

    @PostMapping("exec_code")
    @ResponseBody
    public SimpleTextResponse execCode(Principal principal, @RequestBody UserCode userCode) throws
    NoSuchUserException, ExecTaskCodeException {
        return studentsTestService.executeCodeForCurTask(principal, userCode);
    }

    @GetMapping("result_info")
    @ResponseBody
    public StudentResultInfo getStudentResultInfo(Principal principal) throws NoSuchUserException {
        return studentsTestService.getStudentResultInfo(principal);
    }

    @GetMapping("image_names")
    @ResponseBody
    public List<String> getListOfImageNames(Principal principal) throws NoSuchUserException {
        return studentsTestService.getListOfImageNames(principal);
    }

    @GetMapping("image/{name}")
    public ResponseEntity<InputStreamResource> getImage(@PathVariable("name") String imageName,
        Principal principal) throws NoSuchUserException, InvalidImageNameFormatException,
        NoSuchImageException {
        return studentsTestService.getImage(imageName, principal);
    }
}
