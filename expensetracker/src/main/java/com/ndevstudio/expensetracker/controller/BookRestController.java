package com.ndevstudio.expensetracker.controller;
import com.ndevstudio.expensetracker.entity.Book;
import com.ndevstudio.expensetracker.service.BookService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import java.util.List;

@RestController
@RequestMapping("/books")
public class BookRestController {
    BookService bookService;

    @Autowired
    public BookRestController(BookService bookService) {
        this.bookService = bookService;
    }

    @GetMapping("/readAll")
    ResponseEntity<List<Book>> getAllBooks() {
        return bookService.readAllBooks();
    }

    @PostMapping("/create")
    ResponseEntity<Book> createNewBook(@RequestBody Book b) {
        return bookService.createBook(b);
    }

    @PutMapping("/edit/{id}")
    ResponseEntity<Book> editExistingBook(@RequestBody Book b, @PathVariable long id) {
        return bookService.updateBook(b, id);
    }

    @DeleteMapping("/delete/{id}")
    ResponseEntity<Book> deleteBook(@PathVariable long id) {
        return bookService.deleteBook(id);
    }
}
