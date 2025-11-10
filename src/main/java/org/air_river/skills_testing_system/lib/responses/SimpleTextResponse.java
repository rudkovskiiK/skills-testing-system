package org.air_river.skills_testing_system.lib.responses;

public class SimpleTextResponse {
    private String answer;

    public SimpleTextResponse(String answer) {
        this.answer = answer == null ? "" : answer;
    }

    public String getAnswer() {
        return answer;
    }

    public void setAnswer(String message) {
        this.answer = message;
    }
}
