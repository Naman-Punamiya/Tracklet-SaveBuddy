package com.ndevstudio.expensetracker.repository;

import com.ndevstudio.expensetracker.entity.Book;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface BookRepository extends JpaRepository<Book, Long> {
}
