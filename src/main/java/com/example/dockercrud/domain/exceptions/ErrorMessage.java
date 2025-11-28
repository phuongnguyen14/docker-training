package com.example.dockercrud.domain.exceptions;

public enum ErrorMessage implements BaseErrorMessage {
    // Already exists
    TITLE_ALREADY_EXISTS("Tiêu đề đã tồn tại"),

    // Require items
    TITLE_REQUIRED("Tiêu đề không được để trống"),

    // Not found
    TASK_NOT_FOUND("Không tìm thấy task")
    ;

    public String val;

    private ErrorMessage(String label) {
        val = label;
    }

    @Override
    public String val() {
        return val;
    }
}