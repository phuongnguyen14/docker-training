package com.example.dockercrud.task;

import com.example.dockercrud.app.dtos.TaskDto;
import com.example.dockercrud.app.response.TaskResponse;
import com.example.dockercrud.domain.services.TaskService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.transaction.annotation.Transactional;

import static org.assertj.core.api.Assertions.assertThat;

@SpringBootTest
@Transactional
class TaskServiceTest {

    @Autowired
    private TaskService taskService;

    @Test
    void should_CreateTask_When_RequestValid() {
        TaskDto request = new TaskDto("Viết tài liệu", "Chuẩn bị README", false);

        TaskResponse response = taskService.create(request);

        assertThat(response.id()).isNotNull();
        assertThat(response.title()).isEqualTo("Viết tài liệu");
        assertThat(response.completed()).isFalse();
    }

    @Test
    void should_UpdateTask_When_ExistingId() {
        TaskResponse created = taskService.create(new TaskDto("Test", "Desc", false));
        TaskDto updateRequest = new TaskDto("Đã cập nhật", "Hoàn tất", true);

        TaskResponse updated = taskService.update(created.id(), updateRequest);

        assertThat(updated.title()).isEqualTo("Đã cập nhật");
        assertThat(updated.completed()).isTrue();
    }
}

