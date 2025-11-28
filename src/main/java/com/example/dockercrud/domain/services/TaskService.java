package com.example.dockercrud.domain.services;

import com.example.dockercrud.app.response.TaskResponse;
import com.example.dockercrud.domain.entities.Task;
import com.example.dockercrud.domain.exceptions.CustomException;
import com.example.dockercrud.domain.exceptions.ErrorMessage;
import com.example.dockercrud.domain.repositories.TaskRepository;
import com.example.dockercrud.app.dtos.TaskDto;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

@Service
public class TaskService {

    private final TaskRepository taskRepository;

    public TaskService(TaskRepository taskRepository) {
        this.taskRepository = taskRepository;
    }

    public List<TaskResponse> findAll() {
        return taskRepository.findAll()
                .stream()
                .map(TaskResponse::fromEntity)
                .toList();
    }

    public TaskResponse findById(Long id) {
        return taskRepository.findById(id)
                .map(TaskResponse::fromEntity)
                .orElseThrow(() -> new CustomException(HttpStatus.NOT_FOUND, ErrorMessage.TASK_NOT_FOUND));
    }
    private void validDto(TaskDto dto){
        Optional<Task> existingTask = taskRepository.findByTitleAndIsDeletedFalse(dto.title());
        if (existingTask.isPresent()) {
            throw new CustomException(HttpStatus.CONFLICT,ErrorMessage.TITLE_ALREADY_EXISTS);
        }
        if (dto.title() == null || dto.title().isEmpty()){
            throw new CustomException(HttpStatus.BAD_REQUEST,ErrorMessage.TITLE_REQUIRED);
        }
        if (dto.description() == null || dto.description().isEmpty()){
            throw new CustomException(HttpStatus.BAD_REQUEST,ErrorMessage.DESCRIPTION_REQUIRED);
        }
    }
    @Transactional
    public TaskResponse create(TaskDto dto) {
        validDto(dto);
        Task task = new Task();
        task.setTitle(dto.title());
        task.setDescription(dto.description());
        task.setCompleted(dto.completed());
        task.setCreatedAt(LocalDateTime.now());
        task.setUpdatedAt(LocalDateTime.now());
        return TaskResponse.fromEntity(taskRepository.save(task));
    }

    @Transactional
    public TaskResponse update(Long id, TaskDto dto) {
        Task task = taskRepository.findById(id)
                .orElseThrow(() -> new CustomException(HttpStatus.NOT_FOUND, ErrorMessage.TASK_NOT_FOUND));
        validDto(dto);
        task.setTitle(dto.title());
        task.setDescription(dto.description());
        task.setCompleted(dto.completed());
        task.setUpdatedAt(LocalDateTime.now());
        return TaskResponse.fromEntity(task);
    }

    @Transactional
    public void delete(Long id) {
        Task task = taskRepository.findById(id)
                .orElseThrow(() -> new CustomException(HttpStatus.NOT_FOUND, ErrorMessage.TASK_NOT_FOUND));
        task.setIsDeleted(true);
        taskRepository.save(task);
    }
}

