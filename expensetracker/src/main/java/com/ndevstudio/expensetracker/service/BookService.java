package com.ndevstudio.expensetracker.service;

import com.ndevstudio.expensetracker.entity.Book;
import com.ndevstudio.expensetracker.entity.User;
import com.ndevstudio.expensetracker.repository.BookRepository;
import com.ndevstudio.expensetracker.repository.UserRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
public class BookService {
    private BookRepository bookRepository;
    private UserRepository userRepository;

    @Autowired
    BookService(BookRepository bookRepository, UserRepository userRepository) {
        this.bookRepository = bookRepository;
        this.userRepository = userRepository;
    }

    //Read
    public ResponseEntity<List<Book>> readAllBooks(Authentication authentication) {
        String email = authentication.getName();
        User user = userRepository.findByEmail(email).orElseThrow();
        List<Book> books = bookRepository.findByUser(user);
        return new ResponseEntity<>(books, HttpStatus.OK);
    }

    //Create
    public ResponseEntity<Book> createBook(Book newBook, Authentication authentication) {
        String email = authentication.getName();
        User user = userRepository.findByEmail(email).orElseThrow();
        newBook.setUser(user);
        Book b = bookRepository.save(newBook);
        return new ResponseEntity<>(b, HttpStatus.CREATED);
    }

    //Update
    public ResponseEntity<Book> updateBook(Book newBook, long id, Authentication authentication) {
        String email = authentication.getName();
        User user = userRepository.findByEmail(email).orElseThrow();
        Book oldBook = bookRepository.findById(id).orElse(null);
        if (oldBook == null) {
            return new ResponseEntity<>(null, HttpStatus.NOT_FOUND);
        }
        if (!(oldBook.getUser().getId() == user.getId())) {
            return new ResponseEntity<>(
                    null,
                    HttpStatus.UNAUTHORIZED
            );
        }
        oldBook.setName(newBook.getName());
        bookRepository.save(oldBook);
        return new ResponseEntity<>(oldBook, HttpStatus.OK);
    }

    //Delete
    public ResponseEntity<String> deleteBook(long id, Authentication authentication) {
        String email = authentication.getName();
        User user = userRepository.findByEmail(email).orElseThrow();
        Book b = bookRepository.findById(id).orElse(null);
        if (b == null) {
            return new ResponseEntity<>("Book not found",HttpStatus.NOT_FOUND);
        }

        if (!(b.getUser().getId() == user.getId())){
            return new ResponseEntity<>("Unauthorized",HttpStatus.UNAUTHORIZED);
        }
        bookRepository.delete(b);
        return new ResponseEntity<>("Book deleted", HttpStatus.OK);
    }
}