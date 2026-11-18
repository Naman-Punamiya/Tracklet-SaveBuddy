package com.ndevstudio.expensetracker.repository;

import com.ndevstudio.expensetracker.entity.Book;
import com.ndevstudio.expensetracker.entity.User;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface BookRepository extends JpaRepository<Book, Long> {
    List<Book> findByUser(User user);

    List<Book> findByUserAndArchived(User user,boolean archived);

    Optional<Book> findByIdAndUser(Long id, User user);

    void deleteByUser(User user);
}
