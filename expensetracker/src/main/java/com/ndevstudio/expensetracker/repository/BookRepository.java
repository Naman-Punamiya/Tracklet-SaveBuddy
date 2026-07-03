package com.ndevstudio.expensetracker.repository;

import com.ndevstudio.expensetracker.entity.Book;
import com.ndevstudio.expensetracker.entity.User;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface BookRepository extends JpaRepository<Book, Long> {
    List<Book> findByUser(User user);

    List<Book> findByUserAndArchived(User user,boolean archived);
}
