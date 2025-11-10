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
