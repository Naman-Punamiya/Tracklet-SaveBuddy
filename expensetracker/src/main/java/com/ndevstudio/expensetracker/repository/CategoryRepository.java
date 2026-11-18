package com.ndevstudio.expensetracker.repository;

import com.ndevstudio.expensetracker.entity.Category;
import com.ndevstudio.expensetracker.entity.User;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface CategoryRepository extends JpaRepository<Category, Long> {
    List<Category> findByUserId(Long userId);
    List<Category> findByUser(User user);
    Optional<Category> findByIdAndUser(Long id, User user);
    void deleteByUser(User user);
}
