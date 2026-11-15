package com.ndevstudio.expensetracker.repository;

import com.ndevstudio.expensetracker.entity.Book;
import com.ndevstudio.expensetracker.entity.Category;
import com.ndevstudio.expensetracker.entity.Expense;
import com.ndevstudio.expensetracker.entity.User;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface ExpenseRepository extends JpaRepository<Expense, Long> {
    List<Expense> findByBookId(Long bookId);
    List<Expense> findByUser(User user);
    List<Expense> findByCategory(Category category);
    List<Expense> findByUserAndBook(User user, Book book);
    List<Expense> findByUserAndCategory(User user, Category category);
    void deleteByUser(User user);
}
