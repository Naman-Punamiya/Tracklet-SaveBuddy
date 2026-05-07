package com.ndevstudio.expensetracker.service;

import com.ndevstudio.expensetracker.entity.Book;
import com.ndevstudio.expensetracker.repository.BookRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
public class BookService {
    private BookRepository bookRepository;

    @Autowired
    BookService(BookRepository bookRepository) {
        this.bookRepository = bookRepository;
    }

    //Read
    public ResponseEntity<List<Book>> readAllBooks() {
        List<Book> books = bookRepository.findAll();
        return new ResponseEntity<>(books, HttpStatus.OK);
    }

    //Create
    public ResponseEntity<Book> createBook(Book newBook) {
        Book b = bookRepository.save(newBook);
        return new ResponseEntity<>(b, HttpStatus.CREATED);
    }

    //Update
    public ResponseEntity<Book> updateBook(Book newBook, long id) {
        Book oldBook = bookRepository.findById(id).orElse(null);
        if (oldBook != null) {
            oldBook.setName(newBook.getName());
            bookRepository.save(oldBook);
            return new ResponseEntity<>(oldBook, HttpStatus.OK);
        }
        return new ResponseEntity<>(HttpStatus.NOT_FOUND);
    }

    //Delete
    public ResponseEntity<Book> deleteBook(long id) {
        Book b = bookRepository.findById(id).orElse(null);
        if (b != null) {
            bookRepository.delete(b);
            return new ResponseEntity<>(b, HttpStatus.OK);
        }
        return new ResponseEntity<>(HttpStatus.NOT_FOUND);
    }
}
