package com.example.dockercrud.task;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

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
                .orElseThrow(() -> new TaskNotFoundException(id));
    }

    @Transactional
    public TaskResponse create(TaskRequest request) {
        Task task = new Task();
        task.setTitle(request.title());
        task.setDescription(request.description());
        task.setCompleted(request.completed());
        return TaskResponse.fromEntity(taskRepository.save(task));
    }

    @Transactional
    public TaskResponse update(Long id, TaskRequest request) {
        Task task = taskRepository.findById(id)
                .orElseThrow(() -> new TaskNotFoundException(id));
        task.setTitle(request.title());
        task.setDescription(request.description());
        task.setCompleted(request.completed());
        return TaskResponse.fromEntity(task);
    }

    @Transactional
    public void delete(Long id) {
        if (!taskRepository.existsById(id)) {
            throw new TaskNotFoundException(id);
        }
        taskRepository.deleteById(id);
    }
}

