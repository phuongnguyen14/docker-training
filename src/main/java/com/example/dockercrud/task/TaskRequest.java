package com.example.dockercrud.task;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record TaskRequest(
        @NotBlank(message = "Tiêu đề không được để trống")
        @Size(max = 120, message = "Tiêu đề tối đa 120 ký tự")
        String title,

        @Size(max = 500, message = "Mô tả tối đa 500 ký tự")
        String description,

        boolean completed
) {
}

