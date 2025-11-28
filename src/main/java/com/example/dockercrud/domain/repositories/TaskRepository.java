package com.example.dockercrud.domain.repositories;

import com.example.dockercrud.domain.entities.Task;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface TaskRepository extends JpaRepository<Task, Long> {
    Optional<Task> findByTitleAndIsDeletedFalse(String title);
}

