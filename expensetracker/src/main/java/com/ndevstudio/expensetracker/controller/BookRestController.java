package com.ndevstudio.expensetracker.controller;

import com.ndevstudio.expensetracker.entity.Book;
import com.ndevstudio.expensetracker.service.BookService;

import org.springframework.beans.factory.annotation.Autowired;

import org.springframework.http.ResponseEntity;

import org.springframework.security.core.Authentication;

import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/books")
public class BookRestController {

    private final BookService bookService;

    @Autowired
    public BookRestController(BookService bookService) {
        this.bookService = bookService;
    }

    // READ USER BOOKS
    @GetMapping("/readAll")
    public ResponseEntity<List<Book>> getAllBooks(Authentication authentication){
        return bookService.readAllBooks(authentication);
    }

    @GetMapping("/readAllArchived")
    public ResponseEntity<List<Book>> getArchivedBooks(Authentication authentication){
        return bookService.readArchivedBooks(authentication);
    }
    // CREATE BOOK
    @PostMapping("/create")
    public ResponseEntity<Book> createNewBook(@RequestBody Book b, Authentication authentication) {
        return bookService.createBook(b, authentication);
    }

    // UPDATE BOOK
    @PutMapping("/edit/{id}")
    public ResponseEntity<?> editExistingBook(@RequestBody Book b, @PathVariable long id,Authentication authentication) {
        return bookService.updateBook(b,id,authentication);
    }

    @PatchMapping("archive/{id}")
    public ResponseEntity<String> archiveBook(@PathVariable long id,Authentication authentication){
        return bookService.archiveBook(id, authentication);
    }

    @PatchMapping("restore/{id}")
    public ResponseEntity<String> restoreBook(@PathVariable long id,Authentication authentication){
        return bookService.restoreBook(id, authentication);
    }
    
    // DELETE BOOK
    @DeleteMapping("/delete/{id}")
    public ResponseEntity<?> deleteBook(@PathVariable long id, Authentication authentication) {
        return bookService.deleteBook(id, authentication);
    }
}