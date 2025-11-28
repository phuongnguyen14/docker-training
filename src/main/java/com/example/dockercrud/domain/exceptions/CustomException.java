package com.example.dockercrud.domain.exceptions;

import org.springframework.http.HttpStatus;

public class CustomException extends RuntimeException {
    HttpStatus status;
    String messageCode;

    public CustomException(HttpStatus status, BaseErrorMessage msg) {
        super(msg.val());
        this.status = status;
        this.messageCode = msg.toString();
    }

    public CustomException(HttpStatus status, BaseErrorMessage msg, String data) {
        super(msg.val() + "(" + data + ")");
        this.status = status;
        this.messageCode = msg.toString();
    }

    public CustomException(HttpStatus status, String msg) {
        super(msg);
        this.status = status;
    }

    public HttpStatus getStatus() {
        return this.status;
    }

    public String getMessageCode() {
        return this.messageCode;
    }
}
