package com.example.dockercrud.task;

import java.time.Instant;

public record TaskResponse(
        Long id,
        String title,
        String description,
        boolean completed,
        Instant createdAt,
        Instant updatedAt
) {
    public static TaskResponse fromEntity(Task task) {
        return new TaskResponse(
                task.getId(),
                task.getTitle(),
                task.getDescription(),
                task.isCompleted(),
                task.getCreatedAt(),
                task.getUpdatedAt()
        );
    }
}

