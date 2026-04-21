// ExceptionController.java - this file is part of skills-testing-system
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
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.air_river.skills_testing_system.lib.exceptions.ExecTaskCodeException;
import org.air_river.skills_testing_system.lib.exceptions.InvalidImageNameFormatException;
import org.air_river.skills_testing_system.lib.exceptions.NoSuchImageException;
import org.air_river.skills_testing_system.lib.exceptions.NoSuchUserException;
import org.air_river.skills_testing_system.lib.responses.SimpleTextResponse;

@RestControllerAdvice
public class ExceptionController {
    @ExceptionHandler
    @ResponseStatus(HttpStatus.INTERNAL_SERVER_ERROR)
    public SimpleTextResponse taskCodeExceptionHandler(ExecTaskCodeException ex) {
        return new SimpleTextResponse(ex.getMessage());
    }

    @ExceptionHandler
    @ResponseStatus(HttpStatus.BAD_REQUEST)
    public SimpleTextResponse noSuchUserExceptionHandler(NoSuchUserException ex) {
        return new SimpleTextResponse(ex.getMessage());
    }

    @ExceptionHandler
    @ResponseStatus(HttpStatus.BAD_REQUEST)
    public SimpleTextResponse invalidImageNameFormatExceptionHandler(InvalidImageNameFormatException ex) {
        return new SimpleTextResponse(ex.getMessage());
    }

    @ExceptionHandler
    @ResponseStatus(HttpStatus.BAD_REQUEST)
    public SimpleTextResponse noSuchImageExceptionHandler(NoSuchImageException ex) {
        return new SimpleTextResponse(ex.getMessage());
    }
}
