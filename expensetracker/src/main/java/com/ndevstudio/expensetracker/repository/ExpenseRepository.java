package com.ndevstudio.expensetracker.repository;

import com.ndevstudio.expensetracker.entity.Expense;
import com.ndevstudio.expensetracker.entity.User;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface ExpenseRepository extends JpaRepository<Expense, Long> {
    List<Expense> findByBookId(Long bookId);
}
